import 'package:flutter/material.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';
import './habit_card_content.dart';

/// 习惯卡片组件
class HabitCard extends StatelessWidget {
  final HabitModel habit;
  final bool isCheckedIn;
  final int totalCheckins;
  final ReminderScheduleModel? reminderSchedule;
  final bool shouldRemindToday;
  final bool isCheckingIn;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;
  final VoidCallback onToggleActive;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCheckedIn,
    required this.totalCheckins,
    this.reminderSchedule,
    required this.shouldRemindToday,
    required this.isCheckingIn,
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return HabitCardContent(
      habit: habit,
      isCheckedIn: isCheckedIn,
      totalCheckins: totalCheckins,
      reminderSchedule: reminderSchedule,
      shouldRemindToday: shouldRemindToday,
      isCheckingIn: isCheckingIn,
      onCheckIn: onCheckIn,
      onEdit: onEdit,
      onDelete: onDelete,
      onViewHistory: onViewHistory,
      onToggleActive: onToggleActive,
    );
  }
}
