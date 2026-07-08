import 'package:flutter/material.dart';
import '../../../../utils/date_time_utils.dart';
import '../../../life/models/reminder_model.dart';

/// 待办提醒横幅区块组件
///
/// 展示即将到期或已过期的提醒事项。
class TodoReminderSection extends StatelessWidget {
  final List<ReminderModel> reminders;
  final ValueChanged<ReminderModel> onTap;

  const TodoReminderSection({
    super.key,
    required this.reminders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (reminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ...reminders.map((reminder) {
          final isOverdue = reminder.remindAt.isBefore(DateTime.now());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onTap(reminder),
              borderRadius: BorderRadius.circular(12),
              child: Card(
                color: isOverdue
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.notification_important
                            : Icons.notifications_active,
                        color: isOverdue
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (reminder.description != null &&
                                reminder.description!.isNotEmpty)
                              Text(
                                reminder.description!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              DateTimeUtils.formatStandard(reminder.remindAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isOverdue
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
