/// 宠物模块时长文案统一规则
///
/// 120 秒内按秒展示；超过 120 秒展示「X分Y秒」复合段；超过 120 分钟
/// 展示「X小时Y分」复合段（130 秒→「2分10秒」，130 分钟→「2小时10分」）。
/// 余段为零时省略零值段（300 秒→「5分钟」，2 小时整→「2小时」）；
/// 小时段为精确分解、秒不展示。
/// 数值一律**向上取整**到秒：倒计时语义下宁可多显一档，不出现
/// 「文案已归零却仍未结束」的空窗（与冷却倒计时同一思路）。
String petDurationText(Duration d) {
  final totalSec =
      d.inMilliseconds <= 0 ? 0 : (d.inMilliseconds / 1000).ceil();
  if (totalSec <= 120) return '$totalSec秒';
  if (totalSec <= 7200) {
    final totalMin = totalSec ~/ 60;
    final sec = totalSec % 60;
    return sec == 0 ? '$totalMin分钟' : '$totalMin分$sec秒';
  }
  final totalMin = totalSec ~/ 60;
  final hour = totalMin ~/ 60;
  final min = totalMin % 60;
  return min == 0 ? '$hour小时' : '$hour小时$min分';
}
