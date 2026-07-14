import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_item.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';

/// 习惯卡片组件
class HabitCard extends StatelessWidget {
  final HabitModel habit;
  final bool isCheckedIn;
  final int totalCheckins;
  final ReminderScheduleModel? reminderSchedule;
  final bool shouldRemindToday;
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
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = Color(habitColors['blue']!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.track_changes,
                    color: habitColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              habit.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (!habit.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '已暂停',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (habit.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          habit.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 提醒状态
                      if (reminderSchedule != null && reminderSchedule!.isEnabled) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              shouldRemindToday ? Icons.notifications_active : Icons.notifications_none,
                              size: 14,
                              color: shouldRemindToday
                                  ? Theme.of(context).colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reminderSchedule!.getScheduleDescription(),
                              style: TextStyle(
                                fontSize: 11,
                                color: shouldRemindToday
                                    ? Theme.of(context).colorScheme.primary
                                    : colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'history':
                        onViewHistory();
                        break;
                      case 'toggle':
                        onToggleActive();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text('打卡记录'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            habit.isActive ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: habit.isActive
                                ? Theme.of(context).colorScheme.primary
                                : AppTheme.success,
                          ),
                          const SizedBox(width: 8),
                          Text(habit.isActive ? '暂停' : '恢复'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatItem(
                  label: '目标天数',
                  value: '${habit.targetDays}',
                  icon: Icons.flag,
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatItem(
                  label: '总打卡',
                  value: '$totalCheckins',
                  icon: Icons.check_circle,
                  color: AppTheme.success,
                ),
                StatItem(
                  label: '最长连续',
                  value: '${habit.longestStreak}',
                  icon: Icons.local_fire_department,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: habit.targetDays > 0 ? totalCheckins / habit.targetDays : 0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '进度: $totalCheckins/${habit.targetDays} 天 (${habit.targetDays > 0 ? ((totalCheckins / habit.targetDays) * 100).toInt() : 0}%)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isCheckedIn ? null : onCheckIn,
                icon: Icon(isCheckedIn ? Icons.check : Icons.add),
                label: Text(isCheckedIn ? '今日已打卡' : '立即打卡'),
                style: FilledButton.styleFrom(
                  backgroundColor: isCheckedIn ? AppTheme.success : habitColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
