import 'package:flutter/material.dart';
import '../../../core/widgets/widgets.dart';
import '../models/novel_model.dart';

/// 小说详情章节列表
class NovelDetailChapterList extends StatelessWidget {
  final List<NovelChapterModel> chapters;
  final int currentChapter;
  final bool hasMoreChapters;
  final bool isLoadingChapters;
  final bool isLoadingMoreChapters;
  final void Function(int) onJump;

  const NovelDetailChapterList({
    super.key,
    required this.chapters,
    required this.currentChapter,
    required this.hasMoreChapters,
    required this.isLoadingChapters,
    required this.isLoadingMoreChapters,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (isLoadingChapters) {
            return const ListTile(
              dense: true,
              title: Center(child: LoadingWidget()),
            );
          }

          // 加载更多指示器
          if (index == chapters.length) {
            if (isLoadingMoreChapters) {
              return const ListTile(
                dense: true,
                title: Center(child: LoadingWidget()),
              );
            }
            return const SizedBox.shrink();
          }

          if (index > chapters.length) return null;

          final chapter = chapters[index];
          final isCurrent = chapter.chapterOrder == currentChapter;

          return ListTile(
            dense: true,
            title: Text(
              chapter.title,
              style: TextStyle(
                fontSize: 14,
                color: isCurrent ? colorScheme.primary : null,
                fontWeight: isCurrent ? FontWeight.bold : null,
              ),
            ),
            trailing: isCurrent
                ? Icon(
                    Icons.play_arrow,
                    color: colorScheme.primary,
                    size: 20,
                  )
                : null,
            onTap: () => onJump(chapter.chapterOrder),
          );
        },
        childCount: isLoadingChapters
            ? 1
            : chapters.length + (hasMoreChapters ? 1 : 0),
      ),
    );
  }
}
