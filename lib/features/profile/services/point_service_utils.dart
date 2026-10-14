import '../../../utils/date_time_utils.dart';

// 北京时区口径已统一收敛到 DateTimeUtils（全 App 唯一实现），本文件仅保留历史命名的薄委托，
// 以免 20+ 处调用点改名。新增时间逻辑请直接使用 DateTimeUtils 的 beijing* 系列入口。

/// 获取北京时间今天零点（带时区信息）
DateTime beijingToday() => DateTimeUtils.beijingTodayStart();

/// 获取北京时间昨天零点
DateTime beijingYesterday() =>
    DateTimeUtils.beijingTodayStart().subtract(const Duration(days: 1));

/// 获取北京时间明天零点
DateTime beijingTomorrow() =>
    DateTimeUtils.beijingTodayStart().add(const Duration(days: 1));

/// 将任意时刻换算为北京日期键（yyyy-MM-dd），用于连续签到的按天比较。
///
/// point_records.created_at 以 UTC 存储，此处统一换算到北京墙钟日期，
/// 避免跨零点/时区导致的日期错位。
String beijingDateKey(DateTime dateTime) => DateTimeUtils.beijingDateKey(dateTime);

