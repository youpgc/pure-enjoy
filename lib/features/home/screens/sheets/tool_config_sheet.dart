import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';

/// 工具项定义
class ToolItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const ToolItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// 所有可用工具列表
const List<ToolItem> allTools = [
  ToolItem(id: 'diary', label: '写日记', icon: Icons.note_add_outlined, color: Color(0xFFFFB300)),
  ToolItem(id: 'expense', label: '记一笔', icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50)),
  ToolItem(id: 'weight', label: '记体重', icon: Icons.monitor_weight_outlined, color: Color(0xFFF26522)),
  ToolItem(id: 'note', label: '记笔记', icon: Icons.sticky_note_2_outlined, color: Color(0xFFF26522)),
  ToolItem(id: 'reminder', label: '添加提醒', icon: Icons.alarm_add_outlined, color: Color(0xFFFFB300)),
  ToolItem(id: 'habit', label: '添加习惯', icon: Icons.track_changes_outlined, color: Color(0xFFFF9800)),
  ToolItem(id: 'pet', label: '宠物', icon: Icons.pets_outlined, color: Color(0xFF8D6E63)),
];

/// 工具配置底部弹窗
///
/// 用于选择首页仪表板中显示的常用工具。
class ToolConfigSheet extends StatefulWidget {
  final List<String> visibleIds;
  final ValueChanged<List<String>> onSave;

  /// 宠物系统总开关（pet_enabled=false 时「宠物」工具禁选——
  /// 首页网格亦不渲染该工具，避免「可选却不出」的困惑）。
  final bool petEnabled;

  const ToolConfigSheet({
    super.key,
    required this.visibleIds,
    required this.onSave,
    required this.petEnabled,
  });

  @override
  State<ToolConfigSheet> createState() => ToolConfigSheetState();
}

class ToolConfigSheetState extends State<ToolConfigSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.visibleIds);
  }

  @override
  Widget build(BuildContext context) {
    // SheetContainer：键盘避让 + 手势条 SafeArea + 滚动兜底（统一容器规范）
    return SheetContainer(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      bottomSpacing: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '配置常用工具',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '选择要在首页显示的工具',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allTools.map((tool) {
              final isSelected = _selectedIds.contains(tool.id);
              // 宠物系统关闭时「宠物」工具禁选（与首页网格门控一致）
              final locked = tool.id == 'pet' && !widget.petEnabled;
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tool.icon,
                        size: 16,
                        color: isSelected && !locked
                            ? Colors.white
                            : tool.color),
                    const SizedBox(width: 6),
                    Text(tool.label),
                  ],
                ),
                selected: isSelected && !locked,
                selectedColor: tool.color,
                checkmarkColor: Colors.white,
                onSelected: locked
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedIds.add(tool.id);
                          } else {
                            _selectedIds.remove(tool.id);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          if (!widget.petEnabled) ...[
            const SizedBox(height: 8),
            Text(
              '「宠物」工具暂未开放，系统开启后可添加到首页',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.onSave(_selectedIds);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
