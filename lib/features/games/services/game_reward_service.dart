import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/event_bus.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../profile/services/point_service.dart';
import '../../profile/services/point_service_utils.dart';
import '../models/game_achievement_model.dart';
import '../models/game_level_model.dart';
import '../models/game_model.dart';
import '../models/game_reward_rule_model.dart';
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
/// **发放顺序（先占坑，再发分）**：
///   1. 校验单日上限（rule_type='daily_limit'，初始 10 分）
///   2. 插入 `game_reward_claims`（靠 (user_id, claim_key) 唯一索引保证同一奖励只领一次）
///   3. 占坑成功才调 `PointService.updatePointsStats(type:'game_earn')` 发分
///   4. 发分失败则删除占坑记录，允许下次重试（宁可少发，不可重复发）
///   5. 发分成功后 fire(EventType.pointsUpdated) 刷新积分展示
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
    final scoreRules = config.rewardRules.where(
      (r) =>
          r.gameId == game.id &&
          r.ruleType == GameRewardRuleType.scoreRange &&
          r.enabled,
    );
    for (final rule in scoreRules) {
      if (_meetsScoreRange(rule, scoreValuesByCode)) {
        final r = await claimScoreRange(rule: rule, gameCode: game.code);
        items.add(GameSettlementItem(
          kind: 'score_range',
          label: rule.name ?? '成绩达标',
          points: r.points,
          granted: r.granted,
          reason: r.reason,
        ));
      }
    }

    // 3) 成就达成（按该游戏启用的成就条件）
    final achievements = config
        .achievementsOf(game.id)
        .where((a) => a.enabled);
    for (final ach in achievements) {
      if (_meetsAchievement(ach, level, scoreValuesByCode)) {
        final r = await claimAchievement(achievement: ach);
        items.add(GameSettlementItem(
          kind: 'achievement',
          label: '成就：${ach.name}',
          points: r.points,
          granted: r.granted,
          reason: r.reason,
        ));
      }
    }

    return GameSettlementResult(items: items);
  }

  /// 判断成绩区间规则是否达成。
  /// condition 形如 {'dimension': 'score', 'gte': 1000, 'lte': 9999}。
  bool _meetsScoreRange(
    GameRewardRuleModel rule,
    Map<String, num> values,
  ) {
    final cond = rule.condition;
    final dim = cond['dimension']?.toString();
    if (dim == null) return false;
    final v = values[dim];
    if (v == null) return false;
    final gte = cond['gte'];
    final lte = cond['lte'];
    if (gte != null && v < (gte as num)) return false;
    if (lte != null && v > (lte as num)) return false;
    return true;
  }

  /// 判断成就条件是否达成。
  /// condition 支持：
  ///   {'type': 'first_clear'}                  任意通关
  ///   {'type': 'score', 'dimension': 'score', 'gte': 2048}
  ///   {'type': 'level', 'min_level_no': 2}     通关关卡号 >= 2
  bool _meetsAchievement(
    GameAchievementModel ach,
    GameLevelModel level,
    Map<String, num> values,
  ) {
    final cond = ach.condition;
    final type = cond['type']?.toString() ?? 'first_clear';
    switch (type) {
      case 'first_clear':
        return true;
      case 'score':
        final dim = cond['dimension']?.toString();
        final gte = cond['gte'];
        if (dim == null || gte == null) return false;
        final v = values[dim];
        return v != null && v >= (gte as num);
      case 'level':
        final minLevel = cond['min_level_no'];
        if (minLevel == null) return false;
        return level.levelNo >= (minLevel as num);
      default:
        return false;
    }
  }

  /// 查询今日（北京自然日）已领取的游戏奖励积分。
  Future<int> fetchTodayClaimedPoints() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return 0;

    final result = await ApiClient.get(
      'game_reward_claims',
      filters: <String, String>{
        'user_id': 'eq.$userId',
        'claimed_at': 'gte.${beijingToday().toUtc().toIso8601String()}',
      },
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

  /// 通用领取流程：上限校验 → 占坑 → 发分 → 失败回滚占坑 → 刷新积分。
  Future<GameRewardResult> _tryClaim({
    required String claimKey,
    required int points,
    required String remark,
    String? gameId,
    String? ruleId,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return GameRewardResult.notGranted(reason: '未登录');
    if (points <= 0) return GameRewardResult.notGranted(reason: '积分为 0');

    // 1) 单日上限校验
    final limit = (await GameService.instance.fetchConfig()).dailyLimit;
    final claimed = await fetchTodayClaimedPoints();
    if (claimed + points > limit) {
      return GameRewardResult.notGranted(
        reason: '今日游戏奖励已达上限（$limit 分）',
      );
    }

    // 2) 占坑：唯一索引 (user_id, claim_key) 保证同一奖励只领一次
    final claimId = const Uuid().v4();
    final claimResult = await ApiClient.post(
      'game_reward_claims',
      <String, dynamic>{
        'id': claimId,
        'user_id': userId,
        'game_id': gameId,
        'rule_id': ruleId,
        'claim_key': claimKey,
        'points': points,
        'claimed_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      returnRepresentation: false,
      note: 'games:claim',
    );

    if (!claimResult.isSuccess) {
      // 唯一冲突即已领；其余失败也按已领处理，避免重复发分
      debugPrint('[GameRewardService] 占坑失败（视为已领取）：$claimKey');
      return GameRewardResult.notGranted(reason: '该奖励已领取');
    }

    // 3) 发分：走积分统一入口（type=game_earn，正积分 +180 天）
    try {
      await PointService.instance.updatePointsStats(
        delta: points,
        type: 'game_earn',
        remark: remark,
      );
      // 4) 发分成功，刷新积分展示
      EventBus.instance.fire(EventType.pointsUpdated);
      return GameRewardResult.granted(points: points);
    } catch (e) {
      // 5) 回滚占坑，允许下次重试
      debugPrint('[GameRewardService] 发分失败，回滚占坑：$e');
      await ApiClient.delete(
        'game_reward_claims',
        id: claimId,
        note: 'games:rollback_claim',
      );
      return GameRewardResult.notGranted(reason: '发放失败，请重试');
    }
  }
}
