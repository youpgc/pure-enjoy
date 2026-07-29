import 'package:flutter/material.dart';
import '../../../core/widgets/widgets.dart';
import 'novel_cover.dart';

/// {@template novel_list_item_content}
/// [NovelListItem] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。信息列拆为 [NovelListItemInfo]。
/// {@endtemplate}
class NovelListItemContent extends StatelessWidget {
  /// {@macro novel_list_item_content}
  const NovelListItemContent({
    super.key,
    required this.novel,
    required this.colorScheme,
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
  });

  final Map<String, dynamic> novel;
  final ColorScheme colorScheme;
  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final title = novel['title'] as String? ?? '未知';
    final coverUrl = novel['cover_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NovelCover(
            coverUrl: coverUrl,
            title: title,
            width: 64,
            height: 88,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: NovelListItemInfo(
              novel: novel,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 64,
              height: 32,
              child: isAdded
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: FittedBox(
                        child: Text(
                          '已添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : isAdding
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: LoadingWidget(size: 18),
                          ),
                        )
                      : FilledButton(
                          onPressed: onAdd,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          child: const FittedBox(
                            child: Text(
                              '添加',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 小说列表项信息列：标题 / 作者 / 简介 / 章节·字数。
class NovelListItemInfo extends StatelessWidget {
  const NovelListItemInfo({
    super.key,
    required this.novel,
    required this.colorScheme,
  });

  final Map<String, dynamic> novel;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final title = novel['title'] as String? ?? '未知';
    final author = novel['author'] as String? ?? '佚名';
    final description = novel['description'] as String?;
    final chapterCount = novel['chapter_count'] as int? ?? 0;
    final wordCount = novel['word_count'] as int?;

    return Column(
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
        Text(
          author,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            if (chapterCount > 0)
              Text(
                '$chapterCount章',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (wordCount != null && wordCount > 0) ...[
              if (chapterCount > 0) const SizedBox(width: 8),
              Text(
                wordCount >= 10000
                    ? '${(wordCount / 10000).toStringAsFixed(1)}万字'
                    : '$wordCount字',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
