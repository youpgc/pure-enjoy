import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import './novel_card_content.dart';

/// 小说卡片（书架/列表通用）
class NovelCard extends StatelessWidget {
  final NovelModel novel;
  final VoidCallback onTap;
  final VoidCallback? onAddToBookshelf;
  final bool isInBookshelf;

  const NovelCard({
    super.key,
    required this.novel,
    required this.onTap,
    this.onAddToBookshelf,
    this.isInBookshelf = false,
  });

  @override
  Widget build(BuildContext context) {
    return NovelCardContent(
      novel: novel,
      onTap: onTap,
      onAddToBookshelf: onAddToBookshelf,
      isInBookshelf: isInBookshelf,
    );
  }
}
