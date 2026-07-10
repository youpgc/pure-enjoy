import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../reader_enums.dart';
import '../../../../core/widgets/widgets.dart';

/// 小说阅读器目录抽屉组件
/// 支持下拉刷新和触底加载的无限滚动列表
class ReaderChapterDrawer extends StatefulWidget {
  final List<NovelChapterModel> chapters;
  final int currentChapterIndex;
  final ReaderBackground background;
  final int totalChapterCount;
  final bool hasMoreChapters;
  final bool isLoadingMore;
  final void Function(int globalIndex, NovelChapterModel chapter) onChapterTap;
  final VoidCallback? onCloseDrawer;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onRefresh;

  const ReaderChapterDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.background,
    required this.totalChapterCount,
    this.hasMoreChapters = false,
    this.isLoadingMore = false,
    required this.onChapterTap,
    this.onCloseDrawer,
    this.onLoadMore,
    this.onRefresh,
  });

  @override
  State<ReaderChapterDrawer> createState() => _ReaderChapterDrawerState();
}

class _ReaderChapterDrawerState extends State<ReaderChapterDrawer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.isLoadingMore) return;
    if (!widget.hasMoreChapters) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // 距离底部 200px 时触发加载更多
    if (maxScroll > 0 && currentScroll >= maxScroll - 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return Drawer(child: Center(child: LoadingWidget()));
    }

    final displayCount = widget.totalChapterCount > 0
        ? widget.totalChapterCount
        : widget.chapters.length;

    Widget listContent = ListView.builder(
      controller: _scrollController,
      itemCount: widget.chapters.length + (widget.hasMoreChapters ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载指示器
        if (index >= widget.chapters.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: widget.isLoadingMore
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.background.textColor.withValues(alpha: 0.5),
                      ),
                    )
                  : Text(
                      '上拉加载更多',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.background.textColor.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          );
        }

        final chapter = widget.chapters[index];
        final isCurrent = index == widget.currentChapterIndex;
        return ListTile(
          dense: true,
          title: Text(
            chapter.title,
            style: TextStyle(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : widget.background.textColor,
              fontWeight: isCurrent ? FontWeight.bold : null,
            ),
          ),
          trailing: isCurrent
              ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            widget.onCloseDrawer?.call();
            widget.onChapterTap(index, chapter);
          },
        );
      },
    );

    // 包装下拉刷新
    if (widget.onRefresh != null) {
      listContent = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: listContent,
      );
    }

    return Drawer(
      backgroundColor: widget.background.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '目录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.background.textColor,
                      ),
                    ),
                  ),
                  Text(
                    '共 $displayCount 章',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.background.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: listContent),
          ],
        ),
      ),
    );
  }
}
