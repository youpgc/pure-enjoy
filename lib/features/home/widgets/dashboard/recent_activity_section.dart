import 'package:flutter/material.dart';
import '../activity_item.dart';

/// 最近活动区块组件
///
/// 展示用户最近的心情日记、支出记录和体重记录。
class RecentActivitySection extends StatefulWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> activities;

  const RecentActivitySection({
    super.key,
    required this.isLoading,
    required this.activities,
  });

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近活动',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: widget.isLoading
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: EdgeInsets.only(bottom: i < 2 ? 12 : 0),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 120,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : widget.activities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '暂无最近活动',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children:
                            List.generate(widget.activities.length, (index) {
                          final activity = widget.activities[index];
                          return Column(
                            children: [
                              ActivityItem(
                                icon: activity['icon'] as IconData,
                                title: activity['title'] as String,
                                subtitle: activity['subtitle'] as String,
                                time: activity['time'] as String,
                              ),
                              if (index < widget.activities.length - 1)
                                const Divider(),
                            ],
                          );
                        }),
                      ),
                    ),
        ),
      ],
    );
  }
}
