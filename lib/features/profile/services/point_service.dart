import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../models/point_record_model.dart';

/// 积分服务
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

  /// 获取北京时间今天零点
  DateTime _beijingToday() {
    _ensureTimezone();
    final beijing = tz.getLocation('Asia/Shanghai');
    final now = tz.TZDateTime.now(beijing);
    return DateTime(now.year, now.month, now.day);
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

  /// 打卡获得积分
  Future<Map<String, dynamic>> checkin() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        return {'success': false, 'message': '未登录'};
      }

      final today = _beijingToday();
      final tomorrow = _beijingTomorrow();
      final yesterday = _beijingYesterday();

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

      // 2. 查询最近一次打卡记录，计算连续打卡天数
      int streak = 1;
      final lastResult = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.checkin',
        },
        columns: 'created_at',
        order: 'created_at.desc',
        limit: 1,
      );

      if (lastResult.isSuccess) {
        final lastRecords = lastResult.data!;
        if (lastRecords.isNotEmpty) {
          final lastCreatedAt = DateTime.parse(lastRecords[0]['created_at']);

          // 转换为北京时间日期进行比较
          _ensureTimezone();
          final beijing = tz.getLocation('Asia/Shanghai');
          final lastBeijing = tz.TZDateTime.from(lastCreatedAt, beijing);
          final lastDate = DateTime(lastBeijing.year, lastBeijing.month, lastBeijing.day);

          // 判断最近一次打卡是否是昨天
          if (lastDate.year == yesterday.year &&
              lastDate.month == yesterday.month &&
              lastDate.day == yesterday.day) {
            // 最近一次是昨天，今天打卡后连续天数 = 已有连续天数 + 1
            // 查询所有打卡记录，计算已有连续天数
            final streakResult = await ApiClient.get(
              'point_records',
              filters: {
                'user_id': 'eq.$userId',
                'type': 'eq.checkin',
              },
              columns: 'created_at',
              order: 'created_at.desc',
            );

            if (streakResult.isSuccess) {
              final allCheckins = streakResult.data!;
              // 从昨天的记录开始，向前统计连续天数
              int consecutiveDays = 1; // 昨天是第1天
              for (int i = 1; i < allCheckins.length; i++) {
                final prev = tz.TZDateTime.from(
                  DateTime.parse(allCheckins[i - 1]['created_at']),
                  beijing,
                );
                final curr = tz.TZDateTime.from(
                  DateTime.parse(allCheckins[i]['created_at']),
                  beijing,
                );
                final prevDate = DateTime(prev.year, prev.month, prev.day);
                final currDate = DateTime(curr.year, curr.month, curr.day);
                final diff = prevDate.difference(currDate).inDays;
                if (diff == 1) {
                  consecutiveDays++;
                } else {
                  break;
                }
              }
              // 今天打卡后，连续天数 = 已有连续天数 + 今天
              streak = consecutiveDays + 1;
            }
          } else if (lastDate.isAtSameMomentAs(today)) {
            // 今天已经打过卡（双重检查）
            return {'success': false, 'message': '今天已打卡'};
          }
          // 否则不是昨天，streak 保持为 1（今天首次打卡）
        }
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
          debugPrint('插入积分记录失败');
        }
        return {'success': false, 'message': '打卡失败，请重试'};
      }

      // 5. 更新 users 表 points += 积分
      final currentPoints = AuthService.instance.currentPoints ?? 0;
      final updateResult = await ApiClient.patchByFilter(
        'users',
        filters: {'id': 'eq.$userId'},
        body: {
          'points': currentPoints + points,
        },
      );

      if (!updateResult.isSuccess) {
        if (kDebugMode) {
          debugPrint('更新用户积分失败');
        }
      }

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
        debugPrint('打卡失败');
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

  /// 从 AuthService 获取用户总积分
  int getTotalPoints() {
    return AuthService.instance.currentPoints ?? 0;
  }

  /// 查询30天内即将过期的积分总数
  Future<int> getExpiringSoonPoints() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return 0;

      final result = await ApiClient.get(
        'v_points_expiring_soon',
        filters: {'user_id': 'eq.$userId'},
      );

      if (result.isSuccess) {
        final records = result.data!;
        int total = 0;
        for (final record in records) {
          total += (record['amount'] as num?)?.toInt() ?? 0;
        }
        return total;
      }

      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取即将过期积分失败');
      }
      return 0;
    }
  }

  /// 查询用户可用积分（排除过期）
  Future<int> getAvailablePoints() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return 0;

      final result = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'status': 'eq.active',
        },
        columns: 'amount',
      );

      if (result.isSuccess) {
        final records = result.data!;
        int total = 0;
        for (final record in records) {
          total += (record['amount'] as num?)?.toInt() ?? 0;
        }
        return total;
      }

      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取可用积分失败');
      }
      return 0;
    }
  }
}
