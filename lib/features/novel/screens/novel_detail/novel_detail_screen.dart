import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../../../services/chapter_cache_service.dart';
import '../../models/novel_model.dart';
import '../../services/novel_launch_service.dart';
import '../novel_comments/novel_comments_screen.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/event_bus.dart';
import '../../widgets/novel_detail_header.dart';
import '../../widgets/novel_detail_stat_row.dart';
import '../../widgets/novel_detail_actions.dart';
import '../../widgets/novel_detail_description.dart';
import '../../widgets/novel_detail_comment_entry.dart';
import '../../widgets/novel_detail_chapter_header.dart';
import '../../widgets/novel_detail_chapter_list.dart';
import '../../widgets/novel_aggregation_notice.dart';
import '../novel_detail_dialogs.dart';
import '../novel_detail_helpers.dart';

part 'novel_detail_logic_mixin.dart';

/// 小说详情页面
class NovelDetailScreen extends StatefulWidget {
  final NovelModel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen>
    with _NovelDetailLogic {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkBookshelfStatus();
    // 聚合小说无本地章节（novel_chapters 0 行），跳过章节/缓存请求
    if (!widget.novel.isAggregated) {
      _loadChapters();
      _updateCacheStatus();
      _scrollController.addListener(_onScroll);
    } else {
      _isLoadingChapters = false;
      _hasMoreChapters = false;
    }
    _loadUserRating();
  }

  /// 滚动监听：触底加载更多章节
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreChapters();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final novel = widget.novel;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          NovelDetailHeader(novel: novel),
          NovelDetailStatRow(
            novel: novel,
            userRating: _userRating,
            onRateTap: () => showNovelRatingDialog(
              context,
              novelTitle: novel.title,
              onSubmit: _submitRating,
            ),
          ),
          NovelDetailActions(
            isInBookshelf: _isInBookshelf,
            isLoadingShelf: _isLoadingShelf,
            currentChapter: _currentChapter,
            isDownloading: _isDownloading,
            cachedChapterCount: _cachedChapterCount,
            chaptersLength: _chapters.length,
            isCollected: _isCollected,
            onStartReading: _startReading,
            onToggleBookshelf: _toggleBookshelf,
            onDownload: _downloadAllChapters,
            onClear: _clearCache,
            onToggleCollect: _toggleCollect,
            isAggregated: widget.novel.isAggregated,
          ),
          SliverToBoxAdapter(child: NovelAggregationNotice(novel: novel)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          NovelDetailDescription(novel: novel),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          NovelDetailCommentEntry(
            novelId: novel.id,
            novelTitle: novel.title,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NovelCommentsScreen(
                    novelId: novel.id,
                    novelTitle: novel.title,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // 聚合小说不渲染章节区：正文在原平台，本地 novel_chapters 无数据，
          // 渲染只会出现「共 N 章 + 空列表」的语义错位
          if (!novel.isAggregated) ...[
            NovelDetailChapterHeader(
              isLoadingChapters: _isLoadingChapters,
              chapterCount: widget.novel.chapterCount,
              onShowAll: () => showNovelChapterListSheet(
                context,
                loadAllChapters: () => loadAllNovelChapters(widget.novel.id),
                currentChapter: _currentChapter,
                onJump: _jumpToChapter,
                onChaptersLoaded: (chapters) {
                  // 同时更新详情页的 _chapters（避免后续重复加载）
                  if (_chapters.length < chapters.length) {
                    setState(() {
                      _chapters = chapters;
                      _hasMoreChapters = false;
                    });
                  }
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            NovelDetailChapterList(
              chapters: _chapters,
              currentChapter: _currentChapter,
              hasMoreChapters: _hasMoreChapters,
              isLoadingChapters: _isLoadingChapters,
              isLoadingMoreChapters: _isLoadingMoreChapters,
              onJump: _jumpToChapter,
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
