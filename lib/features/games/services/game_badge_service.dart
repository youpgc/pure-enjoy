import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/game_achievement_model.dart';
import '../models/game_level_model.dart';
import 'game_reward_picker.dart';
import 'game_service.dart';

/// 模式段位徽章服务（v2 徽章化 q-0：成就 = 纯荣誉，0 积分，仅记录解锁）。
///
/// 从 `game_reward_service.dart` 拆出（体量红线拆分，2026-09-04）。
/// 职责：结算时按本局维度值（score/level）判定该游戏该模式的最高满足档，
/// 写 `user_game_achievements`（唯一索引幂等），不发分、不受单日上限约束。
class GameBadgeService {
  GameBadgeService._();

  /// 单例
  static final GameBadgeService instance = GameBadgeService._();

  /// 判定并记录本局达成的最高段位徽章。
  ///
  /// 返回本次**新解锁**的徽章；已解锁 / 无满足档 / 数据异常 / 写入失败
  /// 均返回 null（best-effort，静默，不影响结算主流程）。
  Future<GameAchievementModel?> unlockTopTier({
    required GameConfigSnapshot config,
    required String gameId,
    required String gameCode,
    required GameLevelModel level,
    required List<GameAchievementModel> achievements,
    required Map<String, num> judgeValues,
  }) async {
    final modeCode = _resolveModeCode(config, gameId, level);
    if (modeCode == null) return null;
    final topTier = pickTopModeTierAchievement(
      achievements,
      gameCode: gameCode,
      modeCode: modeCode,
      values: judgeValues,
    );
    if (topTier == null) return null;
    final isNew = await recordAchievementBadge(achievement: topTier);
    return isNew ? topTier : null;
  }

  /// 由关卡反解模式编码（mode_tier 徽章匹配用）。
  ///
  /// 优先按 `level.modeId` 查配置缓存；endless 合成关（无 server 关）按
  /// `isEndless` 兜底。找不到返回 null（数据异常时跳过徽章判定，不崩溃）。
  String? _resolveModeCode(
    GameConfigSnapshot config,
    String gameId,
    GameLevelModel level,
  ) {
    for (final m in config.modesOf(gameId)) {
      if (m.id == level.modeId) return m.code;
    }
    if (level.id.startsWith('endless_2048')) {
      for (final m in config.modesOf(gameId)) {
        if (m.isEndless) return m.code;
      }
    }
    return null;
  }

  /// 记录徽章解锁（0 积分成就仅写 user_game_achievements，不发分）。
  ///
  /// 幂等：先查后插（`uk_user_game_achievements` 唯一索引双兜底）。
  /// 返回 true 表示本次为新解锁；false 表示已解锁或写入失败（静默，best-effort）。
  Future<bool> recordAchievementBadge({
    required GameAchievementModel achievement,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;
    try {
      final existing = await ApiClient.get(
        'user_game_achievements',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'achievement_id': 'eq.${achievement.id}',
        },
        select: 'id',
        limit: 1,
        note: 'games:badge_check',
      );
      if (existing.isSuccess &&
          ((existing.data as List<dynamic>?)?.isNotEmpty ?? false)) {
        return false; // 已解锁，幂等返回
      }
      final inserted = await ApiClient.post(
        'user_game_achievements',
        <String, dynamic>{
          'id': const Uuid().v4(),
          'user_id': userId,
          'achievement_id': achievement.id,
          'unlocked_at': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        returnRepresentation: false,
        note: 'games:badge_unlock',
      );
      return inserted.isSuccess;
    } catch (e) {
      debugPrint('[GameBadgeService] 徽章记录失败：${achievement.code} $e');
      return false;
    }
  }
}
