import 'package:flutter/material.dart';
import '../../../core/widgets/widgets.dart';
import '../models/novel_model.dart';

/// 显示评分对话框
void showNovelRatingDialog(
  BuildContext context, {
  required String novelTitle,
  required Future<void> Function(double) onSubmit,
}) {
  double tempRating = 0;
  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('为这本小说评分'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              novelTitle,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    i < tempRating.round() ? Icons.star : Icons.star_border,
                    color: i < tempRating.round() ? Colors.amber : null,
                  ),
                  onPressed: () {
                    setDialogState(() => tempRating = (i + 1).toDouble());
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              tempRating > 0 ? '${tempRating.toStringAsFixed(1)} 分' : '请选择评分',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: tempRating > 0
                ? () {
                    Navigator.pop(dialogContext);
                    onSubmit(tempRating);
                  }
                : null,
            child: const Text('提交'),
          ),
        ],
      ),
    ),
  );
}

/// 显示章节目录（弹窗内独立全量加载）
void showNovelChapterListSheet(
  BuildContext context, {
  required Future<List<NovelChapterModel>> Function() loadAllChapters,
  required int currentChapter,
  required void Function(int) onJump,
  required void Function(List<NovelChapterModel>) onChaptersLoaded,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        List<NovelChapterModel> allChapters = [];
        bool isLoading = true;

        // 异步加载全部章节
        loadAllChapters().then((chapters) {
          if (context.mounted) {
            setModalState(() {
              allChapters = chapters;
              isLoading = false;
            });
            // 同时更新详情页的 _chapters（避免后续重复加载）
            onChaptersLoaded(chapters);
          }
        });

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '章节目录',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      isLoading ? '加载中...' : '共 ${allChapters.length} 章',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: isLoading
                    ? const Center(child: LoadingWidget())
                    : allChapters.isEmpty
                        ? const Center(child: Text('暂无章节'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: allChapters.length,
                            itemBuilder: (context, index) {
                              final chapter = allChapters[index];
                              final isCurrent = chapter.chapterOrder == currentChapter;

                              return ListTile(
                                dense: true,
                                title: Text(
                                  chapter.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isCurrent
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontWeight: isCurrent ? FontWeight.bold : null,
                                  ),
                                ),
                                trailing: isCurrent
                                    ? Icon(
                                        Icons.play_arrow,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 20,
                                      )
                                    : Text(
                                        '${chapter.wordCount ?? ""}字',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                onTap: () {
                                  Navigator.pop(context);
                                  onJump(chapter.chapterOrder);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// 显示"移除书架"二次确认对话框
Future<bool?> showRemoveFromBookshelfDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认移除'),
      content: const Text('确定要将这本小说从书架移除吗？阅读进度将不会保留。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('移除'),
        ),
      ],
    ),
  );
}
