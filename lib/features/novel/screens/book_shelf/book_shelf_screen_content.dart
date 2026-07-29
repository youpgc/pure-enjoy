import 'package:flutter/material.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../widgets/bookshelf_item.dart';
import '../../widgets/bookshelf_login_view.dart';
import '../../widgets/bookshelf_empty_view.dart';
import '../../widgets/bookshelf_filter_bar.dart';

/// {@template book_shelf_screen_content}
/// [BookShelfScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入数据与回调，不持有状态。列表区拆为 [BookShelfListView]。
/// {@endtemplate}
class BookShelfScreenContent extends StatelessWidget {
  /// {@macro book_shelf_screen_content}
  const BookShelfScreenContent({
    super.key,
    required this.userId,
    required this.isLoading,
    required this.bookshelfItems,
    required this.filteredItems,
    required this.filterStatus,
    required this.scrollController,
    required this.loadMoreIndicator,
    required this.getStatusText,
    required this.getStatusColor,
    required this.formatLastRead,
    required this.formatWordCount,
    required this.onRefresh,
    required this.onLogin,
    required this.onOpenLibrary,
    required this.onAddNovel,
    required this.onFilterChanged,
    required this.onContinueReading,
    required this.onOpenDetail,
    required this.onItemLongPress,
  });

  final String? userId;
  final bool isLoading;
  final List<Map<String, dynamic>> bookshelfItems;
  final List<Map<String, dynamic>> filteredItems;
  final String filterStatus;
  final ScrollController scrollController;
  final Widget loadMoreIndicator;
  final String Function(double?) getStatusText;
  final Color Function(double?, ColorScheme) getStatusColor;
  final String Function(String?) formatLastRead;
  final String Function(int?) formatWordCount;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogin;
  final VoidCallback onOpenLibrary;
  final VoidCallback onAddNovel;
  final ValueChanged<String> onFilterChanged;
  final void Function(Map<String, dynamic>) onContinueReading;
  final void Function(Map<String, dynamic>) onOpenDetail;
  final void Function(Map<String, dynamic>) onItemLongPress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          // 进入小说库按钮
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            onPressed: onOpenLibrary,
            tooltip: '小说库',
          ),
          if (userId != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: onAddNovel,
              tooltip: '添加小说',
            ),
        ],
      ),
      body: userId == null
          ? BookshelfLoginView(onLogin: onLogin)
          : isLoading
              ? SkeletonLoading.list(itemCount: 6, showAvatar: false)
              : bookshelfItems.isEmpty
                  ? BookshelfEmptyView(
                      onRefresh: onRefresh,
                      onAdd: onAddNovel,
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: Column(
                        children: [
                          // 状态筛选栏
                          BookshelfFilterBar(
                            items: bookshelfItems,
                            filterStatus: filterStatus,
                            onFilterChanged: onFilterChanged,
                          ),
                          // 书架列表
                          Expanded(
                            child: BookShelfListView(
                              filteredItems: filteredItems,
                              scrollController: scrollController,
                              loadMoreIndicator: loadMoreIndicator,
                              getStatusText: getStatusText,
                              getStatusColor: getStatusColor,
                              formatLastRead: formatLastRead,
                              formatWordCount: formatWordCount,
                              onContinueReading: onContinueReading,
                              onOpenDetail: onOpenDetail,
                              onItemLongPress: onItemLongPress,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

/// 书架列表（RefreshIndicator + ListView.separated）
class BookShelfListView extends StatelessWidget {
  const BookShelfListView({
    super.key,
    required this.filteredItems,
    required this.scrollController,
    required this.loadMoreIndicator,
    required this.getStatusText,
    required this.getStatusColor,
    required this.formatLastRead,
    required this.formatWordCount,
    required this.onContinueReading,
    required this.onOpenDetail,
    required this.onItemLongPress,
  });

  final List<Map<String, dynamic>> filteredItems;
  final ScrollController scrollController;
  final Widget loadMoreIndicator;
  final String Function(double?) getStatusText;
  final Color Function(double?, ColorScheme) getStatusColor;
  final String Function(String?) formatLastRead;
  final String Function(int?) formatWordCount;
  final void Function(Map<String, dynamic>) onContinueReading;
  final void Function(Map<String, dynamic>) onOpenDetail;
  final void Function(Map<String, dynamic>) onItemLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return filteredItems.isEmpty
        ? ListView(
            children: [
              SizedBox(
                height: 300,
                child: Center(
                  child: Text(
                    '该分类下暂无小说',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          )
        : ListView.separated(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredItems.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == filteredItems.length) {
                return loadMoreIndicator;
              }
              final item = filteredItems[index];
              return BookshelfItem(
                item: item,
                colorScheme: colorScheme,
                getStatusText: getStatusText,
                getStatusColor: getStatusColor,
                formatLastRead: formatLastRead,
                formatWordCount: formatWordCount,
                onTap: () => onContinueReading(item),
                onLongPress: () => onItemLongPress(item),
              );
            },
          );
  }
}
