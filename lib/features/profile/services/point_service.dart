import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../models/point_record_model.dart';

/// 积分服务
///
/// 核心设计：
/// - 积分查询从 users 表统计字段读取（effective_points / available_points / expiring_points）
/// - 积分变动（签到、获得、消费）后，App 端主动重算并更新 users 表统计字段
/// - 不依赖数据库触发器（trg_maintain_user_points 已确认不存在）
/// - 连续打卡天数从 users.consecutive_checkin_days / last_checkin_date 读取
class PointService {
  static PointService? _instance;

  PointService._();

  static PointService get instance {
    _instance ??= PointService._();
    return _instance!;
  }

  bool _timezoneInitialized = false;

  /// 初始化时区数据（仅首次）
  void _ensureTimezone() {
    if (!_timezoneInitialized) {
      tz_data.initializeTimeZones();
      _timezoneInitialized = true;
    }
  }

  /// 获取北京时间今天零点（带时区信息）
  DateTime _beijingToday() {
    _ensureTimezone();
    final beijing = tz.getLocation('Asia/Shanghai');
    final now = tz.TZDateTime.now(beijing);
    return tz.TZDateTime(beijing, now.year, now.month, now.day);
  }

  /// 获取北京时间昨天零点
  DateTime _beijingYesterday() {
    final today = _beijingToday();
    return today.subtract(const Duration(days: 1));
  }

  /// 获取北京时间明天零点
  DateTime _beijingTomorrow() {
    final today = _beijingToday();
    return today.add(const Duration(days: 1));
  }

  /// 从 users 表获取用户统计字段
  Future<Map<String, dynamic>?> _fetchUserStats() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;
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
  Future<bool> _updateUserStats({
    int? consecutiveCheckinDays,
    DateTime? lastCheckinDate,
    int? effectivePoints,
    int? availablePoints,
    int? expiringPoints,
    int? points,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

    final body = <String, dynamic>{};
    if (consecutiveCheckinDays != null) {
      body['consecutive_checkin_days'] = consecutiveCheckinDays;
    }
    if (lastCheckinDate != null) {
      body['last_checkin_date'] =
          lastCheckinDate.toIso8601String().split('T').first;
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

  /// 重算并更新 users 表的积分统计字段
  ///
  /// 基于 point_records 表全量重算（仅在积分变动后调用）：
  /// - effective_points: 所有 status='active' 的积分代数和
  /// - available_points: effective_points（当前未区分过期，后续可加过期过滤）
  /// - expiring_points: 30天内即将过期的 active 积分
  /// - points: 总获得积分（仅正数，不论状态）
  Future<void> _recalcAndUpdateUserPoints() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    try {
      // 查询该用户所有 point_records
      final result = await ApiClient.get(
        'point_records',
        filters: {'user_id': 'eq.$userId'},
        columns: 'amount,status,expires_at',
        // 不分页，全量查询（积分记录量级有限）
      );

      if (!result.isSuccess || result.data == null) return;

      final now = DateTime.now().toUtc();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      int effectivePoints = 0;
      int availablePoints = 0;
      int expiringPoints = 0;
      int totalPoints = 0;

      for (final record in result.data!) {
        final amount = (record['amount'] as num?)?.toInt() ?? 0;
        final status = record['status'] as String? ?? 'active';

        // 总获得积分（仅正数，不论状态）
        if (amount > 0) {
          totalPoints += amount;
        }

        // 仅统计 active 状态
        if (status == 'active') {
          effectivePoints += amount;
          availablePoints += amount;

          // 30天内即将过期
          final expiresAt = record['expires_at'] as String?;
          if (expiresAt != null && amount > 0) {
            final expires = DateTime.parse(expiresAt);
            if (expires.isBefore(thirtyDaysLater) && expires.isAfter(now)) {
              expiringPoints += amount;
            }
          }
        }
      }

      await _updateUserStats(
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

  /// 打卡获得积分
  ///
  /// 核心逻辑：
  /// 1. 检查今天是否已打卡
  /// 2. 计算连续签到天数
  /// 3. 计算积分 = min(连续天数, 7)
  /// 4. 插入 point_records 流水
  /// 5. 更新 users 表签到统计字段
  /// 6. 重算 users 表积分统计字段
  Future<Map<String, dynamic>> checkin() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        return {'success': false, 'message': '未登录'};
      }

      final today = _beijingToday();
      final tomorrow = _beijingTomorrow();

      // 1. 查询用户今天是否已打卡
      final todayResult = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.checkin',
          'and':
              '(created_at.gte.${today.toUtc().toIso8601String()},created_at.lt.${tomorrow.toUtc().toIso8601String()})',
        },
        columns: 'id',
      );

      if (todayResult.isSuccess) {
        final records = todayResult.data!;
        if (records.isNotEmpty) {
          return {'success': false, 'message': '今天已打卡'};
        }
      }

      // 2. 读取 users 表连续打卡信息
      final stats = await _fetchUserStats();
      int streak = 1;
      if (stats != null && stats['last_checkin_date'] != null) {
        final lastDateStr = stats['last_checkin_date'] as String;
        final lastDate = DateTime.parse(lastDateStr);
        final yesterday = _beijingYesterday();

        if (lastDate.year == yesterday.year &&
            lastDate.month == yesterday.month &&
            lastDate.day == yesterday.day) {
          // 昨天打卡了，连续天数 +1
          streak = (stats['consecutive_checkin_days'] as num?)?.toInt() ?? 0;
          streak += 1;
        } else if (lastDate.year == today.year &&
            lastDate.month == today.month &&
            lastDate.day == today.day) {
          return {'success': false, 'message': '今天已打卡'};
        }
        // 否则断签，streak 保持为 1（今天首次打卡）
      }

      // 3. 计算积分 = min(连续天数, 7)
      final points = streak > 7 ? 7 : streak;

      // 4. 插入 point_records 记录
      final now = DateTime.now();
      final nowIso = now.toUtc().toIso8601String();
      final expiresAt =
          now.add(const Duration(days: 180)).toUtc().toIso8601String();
      final insertResult = await ApiClient.post(
        'point_records',
        {
          'id': const Uuid().v4(),
          'user_id': userId,
          'type': 'checkin',
          'amount': points,
          'remark': '连续打卡$streak天',
          'created_at': nowIso,
          'expires_at': expiresAt,
          'status': 'active',
        },
      );

      if (!insertResult.isSuccess) {
        if (kDebugMode) {
          debugPrint('插入积分记录失败: ${insertResult.error}');
        }
        return {'success': false, 'message': '打卡失败: ${insertResult.error}'};
      }

      // 5. 更新 users 表打卡统计字段
      await _updateUserStats(
        consecutiveCheckinDays: streak,
        lastCheckinDate: today,
      );

      // 6. 重算 users 表积分统计字段（不依赖触发器）
      await _recalcAndUpdateUserPoints();

      // 7. 更新 AuthService 中的用户缓存
      await AuthService.instance.reloadCurrentUser();

      return {
        'success': true,
        'message': '打卡成功，获得$points积分',
        'points': points,
        'streak': streak,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('打卡失败: $e');
      }
      return {'success': false, 'message': '打卡失败，请稍后重试'};
    }
  }

  /// 分页获取积分记录
  ///
  /// [statusFilter] 状态过滤，null 表示不过滤（显示所有记录）
  Future<List<PointRecord>> getRecords({
    int page = 1,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return [];

      final offset = (page - 1) * pageSize;
      final filters = <String, String>{'user_id': 'eq.$userId'};
      if (statusFilter != null) {
        filters['status'] = 'eq.$statusFilter';
      }

      final result = await ApiClient.get(
        'point_records',
        filters: filters,
        order: 'created_at.desc',
        limit: pageSize,
        offset: offset,
      );

      if (result.isSuccess) {
        final records = result.data!;
        return records.map((json) => PointRecord.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取积分记录失败');
      }
      return [];
    }
  }

  /// 获取用户可用积分（有效且未过期的积分）
  Future<int> getAvailablePoints() async {
    final stats = await _fetchUserStats();
    return (stats?['available_points'] as num?)?.toInt() ?? 0;
  }

  /// 获取连续签到天数
  Future<int> getConsecutiveCheckinDays() async {
    final stats = await _fetchUserStats();
    return (stats?['consecutive_checkin_days'] as num?)?.toInt() ?? 0;
  }

  /// 从 AuthService 获取用户总积分（兼容旧代码）
  int getTotalPoints() {
    return AuthService.instance.currentPoints ?? 0;
  }

  /// 查询30天内即将过期的积分总数
  Future<int> getExpiringSoonPoints() async {
    final stats = await _fetchUserStats();
    return (stats?['expiring_points'] as num?)?.toInt() ?? 0;
  }

  /// 检查今天是否已打卡
  /// 双重验证：先检查 users.last_checkin_date，再查询 point_records 确认
  Future<bool> hasCheckedInToday() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

    final today = _beijingToday();

    // 方法1：检查 users 表的 last_checkin_date
    final stats = await _fetchUserStats();
    if (stats != null && stats['last_checkin_date'] != null) {
      final lastDateStr = stats['last_checkin_date'] as String;
      final lastDate = DateTime.parse(lastDateStr);
      if (lastDate.year == today.year &&
          lastDate.month == today.month &&
          lastDate.day == today.day) {
        return true;
      }
    }

    // 方法2：直接查询 point_records 表作为验证
    final todayStart = DateTime(today.year, today.month, today.day)
        .toUtc()
        .toIso8601String();
    final result = await ApiClient.get(
      'point_records',
      filters: {
        'user_id': 'eq.$userId',
        'type': 'eq.checkin',
        'created_at': 'gte.$todayStart',
      },
      limit: 1,
    );
    return result.isSuccess && (result.data ?? []).isNotEmpty;
  }

  /// 积分变动时插入 point_records 流水记录（供其他模块调用）
  ///
  /// 插入后自动重算 users 表积分统计字段。
  ///
  /// [delta] 变动值（正数增加，负数减少）
  /// [type] 变动类型：'earn' | 'consume'
  /// [remark] 备注说明
  Future<void> updatePointsStats({
    required int delta,
    required String type,
    String? remark,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    String recordType;
    String defaultRemark;
    switch (type) {
      case 'earn':
        recordType = 'earn';
        defaultRemark = '获得积分';
        break;
      case 'consume':
        recordType = 'spend';
        defaultRemark = '消费积分';
        break;
      default:
        return;
    }

    final now = DateTime.now().toUtc();
    final expiresAt = delta > 0
        ? now.add(const Duration(days: 180)).toIso8601String()
        : null;

    await ApiClient.post('point_records', {
      'id': const Uuid().v4(),
      'user_id': userId,
      'type': recordType,
      'amount': delta,
      'remark': remark ?? defaultRemark,
      'status': 'active',
      'created_at': now.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt,
    });

    // 重算 users 表积分统计字段
    await _recalcAndUpdateUserPoints();
  }

  /// 手动触发积分重算（用于数据修复或初始化场景）
  Future<void> recalcPoints() async {
    await _recalcAndUpdateUserPoints();
  }
}