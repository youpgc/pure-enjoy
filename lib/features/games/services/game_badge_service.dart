import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../services/api_client.dart';
import '../../../services/error_reporter.dart';
import '../../../services/supabase_service.dart';
import '../models/game_achievement_model.dart';
import '../models/game_level_model.dart';
import 'game_reward_picker.dart';
import 'game_reward_service.dart';
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
    if (topTier.rewardPoints > 0) {
      final r = await GameRewardService.instance.claimAchievementPoints(topTier);
      if (r.granted) return topTier;
      if (r.reason != '该奖励已领取') return null; // 如达单日上限：不记解锁，下次重试
      // already=true：积分此前已发，补记解锁记录
    }
    final isNew = await recordAchievementBadge(achievement: topTier);
    return isNew ? topTier : null;
  }

  /// 复合荣誉成就（all_modes_tier）：某游戏全部模式全部段位集齐后解锁。
  ///
  /// condition 形如 `{"type":"all_modes_tier","game":"match3"}`——该类型 v2
  /// 种子遗留、引擎原本不支持（当时落 level 兜底），现于结算链路补真实判定：
  /// 本局新增段位解锁后，核对该游戏全部 mode_tier 段位是否均已解锁，集齐则
  /// 记录并按 rewardPoints 发分（claim_key 幂等）。
  ///
  /// 仅在「本次有新段位解锁」时触发（否则不可能新集齐）；静默 best-effort。
  Future<GameAchievementModel?> unlockAllModesTier({
    required String gameCode,
    required List<GameAchievementModel> achievements,
  }) async {
    final composites = achievements
        .where((a) =>
            a.condition['type']?.toString() == 'all_modes_tier' &&
            a.condition['game']?.toString() == gameCode)
        .toList();
    if (composites.isEmpty) return null;

    // 该游戏全部段位成就 id
    final tierIds = achievements
        .where((a) =>
            a.condition['type']?.toString() == 'mode_tier' &&
            a.condition['game']?.toString() == gameCode)
        .map((a) => a.id)
        .toList();
    if (tierIds.isEmpty) return null;

    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;

    try {
      final res = await ApiClient.get(
        'user_game_achievements',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'achievement_id': 'in.(${tierIds.join(',')})',
        },
        select: 'achievement_id',
        note: 'games:all_tier_check',
      );
      if (!res.isSuccess) return null;
      final unlockedIds = ((res.data as List<dynamic>?) ?? <dynamic>[])
          .map((r) =>
              r is Map<String, dynamic> ? r['achievement_id']?.toString() : null)
          .whereType<String>()
          .toSet();
      final allUnlocked = tierIds.every(unlockedIds.contains);
      if (!allUnlocked) return null;

      // 集齐：记录并按积分口径发放（与段位徽章同 claim 幂等口径）；
      // 任一因单日上限未发分则跳过记录，下次结算重试
      GameAchievementModel? newly;
      for (final composite in composites) {
        var claimable = true;
        if (composite.rewardPoints > 0) {
          final r =
              await GameRewardService.instance.claimAchievementPoints(composite);
          claimable = r.granted || r.reason == '该奖励已领取';
        }
        if (!claimable) continue;
        final isNew = await recordAchievementBadge(achievement: composite);
        if (isNew) newly ??= composite;
      }
      return newly;
    } catch (e) {
      debugPrint('[GameBadgeService] 复合荣誉判定失败：$e');
      return null;
    }
  }

  /// 全局复合成就（all_games_tier）：跨游戏段位达成判定。
  ///
  /// condition 形如 `{"type":"all_games_tier"}`（无 min_tier = 三款游戏全部
  /// 模式段位集齐 →「全能游戏大师」）或 `{"type":"all_games_tier","min_tier":3}`
  /// （三款游戏各自已有 tier ≥ 3 的段位解锁 →「全能得分王」，2026-09-11 语义
  /// 修正：原 daily_streak 为 App 未实现的死条件）。
  ///
  /// 仅在「本次有新段位解锁」时触发（与 [unlockAllModesTier] 同点），静默
  /// best-effort；解锁走 claim 幂等 + 解锁记录，与段位徽章同口径。
  Future<GameAchievementModel?> unlockGlobalTierAchievements({
    required List<GameAchievementModel> achievements,
  }) async {
    final globals = achievements
        .where((a) => a.condition['type']?.toString() == 'all_games_tier')
        .toList();
    if (globals.isEmpty) return null;

    // 全部段位成就（按游戏分组）；三款游戏缺一则无法判定
    final tiersByGame = <String, List<GameAchievementModel>>{};
    for (final a in achievements) {
      if (a.condition['type']?.toString() != 'mode_tier') continue;
      final game = a.condition['game']?.toString();
      if (game == null || game.isEmpty || game == 'null') continue;
      tiersByGame.putIfAbsent(game, () => <GameAchievementModel>[]).add(a);
    }
    if (tiersByGame.length < 3) return null;

    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;

    try {
      final allTierIds =
          tiersByGame.values.expand((list) => list.map((a) => a.id)).toList();
      final res = await ApiClient.get(
        'user_game_achievements',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'achievement_id': 'in.(${allTierIds.join(',')})',
        },
        select: 'achievement_id',
        note: 'games:global_tier_check',
      );
      if (!res.isSuccess) return null;
      final unlockedIdSet = ((res.data as List<dynamic>?) ?? <dynamic>[])
          .map((r) =>
              r is Map<String, dynamic> ? r['achievement_id']?.toString() : null)
          .whereType<String>()
          .toSet();

      // 逐条评估全局成就条件
      final satisfied = <GameAchievementModel>[];
      for (final g in globals) {
        final minTier = g.condition['min_tier'];
        if (minTier is num) {
          // 各游戏均已有 tier >= minTier 的段位解锁
          final ok = tiersByGame.values.every((tiers) => tiers.any((t) {
                final tier = t.condition['tier'];
                return tier is num &&
                    tier >= minTier &&
                    unlockedIdSet.contains(t.id);
              }));
          if (ok) satisfied.add(g);
        } else {
          // 三款游戏全部模式段位集齐
          final ok = tiersByGame.values
              .every((tiers) => tiers.every((t) => unlockedIdSet.contains(t.id)));
          if (ok) satisfied.add(g);
        }
      }
      if (satisfied.isEmpty) return null;

      GameAchievementModel? newly;
      for (final g in satisfied) {
        var claimable = true;
        if (g.rewardPoints > 0) {
          final r = await GameRewardService.instance.claimAchievementPoints(g);
          claimable = r.granted || r.reason == '该奖励已领取';
        }
        if (!claimable) continue;
        final isNew = await recordAchievementBadge(achievement: g);
        if (isNew) newly ??= g;
      }
      return newly;
    } catch (e) {
      debugPrint('[GameBadgeService] 全局复合成就判定失败：$e');
      return null;
    }
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
    } catch (e, st) {
      debugPrint('[GameBadgeService] 徽章记录失败：${achievement.code} $e');
      // 错误上报（2026-09-11）：段位徽章解锁记录失败影响复合荣誉判定
      ErrorReporter.report(
        e,
        st,
        module: 'games',
      );
      return false;
    }
  }
}
