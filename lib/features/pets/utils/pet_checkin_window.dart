import '../models/pet_rpc_models.dart';

/// 签到奖励网格的槽位与收起窗口计算（纯逻辑，便于单测与复用）。
///
/// 槽位 = 当月累计签到第 N 次，与日历日期无关；奖励模板最多 31 槽，
/// 实际展示格数按当月天数钳制（当月最多只能签到当月天数次）。
/// 收起以 4 格为一组，展示待签槽所在组及其后一组。

/// 奖励模板槽数（服务端月模板 31 槽）；状态返回空表时的骨架兜底，不造奖励值
const int kPetCheckinTemplateSlots = 31;

/// 收起窗口的组宽（4 格一行）与显示组数（两组共 8 格）
const int kPetCheckinGroupSize = 4;
const int kPetCheckinCollapsedGroups = 2;

/// 展示槽总数：模板最大槽与当月天数取小值；空表（未配置 / 骨架）
/// 按模板默认槽数参与钳制，不造奖励值
int petCheckinTotalSlots(PetCheckinStatusModel st, int daysInMonth) {
  final templateMax = st.days.isEmpty
      ? kPetCheckinTemplateSlots
      : st.days.keys.fold<int>(0, (a, b) => b > a ? b : a);
  return daysInMonth < templateMax ? daysInMonth : templateMax;
}

/// 收起窗口：待签槽所在组为第一组，再带上后一组；末尾组不满 4 格时
/// 与倒数第二组一并返回（如 31 天月的 25-28 + 29-31、30 天月的
/// 25-28 + 29-30），保证两组都有内容
(int, int) petCheckinCollapsedWindow(int nextSlot, int totalSlots) {
  final lastGroupStart =
      ((totalSlots - 1) ~/ kPetCheckinGroupSize) * kPetCheckinGroupSize + 1;
  final groupStart =
      ((nextSlot - 1) ~/ kPetCheckinGroupSize) * kPetCheckinGroupSize + 1;
  final tailStart = lastGroupStart - kPetCheckinGroupSize;
  final start = groupStart >= tailStart
      ? (tailStart > 0 ? tailStart : 1)
      : groupStart;
  final end = start + kPetCheckinCollapsedGroups * kPetCheckinGroupSize - 1;
  return (start, end > totalSlots ? totalSlots : end);
}
