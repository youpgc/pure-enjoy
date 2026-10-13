import 'package:flutter/foundation.dart';
import '../../../services/backend_api.dart';

/// 用户积分统计字段读取与更新（从 PointService 抽出，纯逻辑）
///
/// change-server：统计权威在后端（users 四列由后端在积分事务内统一维护），
/// App 侧只读 —— 读取走 `/users/points/summary` 概览端点；
/// 写入口 updateUserStats 保留签名以兼容旧调用点，改为 no-op（直接返回 true），
/// 由后端签到/补签/消费事务负责回写。
/// 概览字段向后端 VO 对齐后映射为旧 users 统计字段键名，调用点零改动。

/// 从后端概览端点获取用户积分统计（键名与旧 users 统计字段保持一致）
Future<Map<String, dynamic>?> fetchUserStats(String userId) async {
  try {
    final result = await BackendApi.get('/users/points/summary');
    if (!result.success || result.data is! Map<String, dynamic>) {
      return null;
    }
    final d = result.data as Map<String, dynamic>;
    return {
      'available_points': (d['available'] as num?)?.toInt() ?? 0,
      'expiring_points': (d['expiring'] as num?)?.toInt() ?? 0,
      'consecutive_checkin_days': (d['consecutive_days'] as num?)?.toInt() ?? 0,
      'checked_in_today': d['checked_in_today'] == true,
      'last_checkin_date': d['last_checkin_date'],
    };
  } catch (e) {
    if (kDebugMode) {
      debugPrint('获取积分概览失败: $e');
    }
    return null;
  }
}

/// 更新 users 表统计字段 —— change-server 后统计由后端事务内维护，App 不再回写。
/// 保留签名兼容旧调用点，直接返回 true。
Future<bool> updateUserStats(
  String userId, {
  int? consecutiveCheckinDays,
  DateTime? lastCheckinDate,
  int? effectivePoints,
  int? availablePoints,
  int? expiringPoints,
  int? points,
}) async {
  return true;
}
