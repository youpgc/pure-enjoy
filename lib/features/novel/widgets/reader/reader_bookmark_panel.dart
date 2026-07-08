import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../../../core/widgets/widgets.dart';

/// 小说阅读器书签列表面板（用于 showModalBottomSheet）
class ReaderBookmarkPanel extends StatelessWidget {
  final List<NovelBookmark> bookmarks;
  final NovelChapterModel? currentChapter;
  final VoidCallback onClose;
  final void Function(NovelBookmark bookmark) onBookmarkTap;

  const ReaderBookmarkPanel({
    super.key,
    required this.bookmarks,
    this.currentChapter,
    required this.onClose,
    required this.onBookmarkTap,
  });

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
                    '书签列表',
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
            child: bookmarks.isEmpty
                ? const EmptyWidget(message: '暂无书签')
                : ListView.builder(
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bm = bookmarks[index];
                      return ListTile(
                        leading: Icon(
                          bm.type == BookmarkType.auto
                              ? Icons.auto_stories
                              : Icons.bookmark,
                          color: bm.type == BookmarkType.auto
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text('第${bm.chapterOrder}章'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bm.note != null && bm.note!.isNotEmpty)
                              Text(
                                bm.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            Text(
                              bm.charOffset > 0
                                  ? '进度 ${(bm.charOffset / (currentChapter?.content.length ?? 1) * 100).toStringAsFixed(0)}%'
                                  : '章节开头',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: bm.note != null && bm.note!.isNotEmpty,
                        trailing: Text(
                          '${bm.createdAt.month}/${bm.createdAt.day}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => onBookmarkTap(bm),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
