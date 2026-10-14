part of 'game_reward_service.dart';

/// 统一结算编排（change-server：服务端权威）。
///
/// 「方案 B 先编排、后发放」全语义已移植至后端 `GameSettlementService`
/// （可重复通关 / 双额度全链止付 / 成绩区间 dimension+gte/lte / 成就分桶 /
/// 累计成就 / 段位徽章 / 复合荣誉），本方法收敛为单次 settle 调用 + 明细映射：
/// 成绩落库与奖励发放同一请求（score_id= settleToken 幂等，重试同键不重复发放）。
extension GameRewardSettlement on GameRewardService {
  /// 统一结算：上报成绩并返回服务端发放明细。
  ///
  /// [scoreValuesByCode] 为「维度编码 → 取值」（含引擎注入判定维度，服务端按
  /// 同一口径判定成就与规则）；[cumulativeTotals] 为累计指标总值（方案 A 口径）；
  /// [endlessRounds] 仅无尽会话传入（随请求落库）；[rewardsAllowed]=false 仅落成绩
  /// （默认合成关流程不发分）。
  Future<GameSettlementResult> settleGame({
    required GameModel game,
    required GameLevelModel level,
    required Map<String, num> scoreValuesByCode,
    required bool cleared,
    required String settleToken,
    String? statusOverride,
    required int durationMs,
    bool rewardsAllowed = true,
    Map<String, int> cumulativeTotals = const <String, int>{},
    List<GameEndlessRound> endlessRounds = const <GameEndlessRound>[],
  }) async {
    // 成绩与发放同一请求：failed/aborted 局也必须走 settle（成绩要落库）；
    // 服务端仅 completed 触发发放，非通关局返回空明细（与现网「不发分」语义一致）。
    final outcome = await GameScoreService.instance.settle(
      gameCode: game.code,
      settleToken: settleToken,
      levelId: _sanitizeUuid(level.id),
      modeId: _resolveModeId(game, level),
      cleared: cleared,
      statusOverride: statusOverride,
      durationMs: durationMs,
      rewardsAllowed: rewardsAllowed,
      valuesByCode: scoreValuesByCode,
      cumulativeTotals: cumulativeTotals,
      endlessRounds: endlessRounds,
    );
    if (outcome == null) {
      throw Exception('结算上报失败（game=${game.code}）');
    }
    final items = <GameSettlementItem>[
      for (final row in outcome.rewards)
        GameSettlementItem(
          kind: _kindOfClaimKey(row['claim_key']?.toString() ?? ''),
          label: row['label']?.toString() ?? '',
          points: (row['points'] as num?)?.toInt() ?? 0,
          granted: row['granted'] == true,
          reason: row['reason']?.toString(),
        ),
    ];
    // 本局有实际发放 → 广播积分刷新（旧 claim 链每次发分后 fire 的等价闭环）
    if (items.any((e) => e.granted)) {
      EventBus.instance.fire(EventType.pointsUpdated);
    }
    return GameSettlementResult(items: items, scoreId: outcome.scoreId);
  }

  /// claim_key 前缀 → 结算页种类（与现网 kind 集合一致）。
  String _kindOfClaimKey(String claimKey) {
    if (claimKey.startsWith('level_clear')) return 'level_clear';
    if (claimKey.startsWith('daily_first_clear')) return 'daily_first_clear';
    if (claimKey.startsWith('score_range')) return 'score_range';
    return 'achievement';
  }

  /// 非 uuid 的合成关 id 置 null（endless_2048_N 等无关卡行，后端 level 可空）。
  String? _sanitizeUuid(String? v) =>
      (v != null && _uuidRe.hasMatch(v)) ? v : null;

  /// 模式 id：常规关卡直传；合成关（默认流程/无尽）mode_id 缺失时按快照回退——
  /// 无尽模式优先，否则取该游戏首个模式（后端 mode_id 必填且需真实模式行）。
  String _resolveModeId(GameModel game, GameLevelModel level) {
    final byLevel = _sanitizeUuid(level.modeId);
    if (byLevel != null) return byLevel;
    final modes = GameService.instance.cachedConfig.modesOf(game.id);
    for (final m in modes) {
      if (m.isEndless) return m.id;
    }
    return modes.isNotEmpty ? modes.first.id : level.modeId;
  }
}
