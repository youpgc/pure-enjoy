import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/event_bus.dart';
import '../../../services/api_client.dart';
import '../../../services/error_reporter.dart';
import '../../../services/supabase_service.dart';
import '../../profile/services/point_service_utils.dart';
import '../models/game_achievement_model.dart';
import '../models/game_level_model.dart';
import '../models/game_model.dart';
import '../models/game_reward_rule_model.dart';
import 'game_badge_service.dart';
import 'game_cumulative_service.dart';
import 'game_mode_resolver.dart';
import 'game_reward_picker.dart';
import 'game_service.dart';

// 结算模型类（GameRewardResult / GameSettlementItem / GameSettlementResult）
// 已拆至 game_settlement_models.dart；import 供本文件使用，export 保持调用方
// 原有 import 路径（from game_reward_service.dart）不变。
import 'game_settlement_models.dart';
export 'game_settlement_models.dart';

/// 按后台配置动态推导 match3 关卡的「全局关序」（配置驱动，不硬编码 50/100）。
///
/// 全局关序 = 排在本模式之前的所有模式实际关数之和 + 本模式内关序(levelNo)，
/// 与后台 `game_levels` 实际数据一致，供成就「累计通关至第 N 关」与 score_range
/// 规则的 'level' 维度比对（须与 `min_level_no` / 规则阈值同一口径）。
int _match3GlobalLevelIndex(GameConfigSnapshot config, GameLevelModel level) {
  final modes = config.modesOf(level.gameId);
  int offset = 0;
  for (final m in modes) {
    if (m.id == level.modeId) {
      return offset + (level.levelNo > 0 ? level.levelNo : 0);
    }
    offset += config.levels.where((l) => l.modeId == m.id).length;
  }
  // 找不到对应模式（数据异常）：回退原始 levelNo，保证不崩溃
  return level.levelNo;
}
/// 游戏积分奖励服务
///
/// 职责：在防刷 A 方案下发放游戏奖励（每日首次通关 / 成就达成 / 成绩区间首次达成）。
///
/// **统一入口 [settleGame]**：游戏结束（通关）时调用一次，内部按顺序评估三类奖励，
/// 返回 [GameSettlementResult] 供结算页展示。
///
/// **发放顺序（原子占坑 + 发分）**：
///   1. 校验单日上限（rule_type='daily_limit'，初始 10 分）
///   2. 调 `grant_game_reward` RPC（security definer 事务）：同一奖励靠
///      (user_id, claim_key) 唯一索引原子占坑，并原子插入 point_records + 回写 users；
///      要么全成要么全回滚，granted=true 幂等返回（绝不重复发分）。
///      彻底替代旧「insert + updatePointsStats + delete 回滚」三步——旧流程的 delete
///      回滚被 RLS 拦截，会导致占坑烧掉、奖励永久无法再领。
///   3. 发分成功后 fire(EventType.pointsUpdated) 刷新积分展示
///
/// 说明：成绩由客户端判定，本方案只能提高作弊门槛、不能杜绝；
/// 量化风险靠「单日上限 + 单日仅一次首通 + 关卡计入标记」三重约束压低损失上限。
class GameRewardService {
  GameRewardService._();

  /// 单例
  static final GameRewardService instance = GameRewardService._();

  /// 领取「每日首次通关」奖励。
  ///
  /// 仅当 [level.countForDailyClear] 为 true（后台指定计入的关卡）才发放；
  /// 跨游戏共享：同一自然日（北京时区）内只有第一次计入关卡的通关会发放。
  Future<GameRewardResult> claimDailyFirstClear({
    required String gameId,
    required String gameName,
    required GameLevelModel level,
  }) async {
    if (!level.countForDailyClear) {
      return GameRewardResult.notGranted(reason: '本关不计入每日首通');
    }
    final rules = (await GameService.instance.fetchConfig()).globalRewardRules;
    final rule = rules.firstWhere(
      (r) => r.ruleType == GameRewardRuleType.dailyFirstClear && r.enabled,
      orElse: () => const GameRewardRuleModel(
        id: '',
        ruleType: GameRewardRuleType.dailyFirstClear,
        points: 3,
      ),
    );
    if (!rule.enabled) {
      return GameRewardResult.notGranted(reason: '该奖励已关闭');
    }

    final dateKey = beijingDateKey(DateTime.now());
    return _tryClaim(
      claimKey: 'daily_first_clear:$dateKey',
      points: rule.points,
      remark: '游戏每日首通（$gameName）',
      gameId: gameId,
      ruleId: rule.id.isEmpty ? null : rule.id,
    );
  }

  /// 批量查询已领取的成就 claim_key（claim_key 体系落 game_reward_claims 表）。
  ///
  /// 用于累计型成就发放前过滤已领档位，避免每次结算对全部达标档做无效
  /// claim RPC；查询失败返回空集合（失败时退化为逐档幂等 claim，不阻塞发放）。
  Future<Set<String>> _fetchClaimedAchievementKeys(
    List<GameAchievementModel> achievements,
  ) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null || achievements.isEmpty) return <String>{};
    try {
      final res = await ApiClient.get(
        'game_reward_claims',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'claim_key':
              'in.(${achievements.map((a) => 'achievement:${a.code}').join(',')})',
        },
        select: 'claim_key',
        note: 'games:cumulative_claimed_check',
      );
      if (!res.isSuccess) return <String>{};
      return ((res.data as List<dynamic>?) ?? <dynamic>[])
          .map((r) => r is Map<String, dynamic> ? r['claim_key']?.toString() : null)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('[GameRewardService] 已领档位批量查询失败：$e');
      return <String>{};
    }
  }

  /// 领取成就达成奖励。
  ///
  /// 同一成就终身只发一次（claim_key 唯一索引 + user_game_achievements 唯一索引双兜底）。
  /// 成就奖励**计入单日游戏奖励上限**（与通关/每日首通/成绩区间奖励共用全局与单游戏上限，
  /// 由 [_tryClaim] 统一校验），避免成就叠加刷分突破单日上限。
  Future<GameRewardResult> claimAchievement({
    required GameAchievementModel achievement,
  }) async {
    if (achievement.rewardPoints <= 0) {
      return GameRewardResult.notGranted(reason: '该成就无积分奖励');
    }
    final res = await _tryClaim(
      claimKey: 'achievement:${achievement.code}',
      points: achievement.rewardPoints,
      remark: '成就达成（${achievement.name}）',
      gameId: achievement.gameId,
    );
    if (res.granted) {
      // 记录用户成就（看板展示 + 终身唯一兜底）。失败上报后台（发分已成功，
      // 记录失败会导致「积分已发但看板永不显示」的闭环缺口，2026-09-11）。
      final userId = AuthService.instance.currentUserId;
      if (userId != null) {
        final rec = await ApiClient.post(
          'user_game_achievements',
          <String, dynamic>{
            'id': const Uuid().v4(),
            'user_id': userId,
            'achievement_id': achievement.id,
            'unlocked_at': DateTime.now().toUtc().toIso8601String(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          returnRepresentation: false,
          note: 'games:user_achievement',
        );
        if (!rec.isSuccess) {
          ErrorReporter.reportMessage(
            '用户成就记录写入失败（积分已发）：${rec.errorMessage}（achievement=${achievement.code}, user=$userId）',
            module: 'games',
          );
        }
      }
    }
    return res;
  }

  /// 领取「成绩区间首次达成」奖励。
  ///
  /// [rule] 为后台配置的 score_range 规则；同一游戏同一档位只发一次。
  Future<GameRewardResult> claimScoreRange({
    required GameRewardRuleModel rule,
    required String gameCode,
  }) async {
    if (!rule.enabled || rule.points <= 0) {
      return GameRewardResult.notGranted(reason: '该奖励已关闭');
    }
    return _tryClaim(
      claimKey: 'score_range:$gameCode:${rule.id}',
      points: rule.points,
      remark: rule.name ?? '成绩达标奖励',
      gameId: rule.gameId,
      ruleId: rule.id,
    );
  }

  /// 领取「每关通关奖励」。
  ///
  /// [level.rewardPoints] <= 0 视为无奖励；
  /// [level.rewardRepeatable]=true 时每次通关均可领（claim_key 带随机后缀，受单日上限约束）；
  /// =false 时终身只领一次（固定 claim_key）。
  Future<GameRewardResult> claimLevelReward({
    required GameLevelModel level,
    required String gameName,
  }) async {
    if (level.rewardPoints <= 0) {
      return GameRewardResult.notGranted(reason: '本关无通关奖励');
    }
    final claimKey = level.rewardRepeatable
        ? 'level_clear:${level.id}:${const Uuid().v4()}'
        : 'level_clear_once:${level.id}';
    // 关卡名种子格式自带「游戏·模式」前缀（如「2048·经典模式 L001」），
    // 直接引用即自含归因，不再拼 gameName（否则「2048·2048·…」重复展示）。
    final levelLabel = level.name.isNotEmpty
        ? level.name
        : '$gameName·第${level.levelNo}关';
    return _tryClaim(
      claimKey: claimKey,
      points: level.rewardPoints,
      remark: '通关奖励（$levelLabel）',
      gameId: level.gameId,
    );
  }

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


  /// 段位徽章积分发放（v2 徽章化升级：mode_tier 成就带积分）。
  ///
  /// claim_key 沿用 `achievement:{code}`，幂等；计入单日上限（先到先拦）。
  Future<GameRewardResult> claimAchievementPoints(
    GameAchievementModel achievement,
  ) {
    return _tryClaim(
      claimKey: 'achievement:${achievement.code}',
      points: achievement.rewardPoints,
      remark: '成就达成（${achievement.name}）',
      gameId: achievement.gameId,
    );
  }

  /// 查询今日（北京自然日）已领取的游戏奖励积分。
  ///
  /// [gameId] 非空时仅统计该游戏的领取记录（用于单游戏单日上限校验）；
  /// 为 null（默认）时统计全部游戏（用于全局单日上限校验）。
  Future<int> fetchTodayClaimedPoints({String? gameId}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return 0;

    final filters = <String, String>{
      'user_id': 'eq.$userId',
      'claimed_at': 'gte.${beijingToday().toUtc().toIso8601String()}',
    };
    if (gameId != null) {
      filters['game_id'] = 'eq.$gameId';
    }
    final result = await ApiClient.get(
      'game_reward_claims',
      filters: filters,
      // 按需 select：仅求和消费 points（排除 claim_key/remark 等长文本列）
      select: 'points',
      limit: null,
      note: 'games:today_claimed',
    );
    if (!result.isSuccess) {
      debugPrint(
          '[GameRewardService] 今日已领积分查询失败：${result.errorMessage}');
      ErrorReporter.reportMessage(
        '今日已领积分查询失败：${result.errorMessage}（user=$userId, game=$gameId）',
        module: 'games',
        level: 'warning',
      );
      return 0;
    }

    final rows = (result.data as List<dynamic>?) ?? <dynamic>[];
    var total = 0;
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        total += (row['points'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  /// 今日已领积分链内缓存（M5）：一次结算链会触发多次 [fetchTodayClaimedPoints]
  /// （全局 + 单游戏，每次领奖各一遍），逐次 HTTP 查询既慢又浪费。
  /// 按「北京日期键」缓存，[_tryClaim] 发分成功后增量回写——游戏奖励唯一写入方
  /// 就是本服务，缓存不会失真；跨天自动失效。
  String? _claimedCacheDay;
  int? _cachedGlobalClaimed;
  final Map<String, int> _cachedGameClaimed = <String, int>{};

  /// 账号切换时清空「今日已领」链内缓存（2026-09-14 审查修复）：
  /// 缓存值按用户统计，切号不清会导致新账号读到旧账号的已领积分，
  /// 进而误判「已领取」/提前触发每日上限。
  void resetForAccountSwitch() {
    _claimedCacheDay = null;
    _cachedGlobalClaimed = null;
    _cachedGameClaimed.clear();
  }

  /// 取「今日已领」缓存值（无缓存时回源查询一次）。
  Future<int> _claimedPointsCached({String? gameId}) async {
    final day = beijingDateKey(DateTime.now());
    if (_claimedCacheDay != day) {
      _claimedCacheDay = day;
      _cachedGlobalClaimed = null;
      _cachedGameClaimed.clear();
    }
    if (gameId == null) {
      _cachedGlobalClaimed ??= await fetchTodayClaimedPoints();
      return _cachedGlobalClaimed!;
    }
    if (!_cachedGameClaimed.containsKey(gameId)) {
      _cachedGameClaimed[gameId] = await fetchTodayClaimedPoints(gameId: gameId);
    }
    return _cachedGameClaimed[gameId]!;
  }

  /// 发分成功后把本次积分累加进缓存，保持后续校验实时性。
  void _bumpClaimedCache(int points, String? gameId) {
    _cachedGlobalClaimed = (_cachedGlobalClaimed ?? 0) + points;
    if (gameId != null) {
      _cachedGameClaimed[gameId] = (_cachedGameClaimed[gameId] ?? 0) + points;
    }
  }

  /// 通用领取流程：上限校验 → 调 grant_game_reward RPC（原子占坑 + 发分，幂等）→ 刷新积分。
  ///
  /// [bypassDailyLimit] 为 true 时跳过单日上限校验（成就奖励独立于单日上限）。
  Future<GameRewardResult> _tryClaim({
    required String claimKey,
    required int points,
    required String remark,
    String? gameId,
    String? ruleId,
    bool bypassDailyLimit = false,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return GameRewardResult.notGranted(reason: '未登录');
    if (points <= 0) return GameRewardResult.notGranted(reason: '积分为 0');

    // 1) 单日上限校验（超限时直接返回、不占坑——坑未烧掉，明日刷新后
    //    重新通关同一奖励仍可领取，实现「超限次日可重获」）
    if (!bypassDailyLimit) {
      final config = await GameService.instance.fetchConfig();

      // 1a) 全局单日上限（跨游戏合计，默认 200 分）
      final limit = config.dailyLimit;
      final claimed = await _claimedPointsCached();
      if (claimed + points > limit) {
        return GameRewardResult.notGranted(
          reason: '今日游戏奖励已达上限（$limit 分）',
        );
      }

      // 1b) 单游戏单日上限（如 sheep/g2048/match3 各 50 分，见参考文档 §7/§13 D8）。
      //     与全局上限取「先到先拦」——两者独立约束，任一超限即止。
      if (gameId != null) {
        final gameLimit = config.dailyLimitPerGame(gameId);
        final gameClaimed = await _claimedPointsCached(gameId: gameId);
        if (gameClaimed + points > gameLimit) {
          return GameRewardResult.notGranted(
            reason: '本游戏今日奖励已达上限（$gameLimit 分）',
          );
        }
      }
    }

    // 2) 原子占坑 + 发分：统一走 grant_game_reward RPC（security definer 事务）。
    //    要么占坑 + 发分 + 置 granted=true 全成，要么全回滚；granted 已存在则幂等
    //    返回 already=true，不再发分、也无需 delete 回滚（彻底解决旧流程「回滚被 RLS
    //    拦截 → 占坑烧掉、奖励永久无法再领」的漏洞）。
    final rpc = await ApiClient.rpc(
      'grant_game_reward',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_claim_key': claimKey,
        'p_points': points,
        'p_game_id': gameId,
        'p_rule_id': ruleId,
        'p_type': 'game_earn',
        'p_remark': remark,
      },
      note: 'games:grant_reward',
    );

    if (!rpc.isSuccess) {
      debugPrint('[GameRewardService] 发奖 RPC 失败：$claimKey ${rpc.error}');
      // 错误上报（2026-09-11）：发分失败直接影响用户权益，须后台可见
      ErrorReporter.reportMessage(
        '游戏奖励发放失败：${rpc.error}（claim=$claimKey, points=$points, user=$userId, game=$gameId）',
        module: 'games',
      );
      return GameRewardResult.notGranted(reason: '发放失败，请重试');
    }

    // PostgREST 对 returns jsonb 标量直接返回对象；个别版本会包成单元素数组，兼容两种。
    // 修复前 handleApiResponse 对非数组响应抛 cast 异常，导致 RPC 实际成功却被判失败；
    // 现单对象走 rpc.raw，数组首项走 rpc.data。
    Map<String, dynamic>? dataMap;
    final raw = rpc.raw;
    if (raw is Map<String, dynamic>) {
      dataMap = raw;
    } else {
      final data = rpc.data;
      if (data != null && data.isNotEmpty) {
        dataMap = data.first;
      }
    }

    if (dataMap != null && dataMap['already'] == true) {
      // 该奖励此前已发放（唯一索引命中 / 并发第二请求），按已领取处理，不重复计入
      return GameRewardResult.notGranted(reason: '该奖励已领取');
    }

    // 3) 发分成功，刷新积分展示；已领缓存增量回写，保持同链后续校验实时
    _bumpClaimedCache(points, gameId);
    EventBus.instance.fire(EventType.pointsUpdated);
    return GameRewardResult.granted(points: points);
  }
}
