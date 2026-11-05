import 'package:flutter/foundation.dart';

import '../../../../../utils/cache_helper.dart';
import '../models/journey_models.dart';

/// 西行·用户进度服务（本地持久化优先）。
///
/// 功德余额/最远关卡/天赋/解锁记录先落本地（CacheHelper），保证离线可玩；
/// Supabase journey_progress 系列表部署后在此处追加远端同步（上报+回读），
/// 本地口径不变。
class JourneyProgressService extends ChangeNotifier {
  JourneyProgressService._();

  static final JourneyProgressService instance = JourneyProgressService._();

  static const String _storeKey = 'journey_progress_v1';

  /// 天赋点总量（81 难首通各 1 点）。
  static const int talentPoolTotal = 81;

  /// 相生链：生我者（点某系高层需先修其生源）。
  static const Map<String, String> generatorOf = <String, String>{
    'metal': 'earth', // 土生金
    'water': 'metal', // 金生水
    'wood': 'water', // 水生木
    'fire': 'wood', // 木生火
    'earth': 'fire', // 火生土
  };

  /// 相克链：克我者（标志层需修克我者≥4 层作制衡代价）。
  static const Map<String, String> restrainerOf = <String, String>{
    'metal': 'fire', // 火克金
    'wood': 'metal', // 金克木
    'water': 'earth', // 土克水
    'fire': 'water', // 水克火
    'earth': 'wood', // 木克土
  };

  JourneyProgressModel _state = const JourneyProgressModel();
  JourneyProgressModel get state => _state;

  /// 当前出战角色（默认唐僧=初始角色）。
  String selectedCharacterCode = 'tang';

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await CacheHelper.instance.loadMap(_storeKey);
    if (raw == null) return;
    selectedCharacterCode =
        raw['selected_character'] as String? ?? selectedCharacterCode;
    final talentRaw = raw['talent_points'];
    _state = JourneyProgressModel(
      meritBalance: (raw['merit_balance'] as num?)?.toInt() ?? 0,
      farthestLevelNo: (raw['farthest_level_no'] as num?)?.toInt() ?? 0,
      totalKills: (raw['total_kills'] as num?)?.toInt() ?? 0,
      talentPool: (raw['talent_pool'] as num?)?.toInt() ?? 0,
      talentPoints: talentRaw is Map<String, dynamic>
          ? talentRaw.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0))
          : <String, int>{},
      unlockedCharacters:
          ((raw['unlocked_characters'] as List<dynamic>?) ?? const <dynamic>[])
              .cast<String>()
              .toSet(),
      unlockedWeapons:
          ((raw['unlocked_weapons'] as List<dynamic>?) ?? const <dynamic>[])
              .cast<String>()
              .toSet(),
    );
  }

  /// 结算入账：[merit] 全额计入余额；首通（[levelNo] 超越最远记录）
  /// 奖励 1 天赋点。返回 (实际入账功德, 是否首通)。
  Future<(int, bool)> settleRun({
    required int merit,
    required int kills,
    required int levelNo,
  }) async {
    await ensureLoaded();
    final firstClear = levelNo > _state.farthestLevelNo;
    final poolGain = firstClear && _state.farthestLevelNo < talentPoolTotal
        ? 1
        : 0;
    _state = JourneyProgressModel(
      meritBalance: _state.meritBalance + merit,
      farthestLevelNo:
          levelNo > _state.farthestLevelNo ? levelNo : _state.farthestLevelNo,
      totalKills: _state.totalKills + kills,
      talentPool: _state.talentPool + poolGain,
      talentPoints: _state.talentPoints,
      unlockedCharacters: _state.unlockedCharacters,
      unlockedWeapons: _state.unlockedWeapons,
    );
    await _persist();
    return (merit, firstClear);
  }

  /// 天赋层可点判定（相生相克前置+点池）。
  /// 返回 null=可点；否则返回不可点原因文案。
  String? talentBlockReason(JourneyTalentModel talent) {
    final taken = _state.talentLevelsOf(talent.element);
    if (talent.seq != taken + 1) return '需先点亮前置层';
    if (_state.talentPool <= 0) return '天赋点不足（通关新难+1 点）';

    if (talent.isSignature) {
      // 标志层：本系 16 层满 + 克我者 ≥4 层
      if (taken < 16) return '需本系 16 层修满';
      final restrainer = restrainerOf[talent.element]!;
      final restrainerLv = _state.talentLevelsOf(restrainer);
      if (restrainerLv < JourneyTalentModel.signaturePrereqRestrainer) {
        final rn = restrainerOfName(restrainer);
        return '需「$rn」系 ≥${JourneyTalentModel.signaturePrereqRestrainer} 层';
      }
      return null;
    }

    final need = talent.prereqFrom();
    if (need <= 0) return null;
    final generator = generatorOf[talent.element]!;
    final generatorLv = _state.talentLevelsOf(generator);
    if (generatorLv < need) {
      final gn = restrainerOfName(generator);
      return '需「$gn」系 ≥$need 层';
    }
    return null;
  }

  static String restrainerOfName(String element) =>
      switch (element) {
        'metal' => '金',
        'wood' => '木',
        'water' => '水',
        'fire' => '火',
        'earth' => '土',
        _ => element,
      };

  /// 点天赋层：点池够且前置满足则记账并返回 true。
  Future<bool> spendTalent(JourneyTalentModel talent) async {
    await ensureLoaded();
    if (talentBlockReason(talent) != null) return false;
    final points = Map<String, int>.of(_state.talentPoints);
    points['${talent.element}:${talent.seq}'] = 1;
    _state = JourneyProgressModel(
      meritBalance: _state.meritBalance,
      farthestLevelNo: _state.farthestLevelNo,
      totalKills: _state.totalKills,
      talentPool: _state.talentPool - 1,
      talentPoints: points,
      unlockedCharacters: _state.unlockedCharacters,
      unlockedWeapons: _state.unlockedWeapons,
    );
    await _persist();
    return true;
  }

  /// 记录角色解锁并扣减功德定价（进度门槛由调用方校验）。
  /// 返回是否实际解锁（功德不足/重复解锁为 false）。
  Future<bool> unlockCharacter(String code, {int meritCost = 0}) async {
    await ensureLoaded();
    if (_state.meritBalance < meritCost) return false;
    if (_state.unlockedCharacters.contains(code)) return false;
    // 解锁与扣费合并为一次状态变更+落盘，避免中途失败出现「已解锁未扣费」
    final next = Set<String>.of(_state.unlockedCharacters)..add(code);
    _state = JourneyProgressModel(
      meritBalance: _state.meritBalance - meritCost,
      farthestLevelNo: _state.farthestLevelNo,
      totalKills: _state.totalKills,
      talentPool: _state.talentPool,
      talentPoints: _state.talentPoints,
      unlockedCharacters: next,
      unlockedWeapons: _state.unlockedWeapons,
    );
    await _persist();
    return true;
  }

  Future<void> unlockWeapon(String code) => _addUnlock(
        code: code,
        isCharacter: false,
      );

  /// 切换出战角色（仅已解锁角色；持久化供下次进页恢复）。
  Future<void> selectCharacter(String code) async {
    await ensureLoaded();
    if (selectedCharacterCode == code) return;
    selectedCharacterCode = code;
    await _persist();
  }

  Future<void> _addUnlock({
    required String code,
    required bool isCharacter,
  }) async {
    await ensureLoaded();
    final existing = isCharacter
        ? _state.unlockedCharacters
        : _state.unlockedWeapons;
    if (existing.contains(code)) return;
    final next = Set<String>.of(existing)..add(code);
    _state = JourneyProgressModel(
      meritBalance: _state.meritBalance,
      farthestLevelNo: _state.farthestLevelNo,
      totalKills: _state.totalKills,
      talentPool: _state.talentPool,
      talentPoints: _state.talentPoints,
      unlockedCharacters:
          isCharacter ? next : _state.unlockedCharacters,
      unlockedWeapons: isCharacter ? _state.unlockedWeapons : next,
    );
    await _persist();
  }

  Future<void> _persist() async {
    await CacheHelper.instance.saveMap(_storeKey, <String, dynamic>{
      'merit_balance': _state.meritBalance,
      'farthest_level_no': _state.farthestLevelNo,
      'total_kills': _state.totalKills,
      'talent_pool': _state.talentPool,
      'talent_points': _state.talentPoints,
      'unlocked_characters': _state.unlockedCharacters.toList(),
      'unlocked_weapons': _state.unlockedWeapons.toList(),
      'selected_character': selectedCharacterCode,
    });
    notifyListeners();
  }
}
