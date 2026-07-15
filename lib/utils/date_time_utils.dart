import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// 日期时间工具类
/// 统一处理 App 内所有时间格式化和排序
///
/// 所有时间展示均固定使用北京时间（UTC+8），不依赖设备时区设置。
/// 这样无论真机（北京时区）还是模拟器（UTC 时区）都展示一致的北京时间。
///
/// Supabase 表结构中的日期字段类型：
/// - TIMESTAMPTZ: created_at, updated_at, remind_at — 存储完整时间戳（UTC）
/// - DATE: date (expenses, weight_records) — 仅存储日期 YYYY-MM-DD
class DateTimeUtils {
  /// 北京时区偏移（UTC+8）
  static const Duration _beijingOffset = Duration(hours: 8);

  /// 北京时区定位（用于 tz 转换，避免依赖设备时区）
  static final tz.Location _beijingLoc = tz.getLocation('Asia/Shanghai');

  /// 标准日期时间格式：YYYY-MM-DD HH:mm:ss
  static final DateFormat _standardFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// 日期格式：YYYY-MM-DD
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// 时间格式：HH:mm:ss
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  /// 将 DateTime 转换为北京时间展示
  ///
  /// 统一按设备时区偏移换算到北京时间墙钟，保证真机（北京时区）与
  /// 模拟器（UTC 时区）展示一致，彻底解决模拟器 -8 小时的问题：
  /// - UTC 时间：用 tz 直接转换到 Asia/Shanghai 墙钟
  /// - 本地时间（如 DATE 字段 / 无时区后缀的时间戳）：按设备偏移换算到北京墙钟
  ///   （设备偏移=+8 时等价不变，设备偏移=0 时加 8 小时）
  static DateTime _toBeijingTime(DateTime dt) {
    if (dt.isUtc) {
      return tz.TZDateTime.from(dt, _beijingLoc);
    }
    // 本地时间：按设备时区偏移换算到北京墙钟
    final deviceOffset = DateTime.now().timeZoneOffset;
    final shifted = dt.add(_beijingOffset - deviceOffset);
    return DateTime(
      shifted.year, shifted.month, shifted.day,
      shifted.hour, shifted.minute, shifted.second,
    );
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

  /// 获取当前北京时间（Asia/Shanghai）
  /// 用于过期判断、连续天数等业务逻辑，避免使用设备本地时间导致时区偏差
  static DateTime nowBeijing() {
    return tz.TZDateTime.now(_beijingLoc);
  }
}
