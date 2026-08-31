import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../profile/services/point_service.dart';
import '../../profile/services/point_service_utils.dart';
import '../models/game_achievement_model.dart';
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

/// 游戏积分奖励服务
///
/// 职责：在防刷 A 方案下发放游戏奖励（每日首次通关 / 成就达成 / 成绩区间首次达成）。
///
/// **发放顺序（先占坑，再发分）**：
///   1. 校验单日上限（rule_type='daily_limit'，初始 10 分）
///   2. 插入 `game_reward_claims`（靠 (user_id, claim_key) 唯一索引保证同一奖励只领一次）
///   3. 占坑成功才调 `PointService.updatePointsStats(type:'game_earn')` 发分
///   4. 发分失败则删除占坑记录，允许下次重试（宁可少发，不可重复发）
///
/// 说明：成绩由客户端判定，本方案只能提高作弊门槛、不能杜绝；
/// 量化风险靠「单日上限 + 单日仅一次首通」双重约束压低损失上限。
class GameRewardService {
  GameRewardService._();

  /// 单例
  static final GameRewardService instance = GameRewardService._();

  /// 领取「每日首次通关」奖励。
  ///
  /// 跨游戏共享：同一自然日（北京时区）内只有第一次通关会发放。
  Future<GameRewardResult> claimDailyFirstClear({
    required String gameId,
    required String gameName,
  }) async {
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
  /// 同一成就终身只发一次（同时受 user_game_achievements 唯一索引兜底）。
  Future<GameRewardResult> claimAchievement({
    required GameAchievementModel achievement,
  }) async {
    if (achievement.rewardPoints <= 0) {
      return GameRewardResult.notGranted(reason: '该成就无积分奖励');
    }
    return _tryClaim(
      claimKey: 'achievement:${achievement.code}',
      points: achievement.rewardPoints,
      remark: '成就达成（${achievement.name}）',
      gameId: achievement.gameId,
    );
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

  /// 通用领取流程：上限校验 → 占坑 → 发分 → 失败回滚占坑。
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
      return GameRewardResult.granted(points: points);
    } catch (e) {
      // 4) 回滚占坑，允许下次重试
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
