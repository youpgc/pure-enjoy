import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../../services/supabase_service.dart';
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
      final todayCheckUrl = Uri.parse(
        '${SupabaseConfig.url}/rest/v1/point_records'
        '?user_id=eq.$userId&type=eq.checkin'
        '&created_at=gte.${today.toUtc().toIso8601String()}'
        '&created_at=lt.${tomorrow.toUtc().toIso8601String()}'
        '&select=id',
      );

      final todayResponse = await http.get(
        todayCheckUrl,
        headers: AuthService.instance.authHeaders,
      );

      if (todayResponse.statusCode == 200) {
        final records = jsonDecode(todayResponse.body) as List;
        if (records.isNotEmpty) {
          return {'success': false, 'message': '今天已打卡'};
        }
      }

      // 2. 查询最近一次打卡记录，计算连续打卡天数
      int streak = 1;
      final lastCheckUrl = Uri.parse(
        '${SupabaseConfig.url}/rest/v1/point_records'
        '?user_id=eq.$userId&type=eq.checkin'
        '&select=created_at'
        '&order=created_at.desc'
        '&limit=1',
      );

      final lastResponse = await http.get(
        lastCheckUrl,
        headers: AuthService.instance.authHeaders,
      );

      if (lastResponse.statusCode == 200) {
        final lastRecords = jsonDecode(lastResponse.body) as List;
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
            // 查询连续打卡天数
            final streakUrl = Uri.parse(
              '${SupabaseConfig.url}/rest/v1/point_records'
              '?user_id=eq.$userId&type=eq.checkin'
              '&select=created_at'
              '&order=created_at.desc',
            );

            final streakResponse = await http.get(
              streakUrl,
              headers: AuthService.instance.authHeaders,
            );

            if (streakResponse.statusCode == 200) {
              final allCheckins =
                  jsonDecode(streakResponse.body) as List;
              streak = 1;
              for (int i = 1; i < allCheckins.length; i++) {
                final prev = tz.TZDateTime.from(
                  DateTime.parse(allCheckins[i - 1]['created_at']),
                  beijing,
                );
                final curr = tz.TZDateTime.from(
                  DateTime.parse(allCheckins[i]['created_at']),
                  beijing,
                );
                final prevDate =
                    DateTime(prev.year, prev.month, prev.day);
                final currDate =
                    DateTime(curr.year, curr.month, curr.day);
                final diff = prevDate.difference(currDate).inDays;
                if (diff == 1) {
                  streak++;
                } else {
                  break;
                }
              }
            }
          } else if (lastDate.isAtSameMomentAs(today)) {
            // 今天已经打过卡（双重检查）
            return {'success': false, 'message': '今天已打卡'};
          }
          // 否则不是昨天，streak 保持为 1
        }
      }

      // 3. 计算积分 = min(连续天数, 7)
      final points = streak > 7 ? 7 : streak;

      // 4. 插入 point_records 记录
      final now = DateTime.now().toUtc().toIso8601String();
      final insertResponse = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/point_records'),
        headers: AuthService.instance.authHeaders,
        body: jsonEncode({
          'user_id': userId,
          'type': 'checkin',
          'amount': points,
          'remark': '连续打卡$streak天',
          'created_at': now,
        }),
      );

      if (insertResponse.statusCode != 201 &&
          insertResponse.statusCode != 200) {
        debugPrint('插入积分记录失败: ${insertResponse.statusCode} ${insertResponse.body}');
        return {'success': false, 'message': '打卡失败，请重试'};
      }

      // 5. 更新 users 表 points += 积分
      final currentPoints = AuthService.instance.currentPoints ?? 0;
      final updateResponse = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/users?id=eq.$userId'),
        headers: AuthService.instance.authHeaders,
        body: jsonEncode({
          'points': currentPoints + points,
        }),
      );

      if (updateResponse.statusCode != 200 &&
          updateResponse.statusCode != 204) {
        debugPrint('更新用户积分失败: ${updateResponse.statusCode} ${updateResponse.body}');
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
      debugPrint('打卡失败: $e');
      return {'success': false, 'message': '打卡失败: $e'};
    }
  }

  /// 分页获取积分记录
  Future<List<PointRecord>> getRecords({int page = 1, int pageSize = 20}) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return [];

      final offset = (page - 1) * pageSize;
      final url = Uri.parse(
        '${SupabaseConfig.url}/rest/v1/point_records'
        '?user_id=eq.$userId'
        '&select=*'
        '&order=created_at.desc'
        '&limit=$pageSize'
        '&offset=$offset',
      );

      final response = await http.get(
        url,
        headers: AuthService.instance.authHeaders,
      );

      if (response.statusCode == 200) {
        final records = jsonDecode(response.body) as List;
        return records
            .map((json) => PointRecord.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('获取积分记录失败: $e');
      return [];
    }
  }

  /// 从 AuthService 获取用户总积分
  int getTotalPoints() {
    return AuthService.instance.currentPoints ?? 0;
  }
}
