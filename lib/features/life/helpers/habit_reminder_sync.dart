import '../../../services/notification_service.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';

/// 习惯启停后同步提醒计划（暂停取消 / 恢复重挂，已完成则不再重挂）。
/// 从 [HabitsScreen._toggleHabitActive] 抽离（治理 §1.5.5 膨胀防御）。
/// 行为与原内联实现逐字节等价。
Future<void> syncHabitReminderOnToggle({
  required bool isActiveNow,
  required HabitModel habit,
  required ReminderScheduleModel? schedule,
  required int totalCheckins,
}) async {
  if (!isActiveNow) {
    // 暂停：取消提醒
    await NotificationService.instance.cancelHabitReminder(habit.id);
    return;
  }
  // 恢复：已完成习惯即便恢复启用也不重挂，否则按原计划重挂
  final completed = isHabitCompleted(totalCheckins, habit.targetDays);
  if (completed) {
    await NotificationService.instance.cancelHabitReminder(habit.id);
  } else if (schedule != null) {
    await NotificationService.instance.scheduleHabitReminder(
      schedule: schedule,
      habitName: habit.name,
    );
  }
}
