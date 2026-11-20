part of 'journey_progress_service.dart';

/// 局外玩法扩展（还魂复活 / 图鉴功德解锁 / 成就判定）：
/// 独立于核心进度持久化的局外玩法逻辑。
extension JourneyProgressExtras on JourneyProgressService {
  // ---- 局外玩法（M3 节点 5/10/13）：还魂复活 / 图鉴解锁 / 成就判定 ----

  /// 还魂复活扣功德：消耗 = 基准价 × 当前角色等级并封顶，与局内确认价
  /// 同源；单局次数由局内状态控制。功德不足返回 false；成功落流水
  /// （source_type='revive_spend'）并触发还魂成就单查。
  Future<bool> spendRevive(int charLevel) async {
    await ensureLoaded();
    final snapshot = JourneyConfigService.instance.cached;
    final cost = snapshot?.reviveCostFor(charLevel) ??
        (kJourneyReviveMeritBase * charLevel).clamp(0, kJourneyReviveMeritCap);
    if (_state.meritBalance < cost) return false;
    final newBalance = _state.meritBalance - cost;
    final record = JourneyMeritRecordModel(
      id: const Uuid().v4(),
      delta: -cost,
      balanceAfter: newBalance,
      sourceType: 'revive_spend',
      refType: 'revive',
      refId: charLevel.toString(),
      remark: '角色 Lv$charLevel 还魂复活',
      createdAt: journeyBjNow(),
    );
    _state = _copyState(
      meritBalance: newBalance,
      meritRecords: <JourneyMeritRecordModel>[record, ..._state.meritRecords]
          .take(JourneyProgressService._recordLimit)
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

  /// 从远端回拉本游戏已解锁成就 code 并并入本地状态（清缓存后恢复点亮态）。
  /// 取并集：远端已解锁的补亮；本地已有但远端暂不可达的保留（离线兼容）。
  Future<void> syncUnlockedAchievements() async {
    await ensureLoaded();
    final userId = AuthService.instance.currentUserId;
    final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
    if (userId == null || gameId.isEmpty) return;
    final remote = await JourneyProgressSync.fetchUnlockedAchievementCodes(
      gameId,
      userId,
    );
    if (remote.isEmpty) return;
    final merged = Set<String>.of(_state.unlockedAchievements)..addAll(remote);
    if (merged.length == _state.unlockedAchievements.length) return;
    _state = _copyState(unlockedAchievements: merged);
    await _persist();
  }

  /// 成就页/图鉴页进入时的统一成就态刷新：先回拉远端已解锁 code
  /// （清缓存恢复），再判定新达成项并 best-effort 写远端。
  /// 顺序固定（先 sync 后 evaluate），避免 evaluate 写库后 sync 拿旧快照
  /// 覆盖；两页共用同一入口，口径一致。
  Future<void> refreshAchievementState() async {
    await syncUnlockedAchievements();
    await evaluateAchievements();
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
