import 'package:flutter/material.dart';
import 'bookshelf_item_content.dart';

/// 书架列表项
class BookshelfItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final ColorScheme colorScheme;
  final String Function(double?) getStatusText;
  final Color Function(double?, ColorScheme) getStatusColor;
  final String Function(String?) formatLastRead;
  final String Function(int?) formatWordCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BookshelfItem({
    super.key,
    required this.item,
    required this.colorScheme,
    required this.getStatusText,
    required this.getStatusColor,
    required this.formatLastRead,
    required this.formatWordCount,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return BookshelfItemContent(
      item: item,
      colorScheme: colorScheme,
      getStatusText: getStatusText,
      getStatusColor: getStatusColor,
      formatLastRead: formatLastRead,
      formatWordCount: formatWordCount,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
