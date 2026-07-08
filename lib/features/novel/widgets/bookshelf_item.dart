import 'package:flutter/material.dart';

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

  /// 根据 progress 计算阅读状态
  String _getReadingStatus(double? progress) {
    if (progress == null || progress == 0) return 'unread';
    if (progress >= 1) return 'completed';
    return 'reading';
  }

  @override
  Widget build(BuildContext context) {
    final novelData = item['novels'] as Map<String, dynamic>?;
    final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
    final status = _getReadingStatus(progress);
    final lastChapter = item['last_chapter'] as int? ?? 0;
    final lastReadAt = item['last_read_at'] as String?;

    if (novelData == null) return const SizedBox.shrink();

    final title = novelData['title'] as String? ?? '未知';
    final author = novelData['author'] as String? ?? '佚名';
    final coverUrl = novelData['cover_url'] as String?;
    final chapterCount = novelData['chapter_count'] as int? ?? 0;
    final wordCount = novelData['word_count'] as int?;
    final category = novelData['category'] as String?;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 76,
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.book,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.book,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                      ),
                      if (category != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: getStatusColor(progress, colorScheme)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          getStatusText(progress),
                          style: TextStyle(
                            fontSize: 11,
                            color: getStatusColor(progress, colorScheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 阅读进度
                      Expanded(
                        child: Text(
                          chapterCount == 0
                              ? '读到第 $lastChapter 章（共0章）'
                              : '读到第 $lastChapter / $chapterCount 章',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (lastReadAt != null || wordCount != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (lastReadAt != null) ...[
                          Text(
                            '上次阅读: ${formatLastRead(lastReadAt)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                          ),
                          if (wordCount != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              formatWordCount(wordCount),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 继续阅读按钮
            if (status == 'reading')
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
