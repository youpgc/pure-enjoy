part of 'game_reward_service.dart';

/// 统一结算编排（从 GameRewardService 拆出，逻辑零变更）：按顺序评估通关奖励 /
/// 每日首通 / 成绩区间 / 四类成就 / 段位徽章，含「上限止付」链式守卫。
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

    // 上限止付（2026-09-15 用户反馈修复）：本局一旦有奖励因「今日上限」被拦，
    // 后续项目全部止付、不再尝试发放。此前逐项独立校验会出现「大分项被拦
    // （结算页已提示达到上限）、小分项仍通过校验继续发」的割裂体验。
    // 止付与拦截都不占坑（claim 未触发），次日上限刷新后重新通关可重获。
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
    if (level.rewardPoints > 0) {
      final levelReward = await guardedClaim(
        () => claimLevelReward(gameName: game.name, level: level),
      );
      items.add(GameSettlementItem(
        kind: 'level_clear',
        label: '通关奖励',
        points: levelReward.points,
        granted: levelReward.granted,
        reason: levelReward.reason,
      ));
    }

    // 1) 每日首次通关（仅后台标记为计入的关卡）
    final daily = await guardedClaim(
      () => claimDailyFirstClear(
        gameId: game.id,
        gameName: game.name,
        level: level,
      ),
    );
    items.add(GameSettlementItem(
      kind: 'daily_first_clear',
      label: '每日首次通关',
      points: daily.points,
      granted: daily.granted,
      reason: daily.reason,
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
      final r = await guardedClaim(
        () => claimScoreRange(rule: topRule, gameCode: game.code),
      );
      items.add(GameSettlementItem(
        kind: 'score_range',
        label: topRule.name ?? '成绩达标',
        points: r.points,
        granted: r.granted,
        reason: r.reason,
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
      final r = await guardedClaim(() => claimAchievement(achievement: ach));
      items.add(GameSettlementItem(
        kind: 'achievement',
        label: '成就：${ach.name}',
        points: r.points,
        granted: r.granted,
        reason: r.reason,
      ));
    }

    // 3b) 「关卡里程碑」成就：单局至多一条（本局关序对应的最高档）。
    final topLevel = pickTopLevelAchievement(achievements, effectiveLevelNo);
    if (topLevel != null) {
      final r =
          await guardedClaim(() => claimAchievement(achievement: topLevel));
      items.add(GameSettlementItem(
        kind: 'achievement',
        label: '成就：${topLevel.name}',
        points: r.points,
        granted: r.granted,
        reason: r.reason,
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
      final r =
          await guardedClaim(() => claimAchievement(achievement: topScore));
      items.add(GameSettlementItem(
        kind: 'achievement',
        label: '成就：${topScore.name}',
        points: r.points,
        granted: r.granted,
        reason: r.reason,
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
          final r =
              await guardedClaim(() => claimAchievement(achievement: ach));
          items.add(GameSettlementItem(
            kind: 'achievement',
            label: '成就：${ach.name}',
            points: r.points,
            granted: r.granted,
            reason: r.reason,
          ));
        }
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
}
