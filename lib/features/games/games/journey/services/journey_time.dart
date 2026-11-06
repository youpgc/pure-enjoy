/// 西行·北京墙钟时间工具（UTC+8 固定偏移）。
///
/// 规范：记录与展示一律用北京时间（UTC+8 固定偏移），禁止设备时区——
/// 全部时间取 UTC 时刻加固定 8 小时偏移，与设备时区设置无关。
/// 返回值保持 isUtc=true 标记（字段值=北京墙钟），序列化/比较同口径。
library;

const Duration _bjOffset = Duration(hours: 8);

/// 当前北京墙钟时刻（字段值=北京墙上时间，isUtc=true）。
DateTime journeyBjNow() => DateTime.now().toUtc().add(_bjOffset);

/// 远端 UTC 绝对时刻 → 北京墙钟（展示/比较用，与 [journeyBjNow] 同口径）。
DateTime journeyBjFromUtc(DateTime utc) => utc.toUtc().add(_bjOffset);

/// 北京墙钟日期键（yyyyMMdd，每日游历 gate 用）。
String journeyBjDateKey() {
  final n = journeyBjNow();
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '${n.year}$m$d';
}
