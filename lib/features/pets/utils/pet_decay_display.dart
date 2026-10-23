/// 饱食/心情的**展示层**实时衰减插值
///
/// 服务端结算仍是惰性模型（summary 打开/交互时按 last_decay_at 差额补算，
/// 见 rpc_pet_summary 衰减 UPDATE 与 _pet_add_progress 健康恢复窗）——
/// 本工具只解决「App 停留期间数值不 tick」的观感问题：以数据拉取时刻为锚，
/// 按后台下发的每小时衰减速率线性外推，服务端下一次结算为准（显示近似）。
///
/// 寄养（fostered）冻结不衰减，调用方按状态自行跳过插值。
library;

/// 按流逝时间衰减后的展示值（下限 0）
int petDecayedStat(int base, DateTime fetchedAt, int perHour, DateTime now) {
  if (perHour <= 0 || base <= 0) return base;
  final elapsed = now.difference(fetchedAt);
  if (elapsed.isNegative) return base;
  final decayed =
      base - (elapsed.inMinutes * perHour / 60).floor();
  return decayed < 0 ? 0 : decayed;
}
