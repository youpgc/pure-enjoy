import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/event_bus.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../profile/services/point_service_utils.dart';
import '../models/game_achievement_model.dart';
import '../models/game_level_model.dart';
import '../models/game_model.dart';
import '../models/match3_mode.dart';
import '../models/game_reward_rule_model.dart';
import 'game_reward_picker.dart';
import 'game_service.dart';

/// 奖励发放结果
class GameRewardResult {
  /// 是否实际发放
  final bool granted;

  /// 发放积分（未发放为 0）
  final int points;

  /// 未发放原因（发放成功为 null）
  final String? reason;

  const GameRewardResult._({
    required this.granted,
    this.points = 0,
    this.reason,
  });

  /// 发放成功。
  factory GameRewardResult.granted({required int points}) =>
      GameRewardResult._(granted: true, points: points);

  /// 未发放（含原因，便于 UI 提示）。
  factory GameRewardResult.notGranted({String? reason}) =>
      GameRewardResult._(granted: false, reason: reason);
}

/// 单条奖励明细（供结算页展示）
class GameSettlementItem {
  /// 奖励种类：daily_first_clear / score_range / achievement
  final String kind;

  /// 展示名
  final String label;

  /// 发放积分（未发放为 0）
  final int points;

  /// 是否实际发放
  final bool granted;

  /// 未发放原因（发放成功为 null）
  final String? reason;

  const GameSettlementItem({
    required this.kind,
    required this.label,
    required this.points,
    required this.granted,
    this.reason,
  });
}

/// 一次结算的全部奖励明细
class GameSettlementResult {
  /// 明细列表
  final List<GameSettlementItem> items;

  const GameSettlementResult({required this.items});

  /// 实际发放总积分
  int get totalPoints =>
      items.where((e) => e.granted).fold(0, (sum, e) => sum + e.points);

  /// 是否有任意一项发放成功
  bool get hasGranted => items.any((e) => e.granted);
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

  /// 领取成就达成奖励。
  ///
  /// 同一成就终身只发一次（claim_key 唯一索引 + user_game_achievements 唯一索引双兜底）。
  /// 成就奖励**不占用单日游戏奖励上限**（独立激励体系，byPassDailyLimit）。
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
      bypassDailyLimit: true,
    );
    if (res.granted) {
      // 记录用户成就（看板展示 + 终身唯一兜底）。best-effort，失败仅记日志。
      final userId = AuthService.instance.currentUserId;
      if (userId != null) {
        await ApiClient.post(
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
    return _tryClaim(
      claimKey: claimKey,
      points: level.rewardPoints,
      remark: '通关奖励（$gameName·${level.name}）',
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

    // 判定专用取值：match3 的 level_no 是「模式序号×100 + 模式内关序(1~50)」编码，
    // 若后台把 'level' 配成 score_range 规则或成就的比对维度，必须先折算为
    // 全局关序(1~300) 再比对，否则 101（第 1 关）会被当成第 101 关而误发高档奖励。
    // 仅用于判定；成绩上报（game_scores）由调用方使用原始 level_no，不受影响。
    final judgeValues =
        game.code == 'match3' && scoreValuesByCode.containsKey('level')
            ? <String, num>{
                ...scoreValuesByCode,
                'level': match3LevelIndex(scoreValuesByCode['level']!.toInt()),
              }
            : scoreValuesByCode;

    // 0) 每关通关奖励（rewardPoints<=0 时跳过，结算页不展示无效行）
    if (level.rewardPoints > 0) {
      final levelReward = await claimLevelReward(
        gameName: game.name,
        level: level,
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
    final daily = await claimDailyFirstClear(
      gameId: game.id,
      gameName: game.name,
      level: level,
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
      final r = await claimScoreRange(rule: topRule, gameCode: game.code);
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

    // 消消乐的 level_no 采用「模式序号×100 + 模式内关序(1~50)」编码
    // （如 201=消除模式第 1 关，即全局第 51 关）。直接用原始 level_no 比对
    // min_level_no 会把「第 1 关」误判为已满足「通关第 100/150/200 关」。
    // 需折算为跨模式的全局关序(1~300)（match3LevelIndex）再比对，
    // 成就阈值 10..300 正是按全局关序配置的（300=第 6 模式第 50 关）。
    final effectiveLevelNo =
        game.code == 'match3' ? match3LevelIndex(level.levelNo) : level.levelNo;

    // 3a) 「首次通关」类成就：账号终身唯一、全局与单游戏可叠加，
    //     已领取由 claim_key 唯一索引幂等拦截（不二次计算发放）。
    for (final ach in achievements) {
      if (achievementTypeOf(ach) != kAchievementTypeFirstClear) continue;
      final r = await claimAchievement(achievement: ach);
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
      final r = await claimAchievement(achievement: topLevel);
      items.add(GameSettlementItem(
        kind: 'achievement',
        label: '成就：${topLevel.name}',
        points: r.points,
        granted: r.granted,
        reason: r.reason,
      ));
    }

    // 3c) 「单局得分里程碑」成就：单局至多一条（本局分数对应的最高档）。
    final topScore = pickTopScoreAchievement(achievements, judgeValues);
    if (topScore != null) {
      final r = await claimAchievement(achievement: topScore);
      items.add(GameSettlementItem(
        kind: 'achievement',
        label: '成就：${topScore.name}',
        points: r.points,
        granted: r.granted,
        reason: r.reason,
      ));
    }

    return GameSettlementResult(items: items);
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
      limit: null,
      note: 'games:today_claimed',
    );
    if (!result.isSuccess) {
      debugPrint(
          '[GameRewardService] 今日已领积分查询失败：${result.errorMessage}');
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
      final claimed = await fetchTodayClaimedPoints();
      if (claimed + points > limit) {
        return GameRewardResult.notGranted(
          reason: '今日游戏奖励已达上限（$limit 分）',
        );
      }

      // 1b) 单游戏单日上限（如 sheep/g2048/match3 各 100 分）。
      //     与全局上限取「先到先拦」——两者独立约束，任一超限即止。
      if (gameId != null) {
        final gameLimit = config.dailyLimitPerGame(gameId);
        final gameClaimed = await fetchTodayClaimedPoints(gameId: gameId);
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
      return GameRewardResult.notGranted(reason: '发放失败，请重试');
    }

    // PostgREST 对 returns jsonb 标量直接返回对象；个别版本会包成单元素数组，兼容两种。
    Map<String, dynamic>? dataMap;
    if (rpc.data is Map<String, dynamic>) {
      dataMap = rpc.data as Map<String, dynamic>;
    } else if (rpc.data is List<dynamic> &&
        (rpc.data as List<dynamic>).isNotEmpty &&
        (rpc.data as List<dynamic>).first is Map<String, dynamic>) {
      dataMap = (rpc.data as List<dynamic>).first as Map<String, dynamic>;
    }

    if (dataMap != null && dataMap['already'] == true) {
      // 该奖励此前已发放（唯一索引命中 / 并发第二请求），按已领取处理，不重复计入
      return GameRewardResult.notGranted(reason: '该奖励已领取');
    }

    // 3) 发分成功，刷新积分展示
    EventBus.instance.fire(EventType.pointsUpdated);
    return GameRewardResult.granted(points: points);
  }
}
