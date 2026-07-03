import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/cache_helper.dart';
import '../../../utils/format_utils.dart';
import '../../../widgets/common_widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../models/novel_model.dart';
import '../../../constants/app_constants.dart';
import 'novel_detail_screen.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// 小说列表页面
class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> with PaginatedListMixin {
  List<NovelModel> _novels = [];
  List<NovelModel> _allNovels = [];
  List<Map<String, dynamic>> _userNovels = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// 分类列表（从字典服务获取）
  List<String> get _categories {
    final items = DictService.instance.getItemsSync(dictNovelCategory);
    return ['all', ...items.map((item) => item.code)];
  }

  /// 状态列表
  List<String> get _statuses => ['all', novelStatusOngoing, novelStatusCompleted];

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    initPagination();
    _initLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    disposePagination();
    super.dispose();
  }

  /// 初始化加载：先确保字典加载完成，再读缓存，最后静默刷新
  Future<void> _initLoad() async {
    try {
      await DictService.instance.initialize();
      await _loadCache();
      await _loadNovels(refresh: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ NovelListScreen _initLoad 异常');
        debugPrint('堆栈信息');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, '初始化失败: $e');
      }
    }
  }

  @override
  void onLoadMore() {
    _loadNovels();
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyNovelList);
    if (cached.isNotEmpty && mounted) {
      final novels = cached.map((json) => NovelModel.fromJson(json)).toList();
      setState(() {
        _allNovels = novels;
        _novels = novels;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNovels({bool refresh = false}) async {
    try {
      if (refresh) {
        resetPagination();
        setState(() => _isLoading = true);
      }
      if (!refresh && !beginLoadMore()) return;

      final userId = _userId;

      // 构建服务端过滤条件
      final filters = <String, String>{
        'user_id': 'is.null',
      };
      if (_selectedCategory != 'all') {
        filters['category'] = 'eq.$_selectedCategory';
      }
      if (_selectedStatus != 'all') {
        filters['status'] = 'eq.$_selectedStatus';
      }

      // 获取分页参数
      final (limit, offset) = paginationParams;

      // 并行加载 novels 和 user_novels
      final novelsFuture = ApiClient.get(
        'novels',
        filters: filters,
        order: 'created_at.desc',
        limit: limit,
        offset: offset,
      );

      final shelfFuture = userId != null
          ? ApiClient.get(
              'user_novels',
              filters: {'user_id': 'eq.$userId'},
              columns: 'id,novel_id,is_collected,last_chapter,last_read_at,progress',
              limit: 200,
            )
          : Future.value(ApiResponse.success([]));

      final results = await Future.wait([novelsFuture, shelfFuture]);
      final novelsResult = results[0];
      final shelfResult = results[1];

      List<NovelModel> novels = [];
      if (novelsResult.isSuccess) {
        final data = novelsResult.data!;
        novels = data.map((json) => NovelModel.fromJson(json)).toList();
      }

      List<Map<String, dynamic>> userNovels = [];
      if (shelfResult.isSuccess) {
        userNovels = shelfResult.data!.cast<Map<String, dynamic>>();
      }

      setState(() {
        if (refresh) {
          _allNovels = novels;
          _novels = novels;
        } else {
          _allNovels.addAll(novels);
          _novels.addAll(novels);
        }
        _userNovels = userNovels;
        _isLoading = false;
        onPaginationDataLoaded(novels.length);
      });

      // 只在 refresh 时写入缓存
      if (refresh) {
        await CacheHelper.instance.saveList(
          CacheHelper.keyNovelList,
          novels.map((n) => n.toJson()).toList(),
        );
      }
    } catch (e) {
      if (!refresh) {
        onPaginationDataLoaded(0); // Bug 12 修复：释放分页锁，防止加载更多失败后卡死
      }
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '加载失败: $e');
      }
    }
  }

  /// 切换分类
  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
    _loadNovels(refresh: true);
  }

  /// 切换状态
  void _onStatusChanged(String status) {
    setState(() => _selectedStatus = status);
    _loadNovels(refresh: true);
  }

  /// 搜索
  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    // 搜索保持本地筛选，因为服务端 ilike 搜索需要额外支持
    if (_searchQuery.isEmpty) {
      _loadNovels(refresh: true);
    } else {
      setState(() {
        _novels = _allNovels.where((n) {
          final q = _searchQuery.toLowerCase();
          return n.title.toLowerCase().contains(q) ||
              (n.author?.toLowerCase().contains(q) ?? false);
        }).toList();
      });
    }
  }

  /// 添加到书架
  Future<void> _addToBookshelf(NovelModel novel) async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        showSnackBar(context, '请先登录');
      }
      return;
    }

    try {
      final result = await ApiClient.post(
        'user_novels',
        {
          'user_id': userId,
          'novel_id': novel.id,
          'progress': 0,
          'last_chapter': 0,
          'is_collected': true,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (result.isSuccess) {
        await _loadNovels(refresh: true);
        if (mounted) {
          showSnackBar(context, '已添加到书架');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '添加失败: $e');
      }
    }
  }

  /// 打开小说详情页
  void _openNovelDetail(NovelModel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    ).then((_) {
      // Bug 10 修复：从详情页返回后刷新数据，更新书架状态
      if (mounted) _loadNovels(refresh: true);
    });
  }

  /// 获取正在阅读的小说（只显示在读的：progress > 0 且 progress < 1，且章节数 > 0）
  List<NovelModel> get _readingNovels {
    final readingNovelIds = _userNovels.where((un) {
      final progress = (un['progress'] as num?)?.toDouble() ?? 0.0;
      return progress > 0 && progress < 1;
    }).map((un) => un['novel_id'].toString()).toSet();
    return _allNovels
        .where((n) => readingNovelIds.contains(n.id) && n.chapterCount > 0)
        .toList();
  }

  /// 显示搜索对话框
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索小说'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入小说名或作者名',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('小说'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: '搜索',
          ),
        ],
      ),
      body: _isLoading
          ? SkeletonLoading.grid(itemCount: 6, crossAxisCount: 3)
          : RefreshIndicator(
              onRefresh: () => _loadNovels(refresh: true),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // 搜索提示
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '搜索: "$_searchQuery" (${_novels.length} 结果)',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),

                  // 阅读中的小说
                  if (_readingNovels.isNotEmpty && _searchQuery.isEmpty) ...[
                    Text(
                      '继续阅读',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _readingNovels.length,
                        itemBuilder: (context, index) {
                          final novel = _readingNovels[index];
                          return _NovelCard(
                            novel: novel,
                            onTap: () => _openNovelDetail(novel),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 分类筛选
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final label = category == 'all'
                            ? '全部'
                            : DictService.instance.getLabelOrDefault(
                                dictNovelCategory,
                                category,
                                defaultValue: category,
                              );
                        return CategoryChip(
                          label: label,
                          isSelected: _selectedCategory == category,
                          onTap: () => _onCategoryChanged(category),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 状态筛选
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _statuses.length,
                      itemBuilder: (context, index) {
                        final status = _statuses[index];
                        final label = status == 'all'
                            ? '全部'
                            : DictService.instance.getLabelOrDefault(
                                dictNovelStatus,
                                status,
                                defaultValue: status,
                              );
                        return CategoryChip(
                          label: label,
                          isSelected: _selectedStatus == status,
                          onTap: () => _onStatusChanged(status),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 小说列表
                  Text(
                    _selectedCategory == 'all' ? '全部小说' : DictService.instance.getLabelOrDefault(
                        dictNovelCategory,
                        _selectedCategory,
                        defaultValue: _selectedCategory,
                      ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _novels.isEmpty
                      ? Center(
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
                                  _searchQuery.isNotEmpty ? '没有找到匹配的小说' : '暂无小说',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            // Bug 11 修复：提升到 GridView 外部计算一次，避免每个 item 都重新计算 O(n*m)
                            final bookshelfIds = _userNovels.map((un) => un['novel_id'].toString()).toSet();
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _novels.length,
                              itemBuilder: (context, index) {
                                final novel = _novels[index];
                                final isInBookshelf = bookshelfIds.contains(novel.id);
                                return _NovelCard(
                                  novel: novel,
                                  onTap: () => _openNovelDetail(novel),
                                  onAddToBookshelf: isInBookshelf ? null : () => _addToBookshelf(novel),
                                  isInBookshelf: isInBookshelf,
                                );
                              },
                            );
                          },
                        ),
                  buildLoadMoreIndicator(),
                ],
              ),
            ),
    );
  }
}

class _NovelCard extends StatelessWidget {
  final NovelModel novel;
  final VoidCallback onTap;
  final VoidCallback? onAddToBookshelf;
  final bool isInBookshelf;

  const _NovelCard({
    required this.novel,
    required this.onTap,
    this.onAddToBookshelf,
    this.isInBookshelf = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHighest,
                    child: novel.cover != null
                        ? Image.network(
                            novel.cover!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.book,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.book,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (onAddToBookshelf != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: onAddToBookshelf,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isInBookshelf)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已加入',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 信息
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author ?? '佚名',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (novel.category != null)
                          Text(
                            DictService.instance.getLabelOrDefault(
                              dictNovelCategory,
                              novel.category!,
                              defaultValue: novel.category!,
                            ),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          )
                        else
                          Text(
                            '${novel.chapterCount} 章',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        if (novel.wordCount != null && novel.wordCount! > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '·',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            FormatUtils.formatWordCount(novel.wordCount!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
