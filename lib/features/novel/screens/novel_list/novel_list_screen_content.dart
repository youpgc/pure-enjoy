import 'package:flutter/material.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../services/dict_service.dart';
import '../../../../constants/app_constants.dart';
import '../../../../widgets/common_widgets.dart';
import '../../models/novel_model.dart';
import '../../widgets/novel_card.dart';
import '../../widgets/continue_reading_card.dart';
import '../../widgets/novel_recommendation_card.dart';

/// {@template novel_list_screen_content}
/// [NovelListScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入数据与回调，不持有状态。各区域拆为独立子组件。
/// {@endtemplate}
class NovelListScreenContent extends StatelessWidget {
  /// {@macro novel_list_screen_content}
  const NovelListScreenContent({
    super.key,
    required this.isFirstLoad,
    required this.isLoading,
    required this.searchQuery,
    required this.novels,
    required this.readingNovels,
    required this.userNovels,
    required this.categories,
    required this.statuses,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.scrollController,
    required this.loadMoreIndicator,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onShowSearchDialog,
    required this.onOpenNovelDetail,
    required this.onAddToBookshelf,
    required this.onOpenRanking,
    required this.onOpenRecommendation,
  });

  final bool isFirstLoad;
  final bool isLoading;
  final String searchQuery;
  final List<NovelModel> novels;
  final List<NovelModel> readingNovels;
  final List<Map<String, dynamic>> userNovels;
  final List<String> categories;
  final List<String> statuses;
  final String selectedCategory;
  final String selectedStatus;
  final ScrollController scrollController;
  final Widget loadMoreIndicator;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onShowSearchDialog;
  final ValueChanged<NovelModel> onOpenNovelDetail;
  final ValueChanged<NovelModel> onAddToBookshelf;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenRecommendation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小说'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: onOpenRanking,
            tooltip: '排行榜',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onShowSearchDialog,
            tooltip: '搜索',
          ),
        ],
      ),
      body: isFirstLoad && isLoading
          ? SkeletonLoading.grid(itemCount: 6, crossAxisCount: 3)
          : Column(
              children: [
                // 切换标签/刷新时保留列表，仅顶部细进度条提示请求中（避免整页骨架闪烁）
                if (isLoading && !isFirstLoad)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 搜索提示
                        if (searchQuery.isNotEmpty)
                          NovelListSearchBar(
                            searchQuery: searchQuery,
                            resultCount: novels.length,
                            onSearchChanged: onSearchChanged,
                            onClearSearch: onClearSearch,
                          ),
                        // 阅读中的小说
                        if (readingNovels.isNotEmpty && searchQuery.isEmpty) ...[
                          const Text('继续阅读',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          NovelContinueReadingSection(
                            readingNovels: readingNovels,
                            onOpenNovelDetail: onOpenNovelDetail,
                          ),
                          const SizedBox(height: 24),
                        ],
                        // 猜你喜欢入口
                        if (searchQuery.isEmpty)
                          NovelRecommendationCard(onTap: onOpenRecommendation),
                        // 分类筛选
                        NovelCategoryFilterBar(
                          categories: categories,
                          selectedCategory: selectedCategory,
                          onCategoryChanged: onCategoryChanged,
                        ),
                        const SizedBox(height: 8),
                        // 状态筛选
                        NovelStatusFilterBar(
                          statuses: statuses,
                          selectedStatus: selectedStatus,
                          onStatusChanged: onStatusChanged,
                        ),
                        const SizedBox(height: 16),
                        // 小说列表标题
                        Text(
                          selectedCategory == 'all'
                              ? '全部小说'
                              : DictService.instance.getLabelOrDefault(
                                  dictNovelCategory,
                                  selectedCategory,
                                  defaultValue: selectedCategory,
                                ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        NovelGridSection(
                          novels: novels,
                          userNovels: userNovels,
                          searchQuery: searchQuery,
                          onOpenNovelDetail: onOpenNovelDetail,
                          onAddToBookshelf: onAddToBookshelf,
                          loadMoreIndicator: loadMoreIndicator,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 搜索提示栏
class NovelListSearchBar extends StatelessWidget {
  const NovelListSearchBar({
    super.key,
    required this.searchQuery,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final String searchQuery;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '搜索: "$searchQuery" ($resultCount 结果)',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClearSearch,
            child: Icon(Icons.close,
                size: 16, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 继续阅读横向列表
class NovelContinueReadingSection extends StatelessWidget {
  const NovelContinueReadingSection({
    super.key,
    required this.readingNovels,
    required this.onOpenNovelDetail,
  });

  final List<NovelModel> readingNovels;
  final ValueChanged<NovelModel> onOpenNovelDetail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // 横向列表需为每项提供有限宽度，否则卡片内的 Expanded/Stack
        // 因父级宽度无限而布局崩溃（A Stack requires bounded constraints）。
        // 高度 180 由 SizedBox 约束；卡片用 ContinueReadingCard，
        // 仅封面 Expanded、信息区自然高度，大字体下也不会垂直溢出。
        itemExtent: 140,
        itemCount: readingNovels.length,
        itemBuilder: (context, index) {
          final novel = readingNovels[index];
          return ContinueReadingCard(
            novel: novel,
            onTap: () => onOpenNovelDetail(novel),
          );
        },
      ),
    );
  }
}

/// 分类筛选横条
class NovelCategoryFilterBar extends StatelessWidget {
  const NovelCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final label = category == 'all'
              ? '全部'
              : DictService.instance.getLabelOrDefault(
                  dictNovelCategory,
                  category,
                  defaultValue: category,
                );
          return CategoryChip(
            label: label,
            isSelected: selectedCategory == category,
            onTap: () => onCategoryChanged(category),
          );
        },
      ),
    );
  }
}

/// 状态筛选横条
class NovelStatusFilterBar extends StatelessWidget {
  const NovelStatusFilterBar({
    super.key,
    required this.statuses,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  final List<String> statuses;
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          final label = status == 'all'
              ? '全部'
              : DictService.instance.getLabelOrDefault(
                  dictNovelStatus,
                  status,
                  defaultValue: status,
                );
          return CategoryChip(
            label: label,
            isSelected: selectedStatus == status,
            onTap: () => onStatusChanged(status),
          );
        },
      ),
    );
  }
}

/// 小说网格（或空态 + 加载更多）
class NovelGridSection extends StatelessWidget {
  const NovelGridSection({
    super.key,
    required this.novels,
    required this.userNovels,
    required this.searchQuery,
    required this.onOpenNovelDetail,
    required this.onAddToBookshelf,
    required this.loadMoreIndicator,
  });

  final List<NovelModel> novels;
  final List<Map<String, dynamic>> userNovels;
  final String searchQuery;
  final ValueChanged<NovelModel> onOpenNovelDetail;
  final ValueChanged<NovelModel> onAddToBookshelf;
  final Widget loadMoreIndicator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (novels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty ? '没有找到匹配的小说' : '暂无小说',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Bug 11 修复：提升到 GridView 外部计算一次，避免每个 item 都重新计算 O(n*m)
    final bookshelfIds =
        userNovels.map((un) => un['novel_id'].toString()).toSet();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: novels.length,
      itemBuilder: (context, index) {
        final novel = novels[index];
        final isInBookshelf = bookshelfIds.contains(novel.id);
        return NovelCard(
          novel: novel,
          onTap: () => onOpenNovelDetail(novel),
          onAddToBookshelf: isInBookshelf ? null : () => onAddToBookshelf(novel),
          isInBookshelf: isInBookshelf,
        );
      },
    );
  }
}
