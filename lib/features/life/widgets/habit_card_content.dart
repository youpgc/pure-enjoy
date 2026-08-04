import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_item.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';

part 'habit_card_parts.dart';

/// {@template habit_card_content}
/// [HabitCard] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。为规避「超长方法」告警，
/// 进一步拆为 Header / Menu / StatsRow / Progress / Action 五个子组件
/// （见同库 habit_card_parts.dart）。
/// {@endtemplate}
class HabitCardContent extends StatelessWidget {
  /// {@macro habit_card_content}
  const HabitCardContent({
    super.key,
    required this.habit,
    required this.isCheckedIn,
    required this.totalCheckins,
    this.isCompleted = false,
    this.reminderSchedule,
    required this.shouldRemindToday,
    required this.isCheckingIn,
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
    required this.onToggleActive,
  });

  final HabitModel habit;
  final bool isCheckedIn;
  final int totalCheckins;
  final bool isCompleted;
  final ReminderScheduleModel? reminderSchedule;
  final bool shouldRemindToday;
  final bool isCheckingIn;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final habitColor = Color(habitColors['blue']!);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HabitCardHeader(
              habit: habit,
              isCompleted: isCompleted,
              reminderSchedule: reminderSchedule,
              shouldRemindToday: shouldRemindToday,
              onViewHistory: onViewHistory,
              onToggleActive: onToggleActive,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
            const SizedBox(height: 12),
            HabitCardStatsRow(
              targetDays: habit.targetDays,
              totalCheckins: totalCheckins,
              longestStreak: habit.longestStreak,
            ),
            const SizedBox(height: 12),
            HabitCardProgress(
              targetDays: habit.targetDays,
              totalCheckins: totalCheckins,
              color: habitColor,
            ),
            const SizedBox(height: 12),
            HabitCardAction(
              isCheckedIn: isCheckedIn,
              isCheckingIn: isCheckingIn,
              isCompleted: isCompleted,
              color: habitColor,
              onCheckIn: onCheckIn,
            ),
          ],
        ),
      ),
    );
  }
}
