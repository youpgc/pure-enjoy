import 'package:flutter/material.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../models/habit_model.dart';

/// 习惯页通用小工具（从 [HabitsScreen] 抽离，治理 §1.5.5 膨胀防御）。
void showHabitError(BuildContext context, String message) {
  showSnackBar(context, message, isError: true);
}

/// 「今天是否已打卡」按北京自然日比较：checkin_at 为 UTC 时间戳，
/// 原 `DateUtils.isSameDay` 走设备本地日，北京 00:00–08:00 窗口会错位。
bool isCheckedInToday(List<HabitCheckinModel> checkins) {
  final today = DateTimeUtils.todayBeijingKey();
  return checkins.any((c) => DateTimeUtils.beijingDateKey(c.checkinAt) == today);
}

int getTotalCheckins(List<HabitCheckinModel> checkins) => checkins.length;
