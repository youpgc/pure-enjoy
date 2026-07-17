import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import '../widgets/reader/reader_widgets.dart';
import '../widgets/reader_enums.dart';

/// 章节目录抽屉
class ReaderChapterDrawerWidget extends StatelessWidget {
  final List<NovelChapterModel> chapters;
  final int currentChapterIndex;
  final ReaderBackground background;
  final int totalChapterCount;
  final bool hasMoreChapters;
  final bool isLoadingMore;
  final VoidCallback onCloseDrawer;
  final void Function(int, NovelChapterModel) onChapterTap;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;

  const ReaderChapterDrawerWidget({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.background,
    required this.totalChapterCount,
    required this.hasMoreChapters,
    required this.isLoadingMore,
    required this.onCloseDrawer,
    required this.onChapterTap,
    required this.onLoadMore,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ReaderChapterDrawer(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
      background: background,
      totalChapterCount: totalChapterCount,
      hasMoreChapters: hasMoreChapters,
      isLoadingMore: isLoadingMore,
      onCloseDrawer: onCloseDrawer,
      onChapterTap: onChapterTap,
      onLoadMore: onLoadMore,
      onRefresh: onRefresh,
    );
  }
}
