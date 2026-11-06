import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../../services/supabase_service.dart';
import '../../../../../utils/cache_helper.dart';
import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import 'journey_config_service.dart';
import 'journey_progress_sync.dart';
import 'journey_seed.dart';
import 'journey_time.dart';

part 'journey_progress_talent.dart';

/// 西行·用户进度服务（本地持久化优先，登录态双写远端）。
///
/// 功德余额/天赋分支等级/流水/解锁记录先落本地（CacheHelper），保证
/// 离线可玩；登录态下进度行（journey_progress）与流水/对局记录
/// best-effort 同步远端，双写以 updated_at 新者胜，失败静默不阻塞本地。
class JourneyProgressService extends ChangeNotifier {
  JourneyProgressService._();

  static final JourneyProgressService instance = JourneyProgressService._();

  static const String _storeKey = 'journey_progress_v1';

  /// 天赋点树内总层数参考口径（5 系×16 + 加强点 1；点池本身不设上限，
  /// 首通/妖王掉点可自由累积）。
  static const int talentPoolTotal = 81;

  /// 本地流水/对局记录保留条数（新的在前）。
  static const int _recordLimit = 50;

  /// 相生链：生我者（分支升第 2 级起需先修其生源系）。
  static const Map<String, String> generatorOf = <String, String>{
    'metal': 'earth', // 土生金
    'water': 'metal', // 金生水
    'wood': 'water', // 水生木
    'fire': 'wood', // 木生火
    'earth': 'fire', // 火生土
  };

  /// 相克链：克我者（标志分支需修克我者≥4 层作制衡代价）。
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

  /// 本地进度最后更新时间（CacheHelper 键 'updated_at' ISO 字符串；
  /// 与远端 journey_progress.updated_at 比较做双写新者胜，首次 null 视为远端新）。
  DateTime? _updatedAt;

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await CacheHelper.instance.loadMap(_storeKey);
    if (raw != null) {
      selectedCharacterCode =
          raw['selected_character'] as String? ?? selectedCharacterCode;
      // 天赋等级读档：新结构 talent_levels={char:{branch:lv}}（角色专属树）。
      // 旧扁平行（value 为数字，改版前全局树）与更旧的 'talent_points'
      // （element:seq 结构）一并整体忽略视为空——旧投入清零，功德返还由
      // SQL 迁移侧远端执行，本地新者胜后采纳远端行。
      _state = JourneyProgressModel(
        meritBalance: (raw['merit_balance'] as num?)?.toInt() ?? 0,
        farthestLevelNo: (raw['farthest_level_no'] as num?)?.toInt() ?? 0,
        totalKills: (raw['total_kills'] as num?)?.toInt() ?? 0,
        talentPools: _parseTalentPools(raw['talent_pools']),
        talentLevels: _parseTalentLevels(raw['talent_levels']),
        meritRecords: _parseRecords(
            raw['merit_records'], JourneyMeritRecordModel.fromJson),
        runRecords:
            _parseRecords(raw['run_records'], JourneyRunRecordModel.fromJson),
        unlockedCharacters:
            ((raw['unlocked_characters'] as List<dynamic>?) ?? const <dynamic>[])
                .cast<String>()
                .toSet(),
        unlockedWeapons:
            ((raw['unlocked_weapons'] as List<dynamic>?) ?? const <dynamic>[])
                .cast<String>()
                .toSet(),
        unlockedAchievements:
            ((raw['unlocked_achievements'] as List<dynamic>?) ??
                    const <dynamic>[])
                .cast<String>()
                .toSet(),
      );
      _updatedAt = DateTime.tryParse(raw['updated_at'] as String? ?? '');
    }
    await _pullRemoteProgress();
  }

  /// 节点 13·进度服务端化：登录态下拉取远端进度行，远端 updated_at 比
  /// 本地新时覆盖本地（双写新者胜；流水/对局记录仅本地缓存不参与覆盖）。
  Future<void> _pullRemoteProgress() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    final row = await JourneyProgressSync.fetchProgressRow(userId);
    if (row == null) return;
    final remoteAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');
    // 远端 updated_at 为 UTC 绝对时刻 → 先转北京墙钟（固定 +8h）再比：
    // 与本地 journeyBjNow() 落盘口径一致（8h 偏移两侧相抵，新者胜不漂移）
    final remoteBj = remoteAt == null ? null : journeyBjFromUtc(remoteAt);
    if (_updatedAt != null &&
        (remoteBj == null || !remoteBj.isAfter(_updatedAt!))) {
      return; // 本地更新或远端缺时间戳，维持本地
    }
    // 列缺失传 null → _copyState 回落本地值，语义等价 ?? _state.x
    _state = _copyState(
      meritBalance: (row['merit_balance'] as num?)?.toInt(),
      farthestLevelNo: (row['farthest_level_no'] as num?)?.toInt(),
      totalKills: (row['total_kills'] as num?)?.toInt(),
      talentPools: _parseTalentPools(row['talent_pools']),
      talentLevels: _parseTalentLevels(row['talent_levels']),
      unlockedCharacters:
          ((row['unlocked_characters'] as List<dynamic>?) ?? const <dynamic>[])
              .cast<String>()
              .toSet(),
      unlockedWeapons:
          ((row['unlocked_weapons'] as List<dynamic>?) ?? const <dynamic>[])
              .cast<String>()
              .toSet(),
    );
    selectedCharacterCode =
        row['selected_character'] as String? ?? selectedCharacterCode;
    _updatedAt = remoteBj;
    notifyListeners();
  }

  /// 天赋等级解析（v4 结构 {char:{'{char}_{elem}_{branch}':lv}}）：末段为
  /// core/growth/sig 的键直读（分支上限钳制在点亮侧）；旧结构键（v3 系键 /
  /// v2 分支编码）聚合系总层数后按 **core 承接 min8** 转为 v4 分支键——
  /// 与 SQL 迁移口径一致，防止本地旧档经新者胜写回远端破坏 v4 结构
  /// （溢出层数退点由远端迁移负责，本地兜底不重复退）。
  static Map<String, Map<String, int>> _parseTalentLevels(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const <String, Map<String, int>>{};
    final parsed = <String, Map<String, int>>{};
    raw.forEach((char, tree) {
      if (tree is! Map<String, dynamic>) return; // 旧扁平行：整体忽略
      final out = <String, int>{};
      final legacyTotals = <String, int>{};
      tree.forEach((key, value) {
        final lv = value is num ? value.toInt() : 0;
        if (lv <= 0) return;
        final parts = key.split('_');
        final last = parts.isNotEmpty ? parts.last : '';
        if (kJourneyTalentBranchTypes.contains(last)) {
          out[key] = lv; // v4 分支键直读
        } else if (key == kJourneyTalentEnhanceKey) {
          out[key] = 1; // 加强点钳 1
        } else if (parts.length >= 2) {
          // v2 分支编码 {char}_{elem}_{词}：聚合到系
          final e = parts[1];
          legacyTotals[e] = (legacyTotals[e] ?? 0) + lv;
        } else if (kJourneyTalentElements.contains(key)) {
          // v3 系键 {char:{element:lv}}
          legacyTotals[key] = (legacyTotals[key] ?? 0) + lv;
        }
      });
      // 旧结构 → v4：本源枝承接 min(8)（已有 v4 core 键取较大值防覆盖）
      legacyTotals.forEach((e, total) {
        final code = journeyBranchCode(char, e, 'core');
        final carried = total > 8 ? 8 : total;
        out[code] = carried > (out[code] ?? 0)
            ? carried
            : (out[code] ?? carried);
      });
      parsed[char] = out;
    });
    return parsed;
  }

  /// 角色天赋点池解析（talent_pools jsonb：{charCode: 点数}；缺省空表）。
  static Map<String, int> _parseTalentPools(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const <String, int>{};
    return <String, int>{
      for (final e in raw.entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    };
  }

  /// 本地记录解析：截断为 [_recordLimit] 条（旧脏数据自动丢弃）。
  static List<T> _parseRecords<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List<dynamic>) return <T>[];
    return raw.whereType<Map<String, dynamic>>().map(fromJson).take(_recordLimit).toList();
  }

  /// 全字段状态拷贝（未覆盖项沿用当前 [_state]；新增字段统一在此透传，
  /// 各变更点不再手工罗列全部字段）。
  JourneyProgressModel _copyState({
    int? meritBalance,
    int? farthestLevelNo,
    int? totalKills,
    Map<String, int>? talentPools,
    Map<String, Map<String, int>>? talentLevels,
    List<JourneyMeritRecordModel>? meritRecords,
    List<JourneyRunRecordModel>? runRecords,
    Set<String>? unlockedCharacters,
    Set<String>? unlockedWeapons,
    Set<String>? unlockedAchievements,
  }) =>
      JourneyProgressModel(
        meritBalance: meritBalance ?? _state.meritBalance,
        farthestLevelNo: farthestLevelNo ?? _state.farthestLevelNo,
        totalKills: totalKills ?? _state.totalKills,
        talentPools: talentPools ?? _state.talentPools,
        talentLevels: talentLevels ?? _state.talentLevels,
        meritRecords: meritRecords ?? _state.meritRecords,
        runRecords: runRecords ?? _state.runRecords,
        unlockedCharacters: unlockedCharacters ?? _state.unlockedCharacters,
        unlockedWeapons: unlockedWeapons ?? _state.unlockedWeapons,
        unlockedAchievements: unlockedAchievements ?? _state.unlockedAchievements,
      );

  /// 分支升级功德消耗：cost_base × (已修等级+1)，线性递增。
  /// 实现拆分见 journey_progress_talent.dart（part 同 library）。

  static String restrainerOfName(String element) =>
      switch (element) {
        'metal' => '金',
        'wood' => '木',
        'water' => '水',
        'fire' => '火',
        'earth' => '土',
        _ => element,
      };

  /// 结算入账：[merit] 全额计入余额；首通（[cleared] 且 [levelNo] 超越最远
  /// 记录）全部角色天赋点池各 +1；同时落对局记录与功德流水并远端同步。
  /// 返回 (实际入账功德, 是否首通)。
  Future<(int, bool)> settleRun({
    required int merit,
    required int kills,
    required int levelNo,
    int durationMs = 0,
    bool cleared = false,
    String kind = 'mainline',
    String levelTitle = '',
  }) async {
    await ensureLoaded();
    // 首通判定：仅主线（level_no≥1）可推进；level_no≤0 的无尽/游历模式
    // 即使 cleared 也不推 farthest/不发天赋点（kills/功德流水照记）
    final firstClear = cleared && levelNo > 0 && levelNo > _state.farthestLevelNo;
    // 首通发点（角色专属树）：全部角色独立点池各 +1（点池不设上限）
    final poolGain = firstClear;
    Map<String, int>? nextPools;
    if (poolGain) {
      nextPools = Map<String, int>.of(_state.talentPools);
      for (final char in kJourneyTalentChars) {
        nextPools[char] = (nextPools[char] ?? 0) + 1;
      }
    }
    final newBalance = _state.meritBalance + merit;
    final meritRecord = JourneyMeritRecordModel(
      id: const Uuid().v4(),
      delta: merit,
      balanceAfter: newBalance,
      sourceType: 'run_settle',
      refType: 'level',
      refId: levelNo.toString(),
      // 虚拟关（无尽/游历 level_no≤0）不带难号
      remark: levelNo > 0 ? '第$levelNo难结算' : '模式对局结算',
      createdAt: journeyBjNow(),
    );
    final runRecord = JourneyRunRecordModel(
      id: const Uuid().v4(),
      levelNo: levelNo,
      kills: kills,
      meritGained: merit,
      durationMs: durationMs,
      cleared: cleared,
      kind: kind,
      levelTitle: levelTitle,
      createdAt: journeyBjNow(),
    );
    _state = _copyState(
      meritBalance: newBalance,
      farthestLevelNo: firstClear ? levelNo : _state.farthestLevelNo,
      totalKills: _state.totalKills + kills,
      talentPools: nextPools,
      meritRecords: <JourneyMeritRecordModel>[
        meritRecord,
        ..._state.meritRecords,
      ].take(_recordLimit).toList(),
      runRecords: <JourneyRunRecordModel>[runRecord, ..._state.runRecords]
          .take(_recordLimit)
          .toList(),
    );
    await _persist();
    JourneyProgressSync.syncMeritRecord(meritRecord);
    JourneyProgressSync.syncRunRecord(runRecord);
    // 结算尾部触发成就判定（还魂成就由 spendRevive 成功后单查触发）
    await evaluateAchievements();
    return (merit, firstClear);
  }

  /// 妖王天赋点掉落入账：末场伏诛概率判定命中后调用，全部角色独立
  /// 点池各 +1（点池不设上限）。返回恒 true（横幅据实提示掉落）。
  Future<bool> grantTalentDrop() async {
    await ensureLoaded();
    final pools = Map<String, int>.of(_state.talentPools);
    for (final char in kJourneyTalentChars) {
      pools[char] = (pools[char] ?? 0) + 1;
    }
    _state = _copyState(talentPools: pools);
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
    final newBalance = _state.meritBalance - meritCost;
    final next = Set<String>.of(_state.unlockedCharacters)..add(code);
    final record = meritCost > 0
        ? JourneyMeritRecordModel(
            id: const Uuid().v4(),
            delta: -meritCost,
            balanceAfter: newBalance,
            sourceType: 'character_unlock',
            refType: 'character',
            refId: code,
            remark: '解锁角色',
            createdAt: journeyBjNow(),
          )
        : null;
    _state = _copyState(
      meritBalance: newBalance,
      meritRecords: record == null
          ? _state.meritRecords
          : <JourneyMeritRecordModel>[record, ..._state.meritRecords]
              .take(_recordLimit)
              .toList(),
      unlockedCharacters: next,
      // 主动法宝跟随角色解锁：character_code 归属该角色的法宝一并入池
      unlockedWeapons: _boundWeaponsOf(code),
    );
    await _persist();
    if (record != null) JourneyProgressSync.syncMeritRecord(record);
    return true;
  }

  /// 归属 [characterCode] 且尚未解锁的法宝集合（角色解锁联动入池；
  /// 无绑定法宝时返回 null 不动原集合）。
  Set<String>? _boundWeaponsOf(String characterCode) {
    final weapons =
        JourneyConfigService.instance.cached?.weapons ?? const <JourneyWeaponModel>[];
    final bound = weapons
        .where((w) => w.characterCode == characterCode)
        .map((w) => w.code)
        .where((c) => !_state.unlockedWeapons.contains(c))
        .toSet();
    if (bound.isEmpty) return null;
    return <String>{..._state.unlockedWeapons, ...bound};
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
    final existing =
        isCharacter ? _state.unlockedCharacters : _state.unlockedWeapons;
    if (existing.contains(code)) return;
    final next = Set<String>.of(existing)..add(code);
    _state = _copyState(
      unlockedCharacters: isCharacter ? next : null,
      unlockedWeapons: isCharacter ? null : next,
    );
    await _persist();
  }

  Future<void> _persist() async {
    // 北京墙钟 ISO（isUtc 标记，字段=BJ 墙钟；Z 后缀保证跨设备解析同口径，
    // 远端 timestamptz 拉回后经 journeyBjFromUtc 转 BJ 再比，见 _pullRemoteProgress）
    final updatedAt = journeyBjNow().toIso8601String();
    await CacheHelper.instance.saveMap(_storeKey, <String, dynamic>{
      'merit_balance': _state.meritBalance,
      'farthest_level_no': _state.farthestLevelNo,
      'total_kills': _state.totalKills,
      'talent_pools': _state.talentPools,
      'talent_levels': _state.talentLevels,
      'merit_records': _state.meritRecords.map((r) => r.toJson()).toList(),
      'run_records': _state.runRecords.map((r) => r.toJson()).toList(),
      'unlocked_characters': _state.unlockedCharacters.toList(),
      'unlocked_weapons': _state.unlockedWeapons.toList(),
      'unlocked_achievements': _state.unlockedAchievements.toList(),
      'selected_character': selectedCharacterCode,
      'updated_at': updatedAt,
    });
    _updatedAt = DateTime.tryParse(updatedAt);
    notifyListeners();
    // 登录态下 best-effort upsert 进度行（journey_progress），失败静默
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    await JourneyProgressSync.upsertProgressRow(userId, <String, dynamic>{
      'user_id': userId,
      'merit_balance': _state.meritBalance,
      'farthest_level_no': _state.farthestLevelNo,
      'total_kills': _state.totalKills,
      // 旧全局点池列（改版后仅作兼容镜像，App 消费 talent_pools）
      'talent_pool': _state.talentPoolOf(selectedCharacterCode),
      'talent_pools': _state.talentPools,
      'talent_levels': _state.talentLevels,
      'unlocked_characters': _state.unlockedCharacters.toList(),
      'unlocked_weapons': _state.unlockedWeapons.toList(),
      'selected_character': selectedCharacterCode,
      'updated_at': updatedAt,
    });
  }

  // ---- 局外玩法（M3 节点 5/10/13）：还魂复活 / 图鉴解锁 / 成就判定 ----

  /// 还魂复活扣功德（节点 5）：消耗 = 基准价 × 关卡号（缺省 20×关卡号），
  /// 单局次数由局内状态控制。功德不足返回 false；成功落流水
  /// （source_type='revive_spend'）并触发还魂成就单查。
  Future<bool> spendRevive(int levelNo) async {
    await ensureLoaded();
    final snapshot = JourneyConfigService.instance.cached;
    final cost = snapshot?.reviveCostFor(levelNo) ?? 20 * levelNo;
    if (_state.meritBalance < cost) return false;
    final newBalance = _state.meritBalance - cost;
    final record = JourneyMeritRecordModel(
      id: const Uuid().v4(),
      delta: -cost,
      balanceAfter: newBalance,
      sourceType: 'revive_spend',
      refType: 'revive',
      refId: levelNo.toString(),
      remark: '第$levelNo难还魂复活',
      createdAt: journeyBjNow(),
    );
    _state = _copyState(
      meritBalance: newBalance,
      meritRecords: <JourneyMeritRecordModel>[record, ..._state.meritRecords]
          .take(_recordLimit)
          .toList(),
    );
    await _persist();
    JourneyProgressSync.syncMeritRecord(record);
    // 还魂成就（revived 条件）单查：本局还魂 1 次
    await evaluateAchievements(revivedCount: 1);
    return true;
  }

  /// 图鉴解锁（功德定价）：按 journey_relic_unlocks 配置取 merit_cost；
  /// 重复解锁/功德不足返回 false。图鉴解锁不产生功德流水
  /// （source_type CHECK 无武器口径），仅扣功德 + 落解锁记录并双写。
  Future<bool> unlockWeaponWithMerit(String weaponCode) async {
    await ensureLoaded();
    if (_state.unlockedWeapons.contains(weaponCode)) return false;
    final relic = JourneyConfigService.instance.cached?.relicOf(weaponCode);
    final cost = relic?.meritCost ?? 0;
    if (_state.meritBalance < cost) return false;
    // 扣费与解锁合并为一次状态变更+落盘，避免中途失败出现「已解锁未扣费」
    _state = _copyState(
      meritBalance: _state.meritBalance - cost,
      unlockedWeapons: Set<String>.of(_state.unlockedWeapons)..add(weaponCode),
    );
    await _persist();
    return true;
  }

  /// 成就判定（西行 6 项种子）：满足条件且未解锁则 best-effort 写
  /// user_game_achievements，返回本次新解锁 code 列表（未登录/配置未就绪/
  /// 拉取失败静默返回空）。[revivedCount] 传本局还魂次数（revived 条件用）。
  Future<List<String>> evaluateAchievements({int revivedCount = 0}) async {
    await ensureLoaded();
    final userId = AuthService.instance.currentUserId;
    final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
    if (userId == null || gameId.isEmpty) return const <String>[];
    final newly = await JourneyProgressSync.evaluateAchievements(
      state: _state,
      gameId: gameId,
      userId: userId,
      revivedCount: revivedCount,
    );
    if (newly.isEmpty) return newly;
    // 新解锁 code 记入本地缓存（幂等去重 + 离线可见），落盘
    _state = _copyState(
      unlockedAchievements: Set<String>.of(_state.unlockedAchievements)..addAll(newly),
    );
    await _persist();
    return newly;
  }
}
