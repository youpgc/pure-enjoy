import 'package:flutter/material.dart';
import '../../../utils/date_time_utils.dart';
import '../../life/models/habit_model.dart';
import '../../life/models/mood_diary_model.dart';
import '../../life/models/expense_model.dart';
import '../../life/models/weight_record_model.dart';
import '../../life/models/note_model.dart';
import '../../life/models/reminder_model.dart';
import '../../life/models/reminder_schedule_model.dart';
import 'sheets/sheets.dart';

/// 格式化时间显示（优先创建时间，非同一天则展示选择日期）
String formatDashboardDisplayDate(String? createdAt, String? selectedDate) {
  if (createdAt == null && selectedDate == null) return '';
  final created = createdAt != null ? DateTime.tryParse(createdAt) : null;
  if (created == null) {
    final dt = selectedDate != null ? DateTime.tryParse(selectedDate) : null;
    if (dt == null) return '';
    return DateTimeUtils.formatStandard(dt);
  }
  final createdLocal = created.toLocal();
  if (selectedDate != null) {
    final selected = DateTime.tryParse(selectedDate);
    if (selected != null &&
        (createdLocal.year != selected.year ||
            createdLocal.month != selected.month ||
            createdLocal.day != selected.day)) {
      return DateTimeUtils.formatStandard(selected);
    }
  }
  return DateTimeUtils.formatStandard(created);
}

/// 显示添加心情日记弹窗
void showAddMoodSheet(BuildContext context,
    {required void Function(MoodDiaryModel) onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddMoodSheet(onSave: onSave),
  );
}

/// 显示添加支出弹窗
void showAddExpenseSheet(BuildContext context,
    {required void Function(ExpenseModel) onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddExpenseSheet(onSave: onSave),
  );
}

/// 显示添加体重弹窗
void showAddWeightSheet(BuildContext context,
    {required void Function(WeightRecordModel) onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddWeightSheet(onSave: onSave),
  );
}

/// 显示添加笔记弹窗
void showAddNoteSheet(BuildContext context,
    {required void Function(NoteModel) onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddNoteSheet(onSave: onSave),
  );
}

/// 显示添加提醒弹窗
void showAddReminderSheet(BuildContext context,
    {required void Function(ReminderModel) onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddReminderSheet(onSave: onSave),
  );
}

/// 显示添加习惯弹窗
void showAddHabitSheet(BuildContext context,
    {required Future<void> Function(HabitModel, ReminderScheduleModel?)
        onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddHabitSheet(onSave: onSave),
  );
}

/// 显示工具配置弹窗
void showToolConfigSheet(BuildContext context,
    {required List<String> visibleIds,
    required void Function(List<String>) onSave}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ToolConfigSheet(
      visibleIds: visibleIds,
      onSave: onSave,
    ),
  );
}
