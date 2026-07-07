import 'package:flutter/material.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../core/widgets/widgets.dart';
import '../models/novel_model.dart';
import '../services/ranking_service.dart';
import 'novel_detail_screen.dart';

/// 排行榜页面
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin, PaginatedListMixin {
  late TabController _typeTabController;
  late TabController _timeTabController;

  RankingType _currentType = RankingType.read;
  RankingTimeRange _currentTimeRange = RankingTimeRange.weekly;

  List<RankingItem> _rankings = [];
  bool _isLoading = true;

  final List<RankingType> _types = RankingType.values;
  final List<RankingTimeRange> _timeRanges = RankingTimeRange.values;

  @override
  void initState() {
    super.initState();
    _typeTabController = TabController(length: _types.length, vsync: this);
    _timeTabController = TabController(length: _timeRanges.length, vsync: this);

    _typeTabController.addListener(() {
      if (_typeTabController.indexIsChanging) return;
      setState(() {
        _currentType = _types[_typeTabController.index];
      });
      _loadRankings(refresh: true);
    });

    _timeTabController.addListener(() {
      if (_timeTabController.indexIsChanging) return;
      setState(() {
        _currentTimeRange = _timeRanges[_timeTabController.index];
      });
      _loadRankings(refresh: true);
    });

    initPagination();
    _loadRankings(refresh: true);
  }

  @override
  void dispose() {
    _typeTabController.dispose();
    _timeTabController.dispose();
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadRankings();
  }

  Future<void> _loadRankings({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isLoading = true);
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    final (limit, offset) = paginationParams;

    final result = await RankingService().getRankings(
      type: _currentType,
      timeRange: _currentTimeRange,
      limit: limit,
      offset: offset,
    );

    if (!mounted) return;
    setState(() {
      if (refresh) {
        _rankings = result;
      } else {
        _rankings.addAll(result);
      }
      _isLoading = false;
      onPaginationDataLoaded(result.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              // 榜单类型 Tab
              TabBar(
                controller: _typeTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _types
                    .map((type) => Tab(text: RankingService.getRankingTypeName(type)))
                    .toList(),
              ),
              // 时间维度 Tab
              TabBar(
                controller: _timeTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _timeRanges
                    .map((range) => Tab(text: RankingService.getTimeRangeName(range)))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadRankings(refresh: true),
        child: _isLoading && _rankings.isEmpty
            ? const LoadingWidget()
            : _rankings.isEmpty
                ? const EmptyWidget(message: '暂无榜单数据')
                : _buildRankingList(),
      ),
    );
  }

// _buildEmptyView 已被 EmptyWidget 替换，不再需要

  Widget _buildRankingList() {
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _rankings.length + 1,
      itemBuilder: (context, index) {
        if (index == _rankings.length) {
          return buildLoadMoreIndicator();
        }

        final item = _rankings[index];
        final rank = index + 1;
        final isTop3 = rank <= 3;

        return ListTile(
          leading: SizedBox(
            width: 40,
            child: Center(
              child: _buildRankBadge(rank, isTop3),
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.author ?? '未知作者'} · ${_getHeatText(item)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: item.coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    item.coverUrl!,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 64,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book, size: 24),
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 64,
                  color: Colors.grey[300],
                  child: const Icon(Icons.book, size: 24),
                ),
          onTap: () => _onItemTap(item),
          onLongPress: () => _onItemLongPress(item),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank, bool isTop3) {
    if (isTop3) {
      Color badgeColor;
      switch (rank) {
        case 1:
          badgeColor = const Color(0xFFFFD700); // 金
          break;
        case 2:
          badgeColor = const Color(0xFFC0C0C0); // 银
          break;
        case 3:
          badgeColor = const Color(0xFFCD7F32); // 铜
          break;
        default:
          badgeColor = Colors.grey;
      }

      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: badgeColor.withValues(alpha: 1.0),
            ),
          ),
        ),
      );
    }

    return Text(
      '$rank',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _getHeatText(RankingItem item) {
    switch (_currentType) {
      case RankingType.read:
      case RankingType.newBook:
        return '${item.periodReads}阅读';
      case RankingType.collect:
        return '${item.periodCollects}收藏';
      case RankingType.rating:
      case RankingType.completed:
        return '评分 ${item.avgRating.toStringAsFixed(1)}';
    }
  }

  void _onItemTap(RankingItem item) {
    final novel = NovelModel(
      id: item.novelId,
      title: item.title,
      author: item.author,
      cover: item.coverUrl,
      category: item.category,
      status: item.status,
      rating: item.avgRating,
      readCount: item.totalReads,
      collectCount: item.totalCollects,
      createdAt: item.createdAt ?? DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: novel)),
    );
  }

  void _onItemLongPress(RankingItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('加入书架'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 调用书架服务添加
                showSnackBar(context, '已加入书架');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _onItemTap(item);
              },
            ),
          ],
        ),
      ),
    );
  }
}
