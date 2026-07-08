import 'package:flutter/material.dart';
import '../../screens/sheets/tool_config_sheet.dart';
import '../tool_card.dart';

/// 快捷工具网格区块组件
///
/// 展示用户配置的常用工具入口。
class QuickToolsSection extends StatelessWidget {
  final List<ToolItem> visibleTools;
  final VoidCallback onConfigTap;
  final ValueChanged<ToolItem> onToolTap;

  const QuickToolsSection({
    super.key,
    required this.visibleTools,
    required this.onConfigTap,
    required this.onToolTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '常用工具',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: onConfigTap,
              tooltip: '配置',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleTools.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '点击右上角配置按钮添加工具',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: visibleTools.length,
            itemBuilder: (context, index) {
              final tool = visibleTools[index];
              return ToolCard(
                icon: tool.icon,
                label: tool.label,
                color: tool.color,
                onTap: () => onToolTap(tool),
              );
            },
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
