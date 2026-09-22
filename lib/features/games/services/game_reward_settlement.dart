part of 'game_reward_service.dart';

/// 结算候选步骤（【方案 B 2026-09-22】"先编排、后发放"的编排产物，纯数据）。
///
/// [points] = 该项若真实发放将占用的额度分值；本局不会真实发分的项记 0
/// （不计入每日首通的关卡、无积分成就），避免虚增「应发总额」。
/// [skipIfClaimed] = true 表示已领档位在编排阶段已跳过（累计成就原逻辑）。
/// [countsTowardGame] = 该分值是否计入「本游戏单日上限」桶：claim 时带
/// game_id 的为 true；全局成就（game_id=null）只占全局额度，为 false——
/// 否则会把跨游戏成就误算进本游戏额度，导致整条链被误判装不下。
class _SettleStep {
  const _SettleStep({
    required this.kind,
    required this.label,
    required this.points,
    required this.claimKey,
    required this.claim,
    this.skipIfClaimed = false,
    this.countsTowardGame = true,
  });

  final String kind;
  final String label;
  final int points;
  final String claimKey;
  final Future<GameRewardResult> Function() claim;
  final bool skipIfClaimed;
  final bool countsTowardGame;
}

/// 统一结算编排（从 GameRewardService 拆出）：先按顺序评估通关奖励 /
/// 每日首通 / 成绩区间 / 四类成就（阶段一：只编排），再按单日上限剩余额度
/// 决定整条链「全发」或「全不发」（阶段二：统一发放），最后编排段位徽章。
extension GameRewardSettlement on GameRewardService {
  /// 统一结算：评估三类奖励并返回明细。
  ///
  /// [scoreValuesByCode] 为「维度编码 → 取值」（如 {'score': 2048, 'duration_ms': 12345}）。
  /// 成绩上报（game_scores）由调用方负责，本方法只管奖励发放。
  Future<GameSettlementResult> settleGame({
    required GameModel game,
    required GameLevelModel level,
    required Map<String, num> scoreValuesByCode,
    required bool cleared,
  }) async {
    // 未通关不发放任何奖励（通关奖励 / 首通 / 成就均只针对通关，避免失败也发分）
    if (!cleared) {
      return const GameSettlementResult(items: <GameSettlementItem>[]);
    }
    final items = <GameSettlementItem>[];
    final config = await GameService.instance.fetchConfig();

    // 【方案 B 2026-09-22】结算改为「先编排、后发放」两阶段：下方各判定段
    // 只把候选项登记进 steps（不发分），段末统一按本局可发额度决定
    // 「整条链全发」还是「全不发」，消除逐项校验的割裂体验（详见 guardedClaim 注释）。
    final steps = <_SettleStep>[];

    // 上限止付（2026-09-15 用户反馈修复）：本局一旦有奖励因「今日上限」被拦，
    // 后续项目全部止付、不再尝试发放。此前逐项独立校验会出现「大分项被拦
    // （结算页已提示达到上限）、小分项仍通过校验继续发」的割裂体验。
    // 止付与拦截都不占坑（claim 未触发），次日上限刷新后重新通关可重获。
    // 【方案 B 补强】：capHit 只在单次结算内生效，跨结算不持久——此前
    // 「通关奖励（链内第 0 项、金额小）先通过校验发出、后续大项被拦」会在
    // 同一结算页同时出现「已达上限」提示与「+通关奖励」，且每局重复一次
    // （用户实测连续 3 次结算同样现象）。现由段末的额度总判定提前拦住。
    bool capHit = false;
    Future<GameRewardResult> guardedClaim(
      Future<GameRewardResult> Function() run,
    ) async {
      if (capHit) {
        return GameRewardResult.notGranted(
          reason: '今日游戏奖励已达上限，本局不再发放',
        );
      }
      final r = await run();
      if (!r.granted && (r.reason?.contains('上限') ?? false)) capHit = true;
      return r;
    }

    // 判定专用取值：match3 关卡全局关序按后台配置动态推导（_match3GlobalLevelIndex，
    // 累加各模式真实关数），与 `game_levels` 实际数据一致，供 'level' 维度的
    // score_range 规则 / 成就比对。仅用于判定；成绩上报用原始 level_no，不受影响。
    final match3GlobalIndex = game.code == 'match3'
        ? _match3GlobalLevelIndex(config, level)
        : level.levelNo;
    final judgeValues =
        game.code == 'match3' && scoreValuesByCode.containsKey('level')
            ? <String, num>{
                ...scoreValuesByCode,
                'level': match3GlobalIndex,
              }
            : scoreValuesByCode;

    // 本局模式编码：供「模式限定」成就判定（score 条件可选 `mode` 键）。
    // 解析失败为 null 时，带 mode 限定的成就一律跳过（见 pickTopScoreAchievements）。
    final modeCode = resolveGameModeCode(config, game.id, level);

    // 0) 每关通关奖励（rewardPoints<=0 时跳过，结算页不展示无效行）
    //    【方案 B 阶段一：只登记候选，不在此处发放】真实 claim 延迟到段末
    //    额度判定之后，仍统一经 guardedClaim（阶段二）执行，止付语义不变。
    if (level.rewardPoints > 0) {
      steps.add(_SettleStep(
        kind: 'level_clear',
        label: '通关奖励',
        points: level.rewardPoints,
        // 可重复关卡的 key 带随机后缀（真实发放时另生成一个），此处仅用于
        // 阶段二的「已领剔除」——新坑永不命中，正确计为应发项。
        claimKey: levelClearClaimKey(level),
        claim: () => claimLevelReward(gameName: game.name, level: level),
      ));
    }

    // 1) 每日首次通关（仅后台标记为计入的关卡）
    //    【方案 B 阶段一：只登记候选，不在此处发放】真实 claim 延迟到段末
    //    额度判定之后，仍统一经 guardedClaim（阶段二）执行，止付语义不变。
    //    不计入每日首通 / 规则关闭时 points 记 0，不占用「应发总额」
    //    （实际展示原因仍由 claimDailyFirstClear 给出）。
    final dailyRule = config.globalRewardRules.firstWhere(
      (r) => r.ruleType == GameRewardRuleType.dailyFirstClear && r.enabled,
      orElse: () => const GameRewardRuleModel(
        id: '',
        ruleType: GameRewardRuleType.dailyFirstClear,
        points: 3,
      ),
    );
    steps.add(_SettleStep(
      kind: 'daily_first_clear',
      label: '每日首次通关',
      points:
          level.countForDailyClear && dailyRule.enabled ? dailyRule.points : 0,
      claimKey: dailyFirstClearClaimKey(),
      claim: () => claimDailyFirstClear(
        gameId: game.id,
        gameName: game.name,
        level: level,
      ),
    ));

    // 2) 成绩区间首次达成（按该游戏配置的 score_range 规则）
    //    里程碑式分档：只发「本局成绩落入的最高档」一条，其余档位属非本局区间。
    final scoreRules = config.rewardRules
        .where(
          (r) =>
              r.gameId == game.id &&
              r.ruleType == GameRewardRuleType.scoreRange &&
              r.enabled,
        )
        .toList();
    final topRule = pickTopScoreRangeRule(scoreRules, judgeValues);
    if (topRule != null) {
      // 【方案 B 阶段一：只登记候选，不在此处发放】发放见段末 guardedClaim。
      steps.add(_SettleStep(
        kind: 'score_range',
        label: topRule.name ?? '成绩达标',
        points: topRule.points,
        claimKey: scoreRangeClaimKey(game.code, topRule.id),
        claim: () => claimScoreRange(rule: topRule, gameCode: game.code),
      ));
    }

    // 3) 成就达成（按该游戏启用的成就条件 + 全局成就 game_id=null）
    //    全局成就（如 first_clear_all 任意通关全局 +3）跨游戏生效，此前
    //    achievementsOf(game.id) 仅按 game_id 过滤，把 game_id=null 的全局成就
    //    排除在外，导致 first_clear_all 永不发放——此处补齐闭环。
    final achievements = <GameAchievementModel>[
      ...config.achievementsOf(game.id).where((a) => a.enabled),
      ...config.achievements.where((a) => a.gameId == null && a.enabled),
    ];

    // 消消乐全局关序按后台配置动态推导（见 _match3GlobalLevelIndex），
    // 与后台 `game_levels` 实际关数一致，成就 `min_level_no` 阈值按同一口径比对。
    final effectiveLevelNo = match3GlobalIndex;

    // 3a) 「首次通关」类成就：账号终身唯一、全局与单游戏可叠加，
    //     已领取由 claim_key 唯一索引幂等拦截（不二次计算发放）。
    for (final ach in achievements) {
      if (achievementTypeOf(ach) != kAchievementTypeFirstClear) continue;
      // 【方案 B 阶段一：只登记候选，不在此处发放】发放见段末 guardedClaim。
      steps.add(_SettleStep(
        kind: 'achievement',
        label: '成就：${ach.name}',
        points: ach.rewardPoints,
        claimKey: achievementClaimKey(ach.code),
        claim: () => claimAchievement(achievement: ach),
        countsTowardGame: ach.gameId != null,
      ));
    }

    // 3b) 「关卡里程碑」成就：单局至多一条（本局关序对应的最高档）。
    final topLevel = pickTopLevelAchievement(achievements, effectiveLevelNo);
    if (topLevel != null) {
      // 【方案 B 阶段一：只登记候选，不在此处发放】发放见段末 guardedClaim。
      steps.add(_SettleStep(
        kind: 'achievement',
        label: '成就：${topLevel.name}',
        points: topLevel.rewardPoints,
        claimKey: achievementClaimKey(topLevel.code),
        claim: () => claimAchievement(achievement: topLevel),
        countsTowardGame: topLevel.gameId != null,
      ));
    }

    // 3c) 「单局得分里程碑」成就：按维度分桶（同维度再按模式分桶），每桶至多一条
    //    （本局该维度取值对应的最高档）；得分/用时/步数/连击/收集互不遮蔽。
    //    `streak_days` 是跨游戏的全局维度（连续签到天数），按需注入：只有真的
    //    存在用该维度的成就时才查询，避免每局多打一次 point_records 请求。
    var scoreJudgeValues = judgeValues;
    if (achievements
        .any((a) => a.condition['dimension']?.toString() == kDimensionStreakDays)) {
      final uid = AuthService.instance.currentUserId;
      if (uid != null) {
        scoreJudgeValues = <String, num>{
          ...judgeValues,
          kDimensionStreakDays:
              await calcConsecutiveStreak(uid, beijingToday()),
        };
      }
    }
    for (final topScore in pickTopScoreAchievements(achievements, scoreJudgeValues,
        modeCode: modeCode)) {
      // 【方案 B 阶段一：只登记候选，不在此处发放】发放见段末 guardedClaim。
      steps.add(_SettleStep(
        kind: 'achievement',
        label: '成就：${topScore.name}',
        points: topScore.rewardPoints,
        claimKey: achievementClaimKey(topScore.code),
        claim: () => claimAchievement(achievement: topScore),
        countsTowardGame: topScore.gameId != null,
      ));
    }

    // 3d) 「终身累计达成」成就：跨局累计指标（游玩局数/通关次数/合成次数/
    //    消除方块数）达标的每一档都发放。计数由 reportAndSettle 在主流程
    //    记录一次（重试不重放），此处只读总量判定；先批量查已领取档位，
    //    避免每次结算对全部达标档做无效 claim RPC。
    final cumTotals =
        await GameCumulativeService.instance.totalsFor(gameCode: game.code);
    if (cumTotals.isNotEmpty) {
      final met = pickCumulativeAchievements(achievements, cumTotals);
      if (met.isNotEmpty) {
        final claimedKeys = await _fetchClaimedAchievementKeys(met);
        for (final ach in met) {
          if (claimedKeys.contains('achievement:${ach.code}')) continue;
          // 【方案 B 阶段一：只登记候选，不在此处发放】发放见段末 guardedClaim。
          steps.add(_SettleStep(
            kind: 'achievement',
            label: '成就：${ach.name}',
            points: ach.rewardPoints,
            claimKey: achievementClaimKey(ach.code),
            claim: () => claimAchievement(achievement: ach),
            skipIfClaimed: true,
            countsTowardGame: ach.gameId != null,
          ));
        }
      }
    }

    // ── 【方案 B 阶段二：额度总判定 + 统一发放】─────────────────────────
    // 两条额度桶（与 _tryClaim 预检、grant_game_reward 服务端校验同一口径，
    // 先到先拦）：全局桶跨游戏合计，本游戏桶只算带 game_id 的项。
    // 整条链应发总额两桶都装得下才发；装不下则本局一项都不发（不占坑，
    // 明日上限刷新后重新通关可全部重获），结算页只呈现「未发放 + 已达上限」，
    // 不再出现「提示已达上限的同时仍发放通关奖励」。
    var globalRemaining = config.dailyLimit - await _claimedPointsCached();
    var gameRemaining = config.dailyLimitPerGame(game.id) -
        await _claimedPointsCached(gameId: game.id);
    if (globalRemaining < 0) globalRemaining = 0;
    if (gameRemaining < 0) gameRemaining = 0;
    int globalOf(Iterable<_SettleStep> ss) =>
        ss.fold<int>(0, (sum, s) => sum + s.points);
    int gameOf(Iterable<_SettleStep> ss) => ss
        .where((s) => s.countsTowardGame)
        .fold<int>(0, (sum, s) => sum + s.points);

    // 应发总额先用「名义总额」快速判定：两桶都不超时零额外请求；只有可能
    // 装不下时，才用一次查询剔除已领过、实际不会再发分的项（如当日第二局
    // 的每日首通、终身已领成就档位），得到真实应发总额。
    var payableGlobal = globalOf(steps);
    var payableGame = gameOf(steps);
    if (payableGlobal > globalRemaining || payableGame > gameRemaining) {
      final planClaimed = await _fetchClaimedKeysForPlan(
        steps.where((s) => !s.skipIfClaimed).map((s) => s.claimKey),
      );
      final payable = steps
          .where((s) => s.skipIfClaimed || !planClaimed.contains(s.claimKey))
          .toList();
      payableGlobal = globalOf(payable);
      payableGame = gameOf(payable);
    }
    final overGlobal = payableGlobal > globalRemaining;
    final overGame = payableGame > gameRemaining;

    if (steps.isNotEmpty && (overGlobal || overGame)) {
      capHit = true;
      final quotaDesc = overGlobal && overGame
          ? '全局剩余额度 $globalRemaining 分、本游戏剩余额度 $gameRemaining 分'
          : overGlobal
              ? '全局剩余额度 $globalRemaining 分'
              : '本游戏剩余额度 $gameRemaining 分';
      final payableDesc = overGlobal ? payableGlobal : payableGame;
      final reason = '今日游戏奖励已达上限（$quotaDesc，本局应发 '
          '$payableDesc 分），本局不发放';
      for (final s in steps) {
        items.add(GameSettlementItem(
          kind: s.kind,
          label: s.label,
          points: 0,
          granted: false,
          reason: reason,
        ));
      }
    } else {
      for (final s in steps) {
        final r = await guardedClaim(s.claim);
        items.add(GameSettlementItem(
          kind: s.kind,
          label: s.label,
          points: r.points,
          granted: r.granted,
          reason: r.reason,
        ));
      }
    }

    // 4) 模式段位徽章（v2 徽章化 q-0：成就=纯荣誉，0 积分，仅记录解锁）。
    //    判定与落库见 GameBadgeService（体量拆分），此处只编排结果展示。
    //    上限止付命中时整段跳过：徽章发分同样计入单日上限，此时尝试必然被拦
    //    （不占坑、下次重试），直接跳过省去无效 RPC。
    final newBadge = capHit
        ? null
        : await GameBadgeService.instance.unlockTopTier(
      config: config,
      gameId: game.id,
      gameCode: game.code,
      level: level,
      achievements: achievements,
      judgeValues: judgeValues,
    );
    if (newBadge != null) {
      items.add(GameSettlementItem(
        kind: 'achievement',
        label: '徽章解锁：${newBadge.name}',
        points: newBadge.rewardPoints,
        granted: true,
      ));

      // 4b) 复合荣誉（all_modes_tier）：集齐该游戏全部段位后解锁
      //    （如「消消乐之神」= 消消乐全部模式全部段位）。
      final composite = await GameBadgeService.instance.unlockAllModesTier(
        gameCode: game.code,
        achievements: achievements,
      );
      if (composite != null) {
        items.add(GameSettlementItem(
          kind: 'achievement',
          label: '成就：${composite.name}',
          points: composite.rewardPoints,
          granted: true,
        ));
      }

      // 4c) 全局复合成就（all_games_tier）：跨游戏段位判定——
      //    「全能得分王」（三游戏均达黄金段位+）与「全能游戏大师」（全部段位集齐）。
      final globalTier = await GameBadgeService.instance
          .unlockGlobalTierAchievements(achievements: achievements);
      if (globalTier != null) {
        items.add(GameSettlementItem(
          kind: 'achievement',
          label: '成就：${globalTier.name}',
          points: globalTier.rewardPoints,
          granted: true,
        ));
      }
    }

    return GameSettlementResult(items: items);
  }

  /// 结算额度判定的已领 claim_key 查询（【方案 B 阶段二】）。
  ///
  /// 仅在「名义应发总额 > 剩余额度」时发起，用于剔除已领过、实际不会再发分
  /// 的项，避免「已领项的分值」把整条链误判为装不下。
  ///
  /// 查询失败返回空集合 = 保守按「未领」计入应发总额：宁可本局早止付，
  /// 也不要在额度判定失真时继续发分（与 _tryClaim 预检失败即放行、由
  /// 服务端强校验兜底的取向互补）。
  Future<Set<String>> _fetchClaimedKeysForPlan(
    Iterable<String> claimKeys,
  ) async {
    final userId = AuthService.instance.currentUserId;
    final keys = claimKeys.toList();
    if (userId == null || keys.isEmpty) return <String>{};
    try {
      final res = await ApiClient.get(
        'game_reward_claims',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'claim_key': 'in.(${keys.join(',')})',
        },
        select: 'claim_key',
        limit: null,
        note: 'games:settlement_budget_claimed_check',
      );
      if (!res.isSuccess) return <String>{};
      return ((res.data as List<dynamic>?) ?? <dynamic>[])
          .map((r) =>
              r is Map<String, dynamic> ? r['claim_key']?.toString() : null)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('[GameRewardService] 结算额度判定已领查询失败：$e');
      return <String>{};
    }
  }
}
