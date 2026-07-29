import 'package:flutter/material.dart';
import '../../../life/models/habit_model.dart';
import '../../../life/screens/habits_screen.dart';

/// 习惯打卡区块组件
///
/// 展示今日待打卡的习惯列表，支持一键打卡。
class HabitCheckinSection extends StatelessWidget {
  final List<HabitModel> pendingHabits;
  final String? checkingHabitId;
  final ValueChanged<HabitModel> onCheckIn;
  final VoidCallback? onViewAll;

  const HabitCheckinSection({
    super.key,
    required this.pendingHabits,
    this.checkingHabitId,
    required this.onCheckIn,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (pendingHabits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '今日打卡',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HabitsScreen()),
                ).then((_) => onViewAll?.call());
              },
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: pendingHabits.map((habit) {
            final habitColor = colorScheme.primary;
            final isChecking = checkingHabitId == habit.id;

            return SizedBox(
              width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
              height: 52,
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: isChecking ? null : () => onCheckIn(habit),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            habit.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isChecking)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          Icon(
                            Icons.check_circle_outline,
                            color: habitColor,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
