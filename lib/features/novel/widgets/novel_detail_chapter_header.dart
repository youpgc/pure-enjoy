import 'package:flutter/material.dart';

/// 小说详情章节目录头部
class NovelDetailChapterHeader extends StatelessWidget {
  final bool isLoadingChapters;
  final int chapterCount;
  final VoidCallback onShowAll;

  const NovelDetailChapterHeader({
    super.key,
    required this.isLoadingChapters,
    required this.chapterCount,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              '章节目录',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (!isLoadingChapters)
              Text(
                '共 $chapterCount 章',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onShowAll,
              child: Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
