import 'package:flutter/material.dart';

/// 统计信息项组件
///
/// 支持两种展示模式：
/// - 无图标模式：用于小说详情等场景，占据等分空间
/// - 图标模式：用于习惯打卡等场景，展示图标+数值
class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (icon != null && color != null) {
      // 图标模式（原 habits_screen 版本）
      content = Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      );
    } else {
      // 无图标模式（原 novel_detail_screen 版本）
      content = Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (icon != null) {
      return content;
    }
    return Expanded(child: content);
  }
}
