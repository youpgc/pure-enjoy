import 'package:flutter/material.dart';

/// 通用分页列表 Mixin
/// 封装分页状态管理和 ScrollController 触底自动加载逻辑
///
/// 使用方式：
/// 1. 在 State 类中 with PaginatedListMixin
/// 2. 在 initState 中调用 initPagination()
/// 3. 在 dispose 中调用 disposePagination()
/// 4. 首载/刷新：beginReset() 占位 → 成功 resetPagination() 归位、
///    onPaginationDataLoaded() 记账；失败 cancelLoadMore(revertPage:false)
/// 5. 触底加载：beginLoadMore() 占位并自增页码 → 成功 onPaginationDataLoaded()、
///    失败 cancelLoadMore() 回退页码；用 paginationParams 取 limit/offset
/// 6. 远端从未成功（本地兜底态）时触底直接 return，仅下拉刷新重试
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

  /// 首载/下拉刷新：占用加载锁但不推进页码。
  /// 成功后再调用 [resetPagination] 归位，失败用 [cancelLoadMore] 且 revertPage=false。
  bool beginReset() {
    if (_isLoadingMore) return false;
    _isLoadingMore = true;
    return true;
  }

  /// 加载失败时释放 [beginLoadMore] 的页码自增与加载锁。
  /// [revertPage] 仅触底加载需要回退页码；首载/刷新失败保持原页码。
  void cancelLoadMore({bool revertPage = true}) {
    if (revertPage && _isLoadingMore && _currentPage > 1) _currentPage--;
    _isLoadingMore = false;
  }

  /// 滚动监听 - 触底自动加载
  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    if (_isLoadingMore || !_hasMore) return;

    final maxScroll = _scrollController!.position.maxScrollExtent;
    final currentScroll = _scrollController!.position.pixels;

    if (maxScroll - currentScroll <= loadMoreThreshold) {
      onLoadMore();
    }
  }

  /// 子类实现：触底加载更多数据
  void onLoadMore();

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
