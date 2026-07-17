import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';
import '../../../services/api_client.dart';

bool _timezoneInitialized = false;

/// 初始化时区数据（仅首次）
void _ensureTimezone() {
  if (!_timezoneInitialized) {
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }
}

/// 获取北京时间今天零点（带时区信息）
DateTime beijingToday() {
  _ensureTimezone();
  final beijing = tz.getLocation('Asia/Shanghai');
  final now = tz.TZDateTime.now(beijing);
  return tz.TZDateTime(beijing, now.year, now.month, now.day);
}

/// 获取北京时间昨天零点
DateTime beijingYesterday() {
  final today = beijingToday();
  return today.subtract(const Duration(days: 1));
}

/// 获取北京时间明天零点
DateTime beijingTomorrow() {
  final today = beijingToday();
  return today.add(const Duration(days: 1));
}

/// 将任意时刻换算为北京日期键（yyyy-MM-dd），用于连续签到的按天比较。
///
/// point_records.created_at 以 UTC 存储，此处统一换算到北京墙钟日期，
/// 避免跨零点/时区导致的日期错位。
String beijingDateKey(DateTime dateTime) {
  _ensureTimezone();
  final beijing = tz.getLocation('Asia/Shanghai');
  final t = tz.TZDateTime.from(dateTime, beijing);
  final month = t.month.toString().padLeft(2, '0');
  final day = t.day.toString().padLeft(2, '0');
  return '${t.year}-$month-$day';
}

/// 基于 point_records 签到流水推算「今天签到后」的连续签到天数。
///
/// 设计要点：
/// - 签到流水是权威且必然落库的数据源（每日签到能成功插入、去重判断亦依赖它），
///   因此不再依赖 users.consecutive_checkin_days / last_checkin_date
///   （这两个统计字段的写入曾因 users 表缺表触发器而失败，导致连续天数无法累积）。
/// - 查询最近 10 天的 checkin 流水，按北京日期去重；从「昨天」开始逐日向前回溯，
///   连续命中则累加，今天本次签到计为 1。
/// - 该算法可自愈历史坏数据：首次签到即按真实流水算出正确连续天数。
Future<int> calcConsecutiveStreak(String userId, DateTime today) async {
  try {
    final since = today.subtract(const Duration(days: 10));
    final result = await ApiClient.get(
      'point_records',
      filters: {
        'user_id': 'eq.$userId',
        'type': 'eq.checkin',
        'created_at': 'gte.${since.toUtc().toIso8601String()}',
      },
      columns: 'created_at',
      order: 'created_at.desc',
      limit: 50,
    );

    if (!result.isSuccess || result.data == null) return 1;

    // 收集已签到的北京日期（yyyy-MM-dd）
    final checkedDates = <String>{};
    for (final record in result.data!) {
      final createdStr = record['created_at'] as String?;
      if (createdStr == null) continue;
      checkedDates.add(beijingDateKey(DateTime.parse(createdStr)));
    }

    // 从昨天开始逐日回溯统计连续天数，今天本次签到计为 1
    int streak = 1;
    var cursor = beijingYesterday();
    while (checkedDates.contains(beijingDateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('计算连续签到天数失败: $e');
    }
    return 1;
  }
}
