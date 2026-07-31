import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/anniversary_model.dart';

/// {@template anniversary_card_content}
/// [AnniversaryCard] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段，不持有状态。
/// {@endtemplate}
class AnniversaryCardContent extends StatelessWidget {
  /// {@macro anniversary_card_content}
  const AnniversaryCardContent({
    super.key,
    required this.item,
    required this.daysText,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  final AnniversaryModel item;
  final String daysText;
  final String formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnniversaryCardHeader(
            item: item,
            formatDate: formatDate,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
          const SizedBox(height: 12),
          AnniversaryCardFooter(item: item, daysText: daysText),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// 顶部：图标 + 标题/类型标签 + 农历/提醒标记 + 更多操作菜单
class AnniversaryCardHeader extends StatelessWidget {
  const AnniversaryCardHeader({
    super.key,
    required this.item,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  final AnniversaryModel item;
  final String formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBirthday = item.type == 'birthday';
    final cardColor = isBirthday
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : colorScheme.tertiaryContainer.withValues(alpha: 0.5);
    final iconColor = isBirthday ? colorScheme.primary : colorScheme.tertiary;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(
              UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
            ),
          ),
          child: Icon(
            isBirthday ? Icons.cake : Icons.celebration,
            color: iconColor,
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
                      item.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isBirthday ? '生日' : '纪念日',
                      style: TextStyle(fontSize: 11, color: iconColor),
                    ),
                  ),
                  if (item.isLunar) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '农历',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  if (item.remindEnabled)
                    Icon(
                      Icons.notifications_active,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatDate,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
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
                  Icon(Icons.delete,
                      size: 20,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text('删除',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 底部信息行：距离天数 / 年龄 / 重复信息
class AnniversaryCardFooter extends StatelessWidget {
  const AnniversaryCardFooter({
    super.key,
    required this.item,
    required this.daysText,
  });

  final AnniversaryModel item;
  final String daysText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = item.daysUntilNext == 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isToday
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            daysText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isToday
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (item.age != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.age}岁',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        const Spacer(),
        if (item.repeatYearly)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, size: 14, color: colorScheme.outline),
              const SizedBox(width: 2),
              Text('每年',
                  style:
                      TextStyle(fontSize: 12, color: colorScheme.outline)),
            ],
          )
        else
          Text('仅一次',
              style: TextStyle(fontSize: 12, color: colorScheme.outline)),
      ],
    );
  }
}
