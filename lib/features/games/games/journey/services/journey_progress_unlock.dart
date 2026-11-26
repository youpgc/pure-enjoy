part of 'journey_progress_service.dart';

/// 西行·统一解锁流程：条件校验 → 扣功德 → 写流水 → 写解锁条目 → 双写持久化。
/// 以 part 形式访问宿主私有进度状态，避免把解锁状态拆成第二份真源。
extension JourneyProgressUnlock on JourneyProgressService {
  /// 目标是否已解锁：统一条目优先；旧图鉴解锁列继续生效，老档不回退。
  bool isUnlockGranted(String targetKind, String targetCode) {
    if (_state.entryUnlocked(targetKind, targetCode)) return true;
    if (targetKind == 'weapon' || targetKind == 'passive') {
      return _state.unlockedWeapons.contains(targetCode);
    }
    return false;
  }

  /// 目标是否需要门控：无规则即不设门控（后台未配置时行为不变）。
  bool needsUnlock(String targetKind, String targetCode) {
    final entry = JourneyConfigService.instance.cached
        ?.unlockEntry(targetKind, targetCode);
    return entry != null && !isUnlockGranted(targetKind, targetCode);
  }

  /// 法宝/被动门控：与图鉴购买共用交叉解析，后台把目标错配到另一类时
  /// 仍按同一条规则判定，避免「买得到却进不了池」或反向绕过。
  bool needsWeaponUnlock(String code) {
    final entry = JourneyConfigService.instance.cached?.unlockEntryForWeapon(code);
    return entry != null && !isUnlockGranted(entry.targetKind, code);
  }

  /// 条件判定与图鉴展示共用模型层的统一判定，避免两端口径漂移。
  /// 妖王击杀需远端真源，仅该条件走一次异步拉取；其余条件纯本地判定。
  Future<bool> _conditionMet(JourneyUnlockEntryModel entry) async {
    var bossKills = const <String, int>{};
    if (entry.conditionType == 'boss_killed') {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return false;
      final kills =
          await JourneyProgressSync.fetchBossKills(userId, entry.conditionValue);
      bossKills = <String, int>{entry.conditionValue: kills};
    }
    return journeyUnlockConditionMet(
      entry,
      JourneyUnlockConditionContext(
        farthestLevelNo: _state.farthestLevelNo,
        totalKills: _state.totalKills,
        totalMeritEarned: _state.totalMeritEarned,
        unlockedAchievements: _state.unlockedAchievements,
        bossKills: bossKills,
      ),
    );
  }

  /// 统一解锁入口：条件不满足 / 功德不足 / 重复解锁均返回 false。
  Future<bool> unlockTarget(String targetKind, String targetCode) async {
    await ensureLoaded();
    final entry = JourneyConfigService.instance.cached
        ?.unlockEntry(targetKind, targetCode);
    if (entry == null) return false;
    if (isUnlockGranted(targetKind, targetCode)) return false;
    if (!await _conditionMet(entry)) return false;
    return _commitUnlock(
      targetKind: targetKind,
      targetCode: targetCode,
      cost: entry.meritCost,
      remark: entry.remark.isNotEmpty ? entry.remark : entry.entryKey,
    );
  }

  /// 图鉴/功德直购兼容入口：优先走统一规则；规则尚未配置时回落旧图鉴
  /// 定价，仍统一写 unlock_spend 流水，补齐此前「解锁不落账」的缺口。
  Future<bool> unlockWeaponWithMerit(String weaponCode) async {
    await ensureLoaded();
    final cached = JourneyConfigService.instance.cached;
    if (isUnlockGranted('passive', weaponCode) ||
        isUnlockGranted('weapon', weaponCode)) {
      return false;
    }
    final kind = cached?.weaponOf(weaponCode)?.category == 'passive'
        ? 'passive'
        : 'weapon';
    final entry = cached?.unlockEntryForWeapon(weaponCode);
    if (entry != null) return unlockTarget(entry.targetKind, entry.targetCode);

    final cost = cached?.relicOf(weaponCode)?.meritCost ?? 0;
    if (_state.meritBalance < cost) return false;
    return _commitUnlock(
      targetKind: kind,
      targetCode: weaponCode,
      cost: cost,
      remark: cached?.weaponOf(weaponCode)?.name ?? weaponCode,
    );
  }

  /// 扣功德 + 落条目 + 写流水一次完成，避免中途失败出现「已解锁未扣费」。
  Future<bool> _commitUnlock({
    required String targetKind,
    required String targetCode,
    required int cost,
    required String remark,
  }) async {
    // 负定价会让扣减变成加功德，后台误配时直接拒绝，不放行任何写入。
    if (cost < 0 || _state.meritBalance < cost) return false;
    final newBalance = _state.meritBalance - cost;
    final record = JourneyMeritRecordModel(
      id: const Uuid().v4(),
      delta: -cost,
      balanceAfter: newBalance,
      sourceType: 'unlock_spend',
      refType: targetKind,
      refId: targetCode,
      remark: '解锁$remark',
      createdAt: journeyBjNow(),
    );
    final entries = <String>{
      ..._state.unlockedEntries,
      '$targetKind:$targetCode',
    };
    Set<String>? weapons;
    if (targetKind == 'weapon' || targetKind == 'passive') {
      weapons = <String>{..._state.unlockedWeapons, targetCode};
    }
    _state = _copyState(
      meritBalance: newBalance,
      unlockedEntries: entries,
      unlockedWeapons: weapons,
      meritRecords: <JourneyMeritRecordModel>[
        record,
        ..._state.meritRecords,
      ].take(JourneyProgressService._recordLimit).toList(),
    );
    await _persist();
    // 等待流水上报完成，避免远端已扣费但流水缺行造成审计断账。
    await JourneyProgressSync.syncMeritRecord(record);
    return true;
  }
}
