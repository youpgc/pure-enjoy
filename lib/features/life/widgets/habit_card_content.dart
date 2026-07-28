import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stat_item.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';

/// {@template habit_card_content}
/// [HabitCard] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。为规避「超长方法」告警，
/// 进一步拆为 Header / Menu / StatsRow / Progress / Action 五个子组件。
/// {@endtemplate}
class HabitCardContent extends StatelessWidget {
  /// {@macro habit_card_content}
  const HabitCardContent({
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
              color: habitColor,
              onCheckIn: onCheckIn,
            ),
          ],
        ),
      ),
    );
  }
}

/// 习惯卡片头部：图标 + 名称/描述/提醒 + 操作菜单。
class HabitCardHeader extends StatelessWidget {
  const HabitCardHeader({
    super.key,
    required this.habit,
    this.reminderSchedule,
    required this.shouldRemindToday,
    required this.onViewHistory,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final HabitModel habit;
  final ReminderScheduleModel? reminderSchedule;
  final bool shouldRemindToday;
  final VoidCallback onViewHistory;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = Color(habitColors['blue']!);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: habitColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.track_changes, color: habitColor),
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
                  if (!habit.isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '已暂停',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
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
              if (reminderSchedule != null && reminderSchedule!.isEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      shouldRemindToday
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: 14,
                      color: shouldRemindToday
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      reminderSchedule!.getScheduleDescription(),
                      style: TextStyle(
                        fontSize: 11,
                        color: shouldRemindToday
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        HabitCardMenu(
          habit: habit,
          onViewHistory: onViewHistory,
          onToggleActive: onToggleActive,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

/// 习惯卡片右上角操作菜单（打卡记录 / 暂停恢复 / 编辑 / 删除）。
class HabitCardMenu extends StatelessWidget {
  const HabitCardMenu({
    super.key,
    required this.habit,
    required this.onViewHistory,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final HabitModel habit;
  final VoidCallback onViewHistory;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
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
              Icon(Icons.delete, size: 20,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text('删除',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 习惯卡片三项统计（目标天数 / 总打卡 / 最长连续）。
class HabitCardStatsRow extends StatelessWidget {
  const HabitCardStatsRow({
    super.key,
    required this.targetDays,
    required this.totalCheckins,
    required this.longestStreak,
  });

  final int targetDays;
  final int totalCheckins;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        StatItem(
          label: '目标天数',
          value: '$targetDays',
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
          value: '$longestStreak',
          icon: Icons.local_fire_department,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

/// 习惯卡片进度条与百分比文字。
class HabitCardProgress extends StatelessWidget {
  const HabitCardProgress({
    super.key,
    required this.targetDays,
    required this.totalCheckins,
    required this.color,
  });

  final int targetDays;
  final int totalCheckins;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = targetDays > 0 ? totalCheckins / targetDays : 0.0;
    final percent = targetDays > 0 ? (ratio * 100).toInt() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '进度: $totalCheckins/$targetDays 天 ($percent%)',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// 习惯卡片底部打卡按钮。
class HabitCardAction extends StatelessWidget {
  const HabitCardAction({
    super.key,
    required this.isCheckedIn,
    required this.color,
    required this.onCheckIn,
  });

  final bool isCheckedIn;
  final Color color;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isCheckedIn ? null : onCheckIn,
        icon: Icon(isCheckedIn ? Icons.check : Icons.add),
        label: Text(isCheckedIn ? '今日已打卡' : '立即打卡'),
        style: FilledButton.styleFrom(
          backgroundColor: isCheckedIn ? AppTheme.success : color,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
