import 'package:flutter/foundation.dart';
import '../../../services/api_client.dart';

/// 用户积分统计字段读取与更新（从 PointService 抽出，纯逻辑）
/// 与原类内实现逐字节一致。

/// 从 users 表获取用户统计字段
Future<Map<String, dynamic>?> fetchUserStats(String userId) async {
  final result = await ApiClient.get(
    'users',
    filters: {
      ApiClient.userKey(userId): 'eq.$userId',
      'is_deleted': 'eq.false',
    },
    columns:
        'consecutive_checkin_days,last_checkin_date,effective_points,available_points,expiring_points,points',
    limit: 1,
  );
  if (result.isSuccess && result.data!.isNotEmpty) {
    return result.data![0];
  }
  return null;
}

/// 更新 users 表统计字段
/// 返回 true 表示更新成功，false 表示更新失败
Future<bool> updateUserStats(
  String userId, {
  int? consecutiveCheckinDays,
  DateTime? lastCheckinDate,
  int? effectivePoints,
  int? availablePoints,
  int? expiringPoints,
  int? points,
}) async {
  final body = <String, dynamic>{};
  if (consecutiveCheckinDays != null) {
    body['consecutive_checkin_days'] = consecutiveCheckinDays;
  }
  if (lastCheckinDate != null) {
    body['last_checkin_date'] = lastCheckinDate.toIso8601String().split('T').first;
  }
  if (effectivePoints != null) body['effective_points'] = effectivePoints;
  if (availablePoints != null) body['available_points'] = availablePoints;
  if (expiringPoints != null) body['expiring_points'] = expiringPoints;
  if (points != null) body['points'] = points;

  if (body.isEmpty) return true;

  final result = await ApiClient.patchByFilter(
    'users',
    filters: {ApiClient.userKey(userId): 'eq.$userId'},
    body: body,
  );
  if (!result.isSuccess) {
    if (kDebugMode) {
      debugPrint('更新用户统计字段失败: ${result.error}');
    }
    return false;
  }
  return result.data != null && result.data!.isNotEmpty;
}
