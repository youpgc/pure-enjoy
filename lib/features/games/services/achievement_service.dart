import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/game_achievement_model.dart';
import 'game_service.dart';

/// 用户已获得成就的展示视图。
///
/// 同一类目（如羊了个羊·通关第5/20关）只保留最高级别（sort_order 最大），
/// 用于「成就」页按类目展示最高成就，避免低级别淹没列表。
class UserAchievementView {
  /// 成就定义（含名称 / 图标 / 奖励积分 / 类目）
  final GameAchievementModel achievement;

  /// 该类目最高级别的获取时间（北京时区展示）
  final DateTime unlockedAt;

  const UserAchievementView({
    required this.achievement,
    required this.unlockedAt,
  });
}

/// 成就查询服务
///
/// 职责：拉取当前用户已解锁成就（user_game_achievements），关联 game_achievements
/// 定义，按类目合并为每类「最高级别」，供「我的 → 成就」页展示。
///
/// 用户过滤一律用 [AuthService.instance.currentUserId]（业务 ID，形如 U…），
/// 与 user_game_achievements.user_id 口径一致，并受 RLS(get_user_business_id()) 约束。
class AchievementService {
  AchievementService._();

  /// 单例
  static final AchievementService instance = AchievementService._();

  /// 拉取当前用户已获得成就（按类目合并为最高级别）。未登录返回空列表。
  Future<List<UserAchievementView>> fetchUserAchievements() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return const <UserAchievementView>[];

    final result = await ApiClient.get(
      'user_game_achievements',
      filters: <String, String>{'user_id': 'eq.$userId'},
      select: 'id,user_id,achievement_id,unlocked_at',
      limit: null,
      note: 'games:user_achievements',
    );
    if (!result.isSuccess) {
      debugPrint('[AchievementService] 拉取失败：${result.errorMessage}');
      return const <UserAchievementView>[];
    }

    final rows = (result.data as List<dynamic>?) ?? <dynamic>[];

    // 成就定义映射（id -> GameAchievementModel），复用游戏配置缓存（仅启用项）。
    // 已解锁成就必然来自结算时启用的成就，禁用项不会写入 user_game_achievements。
    final achMap = <String, GameAchievementModel>{};
    for (final a in (await GameService.instance.fetchConfig()).achievements) {
      achMap[a.id] = a;
    }

    // 收集每个 achievement_id 的最早解锁时间（取最小 unlocked_at 作为「获取时间」）
    final unlockedByAch = <String, DateTime>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final aid = row['achievement_id'] as String? ?? '';
      final ts = row['unlocked_at'] != null
          ? DateTime.tryParse(row['unlocked_at'].toString())
          : null;
      if (aid.isEmpty || ts == null) continue;
      final prev = unlockedByAch[aid];
      if (prev == null || ts.isBefore(prev)) unlockedByAch[aid] = ts;
    }

    // 按类目分组，取每类 sort_order 最大的成就（即最高级别）
    final byGroup = <String, UserAchievementView>{};
    for (final entry in unlockedByAch.entries) {
      final ach = achMap[entry.key];
      if (ach == null) continue;
      final group = _groupKey(ach.code);
      final existing = byGroup[group];
      if (existing == null ||
          ach.sortOrder > existing.achievement.sortOrder) {
        byGroup[group] = UserAchievementView(
          achievement: ach,
          unlockedAt: entry.value,
        );
      }
    }

    final list = byGroup.values.toList()
      ..sort((a, b) =>
          a.achievement.sortOrder.compareTo(b.achievement.sortOrder));
    return list;
  }

  /// 类目分组键：去掉 code 尾部数字段（level_sheep_5 -> level_sheep）。
  /// 无尾部数字（如 first_clear_sheep）原样返回。
  String _groupKey(String code) {
    final m = RegExp(r'_\d+$').firstMatch(code);
    if (m != null) return code.substring(0, m.start);
    return code;
  }
}

/// 将 UTC 时间格式化为北京时区展示串（YYYY-MM-DD HH:mm）。
String formatBeijing(DateTime utc) {
  return DateFormat('yyyy-MM-dd HH:mm')
      .format(utc.add(const Duration(hours: 8)));
}
