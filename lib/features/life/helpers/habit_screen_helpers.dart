import 'package:flutter/material.dart';
import '../../../core/widgets/widgets.dart';
import '../models/habit_model.dart';

/// 习惯页通用小工具（从 [HabitsScreen] 抽离，治理 §1.5.5 膨胀防御）。
void showHabitError(BuildContext context, String message) {
  showSnackBar(context, message, isError: true);
}

bool isCheckedInToday(List<HabitCheckinModel> checkins) {
  final today = DateTime.now();
  return checkins.any((c) => DateUtils.isSameDay(c.checkinAt, today));
}

int getTotalCheckins(List<HabitCheckinModel> checkins) => checkins.length;
