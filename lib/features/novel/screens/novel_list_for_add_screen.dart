import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../core/widgets/widgets.dart';
import 'novel_search_delegate.dart';
import '../widgets/novel_list_item.dart';

/// 用于从书架添加小说的列表页
/// 从 novels 表查询公共小说列表，支持添加到书架
class NovelListForAddScreen extends StatefulWidget {
  const NovelListForAddScreen({super.key});

  @override
  State<NovelListForAddScreen> createState() => _NovelListForAddScreenState();
}

class _NovelListForAddScreenState extends State<NovelListForAddScreen> with PaginatedListMixin {
  List<Map<String, dynamic>> _novels = [];
  Set<String> _addedNovelIds = {};
  final Set<String> _addingNovelIds = {};
  bool _isLoading = true;
  final String _searchQuery = '';

  String? get _userId => AuthService.instance.currentUserId;

  /// 检查用户认证
  bool _checkAuth() {
    if (!AuthService.instance.isAuthenticated) {
      if (mounted) {
        showSnackBar(context, '请先登录');
      }
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadData();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadData();
  }

  /// 加载公共小说列表和用户已添加的书架数据
  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isLoading = true);
    }

    try {
      final userId = _userId;
      if (userId == null || !_checkAuth()) {
        setState(() => _isLoading = false);
        return;
      }

      if (refresh) {
        resetPagination();
      }
      if (!refresh && !beginLoadMore()) return;

      final (limit, offset) = paginationParams;

      // 并行请求：公共小说列表（分页）+ 用户已添加的书架（全部）
      final novelsFuture = ApiClient.get(
        'novels',
        filters: {'user_id': 'is.null'},
        columns: 'id,title,author,cover_url,category,description,chapter_count,word_count,status',
        order: 'created_at.desc',
        limit: limit,
        offset: offset,
      );
      final shelfFuture = ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$userId',
          'is_collected': 'eq.true',
        },
        columns: 'novel_id',
        limit: 1000,
      );

      final results = await Future.wait([novelsFuture, shelfFuture]);
      final novelsResult = results[0];
      final shelfResult = results[1];

      if (novelsResult.isSuccess) {
        final novelsData = novelsResult.data!;
        setState(() {
          if (refresh) {
            _novels = novelsData.cast<Map<String, dynamic>>();
          } else {
            _novels.addAll(novelsData.cast<Map<String, dynamic>>());
          }
          onPaginationDataLoaded(novelsData.length);
        });
      }

      if (shelfResult.isSuccess) {
        final shelfData = shelfResult.data!;
        setState(() {
          _addedNovelIds = shelfData
              .map((item) => item['novel_id'].toString())
              .toSet();
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '加载小说列表出错: $e');
      }
    }
  }

  /// 添加小说到书架
  Future<void> _addToBookshelf(String novelId) async {
    final userId = _userId;
    if (userId == null || !_checkAuth()) return;

    setState(() => _addingNovelIds.add(novelId));

    try {
      final result = await ApiClient.post(
        'user_novels',
        {
          'user_id': userId,
          'novel_id': novelId,
          'progress': 0,
          'last_chapter': 0,
          'is_collected': true,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (result.isSuccess) {
        setState(() => _addedNovelIds.add(novelId));
        if (mounted) {
          showSnackBar(context, '已添加到书架');
        }
      } else {
        if (mounted) {
          showSnackBar(context, '添加失败: ${result.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '添加出错: $e');
      }
    } finally {
      setState(() => _addingNovelIds.remove(novelId));
    }
  }

  /// 获取搜索过滤后的小说列表
  List<Map<String, dynamic>> get _filteredNovels {
    if (_searchQuery.isEmpty) return _novels;
    final query = _searchQuery.toLowerCase();
    return _novels.where((novel) {
      final title = (novel['title'] as String? ?? '').toLowerCase();
      final author = (novel['author'] as String? ?? '').toLowerCase();
      return title.contains(query) || author.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加小说到书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: NovelSearchDelegate(
                  novels: _novels,
                  addedNovelIds: _addedNovelIds,
                  addingNovelIds: _addingNovelIds,
                  onAdd: _addToBookshelf,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _filteredNovels.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadData(refresh: true),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '暂无可添加的小说',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadData(refresh: true),
                  child: ListView.separated(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filteredNovels.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _filteredNovels.length) {
                        return buildLoadMoreIndicator();
                      }
                      final novel = _filteredNovels[index];
                      final novelId = novel['id'].toString();
                      final isAdded = _addedNovelIds.contains(novelId);
                      final isAdding = _addingNovelIds.contains(novelId);

                      return NovelListItem(
                        novel: novel,
                        colorScheme: colorScheme,
                        isAdded: isAdded,
                        isAdding: isAdding,
                        onAdd: () => _addToBookshelf(novelId),
                      );
                    },
                  ),
                ),
    );
  }
}
