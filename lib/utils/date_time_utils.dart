import 'package:intl/intl.dart';

/// 日期时间工具类
/// 统一处理 App 内所有时间格式化和排序
///
/// 所有时间展示均固定使用北京时间（UTC+8），不依赖设备时区设置。
///
/// Supabase 表结构中的日期字段类型：
/// - TIMESTAMPTZ: created_at, updated_at, remind_at — 存储完整时间戳（UTC）
/// - DATE: date (expenses, weight_records) — 仅存储日期 YYYY-MM-DD
class DateTimeUtils {
  /// 北京时区偏移（UTC+8）
  static const Duration _beijingOffset = Duration(hours: 8);

  /// 标准日期时间格式：YYYY-MM-DD HH:mm:ss
  static final DateFormat _standardFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// 日期格式：YYYY-MM-DD
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// 时间格式：HH:mm:ss
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  /// 将 UTC DateTime 转换为北京时间
  static DateTime _toBeijingTime(DateTime dt) {
    // 如果已经是带时区信息的 DateTime，直接加 8 小时偏移
    return dt.add(_beijingOffset);
  }

  /// 格式化为标准格式：YYYY-MM-DD HH:mm:ss
  /// 用于显示 created_at, updated_at, remind_at 等完整时间戳字段
  static String formatStandard(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _standardFormat.format(_toBeijingTime(dateTime));
  }

  /// 格式化为日期：YYYY-MM-DD
  /// 用于显示 date 字段（仅日期）
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    // DATE 字段为本地时间凌晨，无需偏移
    return _dateFormat.format(dateTime);
  }

  /// 格式化为时间：HH:mm:ss
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _timeFormat.format(_toBeijingTime(dateTime));
  }

  /// 解析 ISO 8601 字符串为 DateTime
  /// 适用于 created_at, updated_at 等 TIMESTAMPTZ 字段
  static DateTime? parseIso8601(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      return DateTime.parse(isoString);
    } catch (e) {
      return null;
    }
  }

  /// 解析 DATE 字符串 (YYYY-MM-DD) 为本地时间凌晨
  /// 适用于 expenses, weight_records 的 date 字段
  /// 避免 DateTime.parse('YYYY-MM-DD') 默认按 UTC 解析导致时区偏移
  static DateTime? parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse('${dateString.split('T').first}T00:00:00.000');
    } catch (e) {
      return null;
    }
  }

  /// 格式化为 DATE 字符串 (YYYY-MM-DD)
  /// 用于提交到 Supabase 的 date 字段
  static String toDateString(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateFormat.format(dateTime);
  }

  /// 格式化为 TIMESTAMPTZ 字符串 (ISO 8601)
  /// 用于提交到 Supabase 的 created_at, updated_at 字段
  static String toTimestampString(DateTime? dateTime) {
    if (dateTime == null) return '';
    return dateTime.toUtc().toIso8601String();
  }

  /// 按时间倒序排序列表
  /// 适用于有 createdAt 字段的模型
  static List<T> sortByTimeDesc<T>(List<T> list, DateTime? Function(T) getTime) {
    return List<T>.from(list)
      ..sort((a, b) {
        final timeA = getTime(a);
        final timeB = getTime(b);
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });
  }

  /// 获取当前时间的 ISO 8601 字符串（UTC）
  /// 用于 created_at, updated_at 字段
  static String nowIso8601() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// 获取当前日期字符串（YYYY-MM-DD）
  /// 用于 date 字段
  static String nowDateString() {
    return _dateFormat.format(DateTime.now());
  }

  /// 获取当前时间的标准格式字符串（北京时间）
  static String nowStandard() {
    return formatStandard(DateTime.now().toUtc());
  }
}
