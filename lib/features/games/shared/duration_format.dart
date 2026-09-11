/// 游戏耗时进阶单位格式化（2026-09-11 用户拍板，与后台 utils 同口径）：
///
/// - `< 120 秒` → 「N秒」（60秒 → 60秒）
/// - `120 秒 ~ <120 分钟` → 「M分S秒」（130秒 → 2分10秒；整分省略秒 → 2分）
/// - `120 分钟 ~ <120 小时` → 「H小时M分钟S秒」（零段省略 → 2小时 / 2小时5分钟）
/// - `≥ 120 小时` → 「D天H小时M分钟」
///
/// 仅用于成绩/最佳成绩等**查看场景**；对局中倒计时仍用 mm:ss（宽度稳定）。
String formatDurationSmart(num ms) {
  final totalSec = (ms / 1000).floor();
  if (totalSec < 120) return '$totalSec秒';
  final totalMin = totalSec ~/ 60;
  final sec = totalSec % 60;
  if (totalMin < 120) {
    return sec > 0 ? '$totalMin分$sec秒' : '$totalMin分';
  }
  final totalHour = totalMin ~/ 60;
  final min = totalMin % 60;
  if (totalHour < 120) {
    final parts = <String>['$totalHour小时'];
    if (min > 0) parts.add('$min分钟');
    if (sec > 0) parts.add('$sec秒');
    return parts.join();
  }
  final day = totalHour ~/ 24;
  final hour = totalHour % 24;
  final parts = <String>['$day天', '$hour小时'];
  if (min > 0) parts.add('$min分钟');
  return parts.join();
}
