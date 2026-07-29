import 'package:flutter/material.dart';
import './novel_list_item_content.dart';

/// 小说列表项组件
class NovelListItem extends StatelessWidget {
  final Map<String, dynamic> novel;
  final ColorScheme colorScheme;
  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  const NovelListItem({
    super.key,
    required this.novel,
    required this.colorScheme,
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return NovelListItemContent(
      novel: novel,
      colorScheme: colorScheme,
      isAdded: isAdded,
      isAdding: isAdding,
      onAdd: onAdd,
    );
  }
}
