import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../../../../core/widgets/widgets.dart';

/// 小说阅读器批注输入面板（用于 showModalBottomSheet）
class ReaderAnnotationPanel extends StatefulWidget {
  final String selectedText;
  final int startOffset;
  final int endOffset;
  final void Function(String selectedText, int startOffset, int endOffset, String? note, String color) onSave;

  const ReaderAnnotationPanel({
    super.key,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    required this.onSave,
  });

  @override
  State<ReaderAnnotationPanel> createState() => _ReaderAnnotationPanelState();
}

class _ReaderAnnotationPanelState extends State<ReaderAnnotationPanel> {
  final _noteController = TextEditingController();
  String _selectedColor = 'yellow';

  final _colorOptions = const [
    ('yellow', Color(0xFFFFF176)),
    ('green', Color(0xFFA5D6A7)),
    ('blue', Color(0xFF90CAF9)),
    ('pink', Color(0xFFF48FB1)),
    ('purple', Color(0xFFCE93D8)),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '添加批注',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 原文预览
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.selectedText,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            // 颜色选择
            Text('高亮颜色', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colorOptions.map((option) {
                final (colorName, color) = option;
                final isSelected = _selectedColor == colorName;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorName),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // 笔记输入
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '输入你的笔记（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSave(
                    widget.selectedText,
                    widget.startOffset,
                    widget.endOffset,
                    _noteController.text.isEmpty ? null : _noteController.text,
                    _selectedColor,
                  );
                },
                child: const Text('保存批注'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 小说阅读器批注列表面板（用于 showModalBottomSheet）
class ReaderAnnotationListPanel extends StatelessWidget {
  final List<NovelAnnotation> annotations;
  final VoidCallback onClose;
  final void Function(NovelAnnotation annotation) onDelete;
  final void Function(NovelAnnotation annotation)? onTap;

  const ReaderAnnotationListPanel({
    super.key,
    required this.annotations,
    required this.onClose,
    required this.onDelete,
    this.onTap,
  });

  Color _parseHighlightColor(String color) {
    switch (color) {
      case 'yellow': return const Color(0xFFFFF176);
      case 'green': return const Color(0xFFA5D6A7);
      case 'blue': return const Color(0xFF90CAF9);
      case 'pink': return const Color(0xFFF48FB1);
      case 'purple': return const Color(0xFFCE93D8);
      default: return const Color(0xFFFFF176);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '我的批注',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: onClose,
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: annotations.isEmpty
                ? const EmptyWidget(message: '暂无批注，长按正文选中文本添加')
                : ListView.builder(
                    itemCount: annotations.length,
                    itemBuilder: (context, index) {
                      final annotation = annotations[index];
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _parseHighlightColor(annotation.color.name),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: Text(
                          annotation.highlightedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: annotation.note != null && annotation.note!.isNotEmpty
                            ? Text(
                                annotation.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => onDelete(annotation),
                        ),
                        onTap: onTap != null ? () => onTap!(annotation) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
