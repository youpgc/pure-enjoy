import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// 小说详情操作按钮行（开始阅读/书架/缓存/收藏）
class NovelDetailActions extends StatelessWidget {
  final bool isInBookshelf;
  final bool isLoadingShelf;
  final int currentChapter;
  final bool isDownloading;
  final int cachedChapterCount;
  final int chaptersLength;
  final bool isCollected;
  final VoidCallback onStartReading;
  final VoidCallback onToggleBookshelf;
  final VoidCallback onDownload;
  final VoidCallback onClear;
  final VoidCallback onToggleCollect;

  const NovelDetailActions({
    super.key,
    required this.isInBookshelf,
    required this.isLoadingShelf,
    required this.currentChapter,
    required this.isDownloading,
    required this.cachedChapterCount,
    required this.chaptersLength,
    required this.isCollected,
    required this.onStartReading,
    required this.onToggleBookshelf,
    required this.onDownload,
    required this.onClear,
    required this.onToggleCollect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 开始阅读按钮
            Expanded(
              child: FilledButton.icon(
                onPressed: onStartReading,
                icon: const Icon(Icons.menu_book),
                label: Text(
                  isInBookshelf && currentChapter > 1
                      ? '继续阅读 第$currentChapter章'
                      : '开始阅读',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 书架按钮
            SizedBox(
              width: 48,
              height: 48,
              child: isLoadingShelf
                  ? const Center(child: LoadingWidget(size: 24))
                  : OutlinedButton(
                      onPressed: onToggleBookshelf,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Icon(
                        isInBookshelf
                            ? Icons.library_books
                            : Icons.library_add_outlined,
                        color: isInBookshelf ? colorScheme.primary : null,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // 缓存下载按钮
            SizedBox(
              width: 48,
              height: 48,
              child: isDownloading
                  ? const Center(child: LoadingWidget(size: 24))
                  : OutlinedButton(
                      onPressed: cachedChapterCount > 0 &&
                              cachedChapterCount >= chaptersLength
                          ? onClear
                          : onDownload,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Icon(
                        cachedChapterCount > 0
                            ? Icons.download_done
                            : Icons.download_outlined,
                        color: cachedChapterCount > 0 ? AppTheme.success : null,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // 收藏按钮
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                onPressed: isInBookshelf ? onToggleCollect : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                ),
                child: Icon(
                  isCollected
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: isCollected
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
