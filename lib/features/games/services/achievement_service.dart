import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/game_achievement_model.dart';
import 'game_service.dart';

/// 单条已获取成就实例（某类目下的某一个已解锁等级）。
class UserAchievementView {
  /// 成就定义（含名称 / 图标 / 奖励积分 / 类目）
  final GameAchievementModel achievement;

  /// 该等级的获取时间（北京时区展示）
  final DateTime unlockedAt;

  const UserAchievementView({
    required this.achievement,
    required this.unlockedAt,
  });
}

/// 同类（重复类型）已获取成就的分组视图。
///
/// 同一类目（如羊了个羊·通关第 5/20 关，code 去尾部数字归为一组）归为一组，
/// [obtained] 为该类目下用户【已获取】的各等级成就，按 sort_order 升序（低 → 高）；
/// [highest] 为最高级别，网格仅展示此项，满足「重复类型仅显示最高等级」。
class AchievementGroupView {
  /// 类目分组键（code 去尾部数字）
  final String groupKey;

  /// 该类目下已获取的全部等级（升序）
  final List<UserAchievementView> obtained;

  const AchievementGroupView({
    required this.groupKey,
    required this.obtained,
  });

  /// 最高级别（列表末尾）。
  UserAchievementView get highest => obtained.last;
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

  /// 拉取当前用户已获得成就（按类目分组，每组保留已获取的全部等级）。
  /// 未登录返回空列表。
  Future<List<AchievementGroupView>> fetchUserAchievements() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return const <AchievementGroupView>[];

    final result = await ApiClient.get(
      'user_game_achievements',
      filters: <String, String>{'user_id': 'eq.$userId'},
      select: 'id,user_id,achievement_id,unlocked_at',
      limit: null,
      note: 'games:user_achievements',
    );
    if (!result.isSuccess) {
      debugPrint('[AchievementService] 拉取失败：${result.errorMessage}');
      return const <AchievementGroupView>[];
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

    // 按类目分组，收集该类目下【已获取】的全部等级（升序排列）。
    final byGroup = <String, List<UserAchievementView>>{};
    for (final entry in unlockedByAch.entries) {
      final ach = achMap[entry.key];
      if (ach == null) continue;
      final group = _groupKey(ach.code);
      byGroup
          .putIfAbsent(group, () => <UserAchievementView>[])
          .add(UserAchievementView(achievement: ach, unlockedAt: entry.value));
    }

    final groups = byGroup.entries.map((e) {
      e.value.sort((a, b) =>
          a.achievement.sortOrder.compareTo(b.achievement.sortOrder));
      return AchievementGroupView(groupKey: e.key, obtained: e.value);
    }).toList();

    // 组间按最高级别的 sort_order 升序，保持展示稳定。
    groups.sort((a, b) => a.highest.achievement.sortOrder
        .compareTo(b.highest.achievement.sortOrder));
    return groups;
  }

  /// 类目分组键：去掉 code 尾部数字段（level_sheep_5 -> level_sheep）。
  /// 无尾部数字（如 first_clear_sheep）原样返回。
  String _groupKey(String code) {
    final m = RegExp(r'_\d+$').firstMatch(code);
    if (m != null) return code.substring(0, m.start);
    return code;
  }
}

/// 将 UTC 时间格式化为北京时区展示串（YYYY-MM-DD HH:mm:ss）。
String formatBeijing(DateTime utc) {
  return DateFormat('yyyy-MM-dd HH:mm:ss')
      .format(utc.add(const Duration(hours: 8)));
}
