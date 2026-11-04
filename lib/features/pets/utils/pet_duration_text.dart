/// 宠物模块时长文案统一规则
///
/// 90 秒内按秒展示，90 秒 ~ 90 分钟按分钟展示，超过 90 分钟按小时展示；
/// 单位单一、不拼复合段（如「2分30秒」「1小时35分钟」均不再使用）。
/// 数值一律**向上取整**：倒计时语义下宁可多显一档，不出现
/// 「文案已归零却仍未结束」的空窗（与冷却倒计时同一思路）。
String petDurationText(Duration d) {
  final totalSec =
      d.inMilliseconds <= 0 ? 0 : (d.inMilliseconds / 1000).ceil();
  if (totalSec <= 90) return '$totalSec秒';
  final totalMin = (totalSec / 60).ceil();
  if (totalMin <= 90) return '$totalMin分钟';
  return '${(totalMin / 60).ceil()}小时';
}
