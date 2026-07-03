import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../models/point_record_model.dart';

/// 积分服务
///
/// 核心变更：
/// - 连续打卡天数改为读取 users.consecutive_checkin_days / last_checkin_date
/// - 有效/可用/即将过期积分改为读取 users 表统计字段，不再全量查询 point_records
/// - 积分变动时同步更新 users 表统计字段
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
      filters: {'id': 'eq.$userId'},
      columns: 'consecutive_checkin_days,last_checkin_date,effective_points,available_points,expiring_points,points',
      limit: 1,
    );
    if (result.isSuccess && result.data!.isNotEmpty) {
      return result.data![0];
    }
    return null;
  }

  /// 更新 users 表统计字段
  Future<void> _updateUserStats({
    int? consecutiveCheckinDays,
    DateTime? lastCheckinDate,
    int? effectivePoints,
    int? availablePoints,
    int? expiringPoints,
    int? points,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

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

    if (body.isNotEmpty) {
      await ApiClient.patchByFilter(
        'users',
        filters: {'id': 'eq.$userId'},
        body: body,
      );
    }
  }

  /// 打卡获得积分
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
          'and': '(created_at.gte.${today.toUtc().toIso8601String()},created_at.lt.${tomorrow.toUtc().toIso8601String()})',
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
      final expiresAt = now.add(const Duration(days: 180)).toUtc().toIso8601String();
      final insertResult = await ApiClient.post(
        'point_records',
        {
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

      // 5. 更新 users 表统计字段
      final currentPoints = (stats?['points'] as num?)?.toInt() ?? 0;
      final currentEffective = (stats?['effective_points'] as num?)?.toInt() ?? 0;
      final currentAvailable = (stats?['available_points'] as num?)?.toInt() ?? 0;
      final newPoints = currentPoints + points;
      final newEffective = currentEffective + points;
      final newAvailable = currentAvailable + points;

      await _updateUserStats(
        consecutiveCheckinDays: streak,
        lastCheckinDate: today,
        effectivePoints: newEffective,
        availablePoints: newAvailable,
        points: newPoints,
      );

      // 6. 更新 AuthService 中的用户缓存
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
      return {'success': false, 'message': '打卡失败: $e'};
    }
  }

  /// 分页获取积分记录
  Future<List<PointRecord>> getRecords({int page = 1, int pageSize = 20}) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return [];

      final offset = (page - 1) * pageSize;
      final result = await ApiClient.get(
        'point_records',
        filters: {'user_id': 'eq.$userId'},
        order: 'created_at.desc',
        limit: pageSize,
        offset: offset,
      );

      if (result.isSuccess) {
        final records = result.data!;
        return records
            .map((json) => PointRecord.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取积分记录失败');
      }
      return [];
    }
  }

  /// 获取用户有效积分总和（直接从 users 表读取）
  Future<int> fetchTotalPoints() async {
    final stats = await _fetchUserStats();
    return (stats?['effective_points'] as num?)?.toInt() ?? 0;
  }

  /// 从 AuthService 获取用户总积分（兼容旧代码）
  int getTotalPoints() {
    return AuthService.instance.currentPoints ?? 0;
  }

  /// 查询30天内即将过期的积分总数（直接从 users 表读取）
  Future<int> getExpiringSoonPoints() async {
    final stats = await _fetchUserStats();
    return (stats?['expiring_points'] as num?)?.toInt() ?? 0;
  }

  /// 查询用户可用积分（直接从 users 表读取）
  Future<int> getAvailablePoints() async {
    final stats = await _fetchUserStats();
    return (stats?['available_points'] as num?)?.toInt() ?? 0;
  }

  /// 积分变动时更新 users 表统计字段（供其他模块调用）
  /// 
  /// [delta] 变动值（正数增加，负数减少）
  /// [type] 变动类型：'earn' | 'consume' | 'expire'
  Future<void> updatePointsStats({required int delta, required String type}) async {
    final stats = await _fetchUserStats();
    if (stats == null) return;

    final currentEffective = (stats['effective_points'] as num?)?.toInt() ?? 0;
    final currentAvailable = (stats['available_points'] as num?)?.toInt() ?? 0;
    final currentPoints = (stats['points'] as num?)?.toInt() ?? 0;

    int newEffective = currentEffective;
    int newAvailable = currentAvailable;
    int newPoints = currentPoints;

    switch (type) {
      case 'earn':
        newEffective += delta;
        newAvailable += delta;
        newPoints += delta;
        break;
      case 'consume':
        newAvailable -= delta;
        newPoints -= delta;
        break;
      case 'expire':
        newEffective -= delta;
        newAvailable -= delta;
        newPoints -= delta;
        break;
    }

    // 确保不为负数
    newEffective = newEffective < 0 ? 0 : newEffective;
    newAvailable = newAvailable < 0 ? 0 : newAvailable;
    newPoints = newPoints < 0 ? 0 : newPoints;

    await _updateUserStats(
      effectivePoints: newEffective,
      availablePoints: newAvailable,
      points: newPoints,
    );
  }
}
