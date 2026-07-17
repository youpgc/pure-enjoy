import 'package:flutter/material.dart';
import 'filter_chip.dart';

/// 书架状态筛选栏
class BookshelfFilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String filterStatus;
  final ValueChanged<String> onFilterChanged;

  const BookshelfFilterBar({
    super.key,
    required this.items,
    required this.filterStatus,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            BookshelfFilterChip(
              label: '全部',
              count: items.length,
              isSelected: filterStatus == 'all',
              onTap: () => onFilterChanged('all'),
            ),
            BookshelfFilterChip(
              label: '在读',
              count: items.where((i) {
                final p = (i['progress'] as num?)?.toDouble() ?? 0.0;
                return p > 0 && p < 1;
              }).length,
              isSelected: filterStatus == 'reading',
              onTap: () => onFilterChanged('reading'),
            ),
            BookshelfFilterChip(
              label: '已读完',
              count: items.where((i) {
                final p = (i['progress'] as num?)?.toDouble() ?? 0.0;
                return p >= 1;
              }).length,
              isSelected: filterStatus == 'completed',
              onTap: () => onFilterChanged('completed'),
            ),
          ],
        ),
      ),
    );
  }
}
