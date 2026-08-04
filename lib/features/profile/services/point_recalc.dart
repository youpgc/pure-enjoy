import 'package:flutter/foundation.dart';
import '../../../services/api_client.dart';
import './point_user_stats.dart';

/// 积分重算逻辑（从 PointService._recalcAndUpdateUserPoints 抽出，纯逻辑）
/// 与原类内实现逐字节一致。
Future<void> recalcAndUpdateUserPoints(String userId) async {
  try {
    // 查询该用户所有 point_records
    // 注意：必须显式传 limit: null，否则 ApiClient.get 默认 limit=10，
    // 仅聚合前 10 条记录，导致 available_points / points 被少算（BUG 根因）。
    final result = await ApiClient.get(
      'point_records',
      filters: {'user_id': 'eq.$userId'},
      columns: 'amount,status,expires_at',
      limit: null, // 全量查询（积分记录量级有限），不可省略
    );

    if (!result.isSuccess || result.data == null) return;

    final now = DateTime.now().toUtc();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    int effectivePoints = 0;
    int availablePoints = 0;
    int expiringPoints = 0;
    int totalPoints = 0;
    bool hasExpired = false;

    for (final record in result.data!) {
      final amount = (record['amount'] as num?)?.toInt() ?? 0;
      final status = record['status'] as String? ?? 'active';
      final expiresAtStr = record['expires_at'] as String?;
      final expiresAt =
          expiresAtStr != null ? DateTime.parse(expiresAtStr) : null;
      final isExpired = expiresAt != null && expiresAt.isBefore(now);

      // 总获得积分（仅正数，不论状态、不论是否过期）
      if (amount > 0) {
        totalPoints += amount;
      }

      // 仅统计【有效且未过期】的 active 记录
      if (status == 'active' && !isExpired) {
        effectivePoints += amount;
        availablePoints += amount;

        // 30天内即将过期
        if (expiresAt != null && amount > 0) {
          if (expiresAt.isBefore(thirtyDaysLater)) {
            expiringPoints += amount;
          }
        }
      } else if (status == 'active' && isExpired) {
        // 已过期但仍标记为 active，需在库中翻转为 expired
        hasExpired = true;
      }
    }

    // 将已过期但仍为 active 的记录持久化翻转为 expired，
    // 使「可用积分」扣减与 UI「已过期」标签一致（一次性批量更新）
    if (hasExpired) {
      await ApiClient.patchByFilter(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'status': 'eq.active',
          'expires_at': 'lt.${now.toIso8601String()}',
        },
        body: {'status': 'expired'},
      );
    }

    await updateUserStats(
      userId,
      effectivePoints: effectivePoints,
      availablePoints: availablePoints,
      expiringPoints: expiringPoints,
      points: totalPoints,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('重算用户积分失败: $e');
    }
  }
}
