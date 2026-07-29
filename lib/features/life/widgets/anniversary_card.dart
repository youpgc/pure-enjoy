import 'package:flutter/material.dart';
import '../models/anniversary_model.dart';
import './anniversary_card_content.dart';

/// 纪念日卡片组件
class AnniversaryCard extends StatelessWidget {
  final AnniversaryModel item;
  final String daysText;
  final String formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AnniversaryCard({
    super.key,
    required this.item,
    required this.daysText,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = item.daysUntilNext == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isToday ? colorScheme.primaryContainer : null,
      elevation: isToday ? 4 : 1,
      child: AnniversaryCardContent(
        item: item,
        daysText: daysText,
        formatDate: formatDate,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}
