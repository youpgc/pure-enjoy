import 'package:flutter/material.dart';

/// 通用分页列表 Mixin
/// 封装分页状态管理和 ScrollController 触底自动加载逻辑
///
/// 使用方式：
/// 1. 在 State 类中 with PaginatedListMixin
/// 2. 在 initState 中调用 initPagination()
/// 3. 在 dispose 中调用 disposePagination()
/// 4. 在数据加载方法中使用 paginationParams 获取 limit/offset
/// 5. 在数据加载完成后调用 onPaginationDataLoaded(newDataCount)
/// 6. 在下拉刷新时调用 resetPagination() + 重新加载
mixin PaginatedListMixin<T extends StatefulWidget> on State<T> {
  /// 每页数据量
  int get pageSize => 10;

  /// 触底加载的阈值（距离底部多少像素时触发）
  double get loadMoreThreshold => 200;

  ScrollController? _scrollController;

  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  /// ScrollController，用于绑定到 ListView/GridView
  ScrollController get scrollController {
    _scrollController ??= ScrollController();
    return _scrollController!;
  }

  /// 当前是否正在加载更多
  bool get isLoadingMore => _isLoadingMore;

  /// 是否还有更多数据
  bool get hasMore => _hasMore;

  /// 初始化分页（在 initState 中调用）
  void initPagination() {
    scrollController.addListener(_onScroll);
  }

  /// 释放分页资源（在 dispose 中调用）
  void disposePagination() {
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _scrollController = null;
  }

  /// 重置分页状态（下拉刷新时调用）
  void resetPagination() {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
  }

  /// 获取当前分页参数
  /// 返回 (limit, offset)
  (int, int) get paginationParams {
    return (pageSize, (_currentPage - 1) * pageSize);
  }

  /// 数据加载完成后调用
  /// [newDataCount] 本次加载的数据条数
  void onPaginationDataLoaded(int newDataCount) {
    _isLoadingMore = false;
    if (newDataCount < pageSize) {
      _hasMore = false;
    }
  }

  /// 开始加载更多前调用（返回 false 表示无需加载）
  bool beginLoadMore() {
    if (_isLoadingMore || !_hasMore) return false;
    _isLoadingMore = true;
    _currentPage++;
    return true;
  }

  /// 滚动监听 - 触底自动加载
  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    if (_isLoadingMore || !_hasMore) return;

    final maxScroll = _scrollController!.position.maxScrollExtent;
    final currentScroll = _scrollController!.position.pixels;

    if (maxScroll - currentScroll <= loadMoreThreshold) {
      _onLoadMore();
    }
  }

  /// 子类实现：触底加载更多数据
  void _onLoadMore();

  /// 构建加载更多指示器
  Widget buildLoadMoreIndicator() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '没有更多了',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
