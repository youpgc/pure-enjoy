import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../utils/format_utils.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';
import 'novel_detail_screen.dart';
import 'novel_list_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/widgets/widgets.dart';

/// 书架页面 - 显示用户已加入书架的小说列表
class BookShelfScreen extends StatefulWidget {
  const BookShelfScreen({super.key});

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen> with PaginatedListMixin {
  List<Map<String, dynamic>> _bookshelfItems = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, reading, completed

  String? get _userId => AuthService.instance.currentUserId;

  /// 检查用户是否已登录，未登录则提示
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
    _initLoad();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void _onLoadMore() {
    _loadBookshelf();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    try {
      await _loadCache();
      await _loadBookshelf(refresh: true);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ BookShelfScreen _initLoad 异常: ');
        debugPrint('堆栈信息: ');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, '初始化失败: $e');
      }
    }
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyBookshelf);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _bookshelfItems = cached.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    }
  }

  /// 从 Supabase 加载书架数据（嵌套查询：通过外键一次获取 user_novels + novels）
  Future<void> _loadBookshelf({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (!_checkAuth()) {
      setState(() => _isLoading = false);
      return;
    }

    if (refresh) {
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    try {
      final (limit, offset) = paginationParams;

      // 嵌套查询：一次请求获取 user_novels + novels 详情（需要 FK: user_novels.novel_id → novels.id）
      final result = await ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$userId',
          'is_collected': 'eq.true',
        },
        columns: 'id,novel_id,progress,last_chapter,last_read_at,is_collected,novels(id,title,author,cover_url,category,status,chapter_count,word_count,description)',
        order: 'last_read_at.desc.nullslast',
        limit: limit,
        offset: offset,
      );

      if (!result.isSuccess) {
        if (mounted) {
          showSnackBar(context, '加载书架失败: ${result.statusCode}');
        }
        return;
      }

      final data = result.data!;
      if (data.isEmpty) {
        setState(() {
          _bookshelfItems = [];
          _isLoading = false;
        });
        await CacheHelper.instance.saveList(CacheHelper.keyBookshelf, []);
        return;
      }

      // 嵌套查询返回的数据中 novels 字段已包含小说详情
      final bookshelfItems = data.map((item) {
        return {
          'id': item['id'],
          'novel_id': item['novel_id'],
          'progress': item['progress'],
          'last_chapter': item['last_chapter'],
          'last_read_at': item['last_read_at'],
          'is_collected': item['is_collected'],
          'novels': item['novels'],
        };
      }).toList();

      setState(() {
        if (refresh) {
          _bookshelfItems = bookshelfItems.cast<Map<String, dynamic>>();
        } else {
          _bookshelfItems.addAll(bookshelfItems.cast<Map<String, dynamic>>());
        }
        _isLoading = false;
      });
      onPaginationDataLoaded(data.length);

      // 写入缓存（仅在刷新时）
      if (refresh) {
        await CacheHelper.instance.saveList(CacheHelper.keyBookshelf, bookshelfItems);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '加载书架出错: $e');
      }
    }
  }

  /// 从书架移除小说
  Future<void> _removeFromBookshelf(String userNovelId) async {
    if (!_checkAuth()) return;

    try {
      final result = await ApiClient.batchDeleteByFilter(
        'user_novels',
        filters: {'id': 'eq.$userNovelId'},
      );

      if (result.isSuccess) {
        await _loadBookshelf(refresh: true);
        if (mounted) {
          showSnackBar(context, '已从书架移除');
        }
      } else {
        if (mounted) {
          showSnackBar(context, '移除失败: ${result.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '移除出错: $e');
      }
    }
  }

  /// 更新阅读状态（通过更新 progress 来标记状态，数据库无 reading_status 列）
  Future<void> _updateReadingStatus(String userNovelId, String status) async {
    if (!_checkAuth()) return;

    try {
      // 根据状态计算对应的 progress 值
      double progressValue;
      switch (status) {
        case 'reading':
          progressValue = 0.01; // 标记为已开始阅读
          break;
        case 'completed':
          progressValue = 1.0; // 标记为已读完
          break;
        default:
          progressValue = 0.0;
      }

      final result = await ApiClient.patchByFilter(
        'user_novels',
        filters: {'id': 'eq.$userNovelId'},
        body: {
          'progress': progressValue,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (result.isSuccess) {
        await _loadBookshelf(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '更新状态失败: $e');
      }
    }
  }

  /// 根据 progress 计算阅读状态
  String _getReadingStatus(double? progress) {
    if (progress == null || progress == 0) return 'unread';
    if (progress >= 1) return 'completed';
    return 'reading';
  }

  /// 获取筛选后的列表
  List<Map<String, dynamic>> get _filteredItems {
    if (_filterStatus == 'all') return _bookshelfItems;
    return _bookshelfItems.where((item) {
      final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
      final status = _getReadingStatus(progress);
      return status == _filterStatus;
    }).toList();
  }

  /// 获取状态显示文本
  String _getStatusText(double? progress) {
    final status = _getReadingStatus(progress);
    switch (status) {
      case 'reading':
        return '在读';
      case 'completed':
        return '已读完';
      case 'unread':
        return '未读';
      default:
        return '未读';
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(double? progress, ColorScheme colorScheme) {
    final status = _getReadingStatus(progress);
    switch (status) {
      case 'reading':
        return colorScheme.primary;
      case 'completed':
        return AppTheme.success;
      case 'unread':
        return Theme.of(context).colorScheme.secondary;
      default:
        return colorScheme.primary;
    }
  }

  /// 继续阅读 - 跳转到上次阅读的章节
  void _continueReading(Map<String, dynamic> item) {
    final novelData = item['novels'] as Map<String, dynamic>?;
    if (novelData == null) return;

    final novel = _parseNovel(novelData);
    final lastChapter = item['last_chapter'] as int? ?? 1;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novel: novel,
          startChapter: lastChapter,
        ),
      ),
    );
  }

  /// 打开小说详情
  void _openNovelDetail(Map<String, dynamic> item) {
    final novelData = item['novels'] as Map<String, dynamic>?;
    if (novelData == null) return;

    final novel = _parseNovel(novelData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    );
  }

  /// 解析小说数据
  NovelModel _parseNovel(Map<String, dynamic> novelData) {
    return NovelModel(
      id: novelData['id'] as String? ?? '',
      title: novelData['title'] as String? ?? '',
      author: novelData['author'] as String?,
      cover: novelData['cover_url'] as String?,
      category: novelData['category'] as String?,
      status: novelData['status'] as String?,
      chapterCount: novelData['chapter_count'] as int? ?? 0,
      wordCount: novelData['word_count'] as int?,
      description: novelData['description'] as String?,
      createdAt: DateTime.now(),
    );
  }

  /// 显示操作底部弹窗
  void _showActionBottomSheet(BuildContext context, Map<String, dynamic> item) {
    final userNovelId = item['id'].toString();
    final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
    final currentStatus = _getReadingStatus(progress);
    final lastChapter = item['last_chapter'] as int? ?? 1;
    final novelData = item['novels'] as Map<String, dynamic>?;
    final chapterCount = novelData?['chapter_count'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 继续阅读
            ListTile(
              leading: Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('继续阅读'),
              subtitle: Text('第 $lastChapter / $chapterCount 章'),
              onTap: () {
                Navigator.pop(context);
                _continueReading(item);
              },
            ),
            // 查看详情
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _openNovelDetail(item);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '更改阅读状态',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories),
              title: const Text('在读'),
              trailing: currentStatus == 'reading'
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (currentStatus != 'reading') {
                  _updateReadingStatus(userNovelId, 'reading');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('已读完'),
              trailing: currentStatus == 'completed'
                  ? Icon(Icons.check, color: AppTheme.success)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (currentStatus != 'completed') {
                  _updateReadingStatus(userNovelId, 'completed');
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('移出书架', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmRemove(userNovelId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 确认移出书架
  void _confirmRemove(String userNovelId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移除'),
        content: const Text('确定要将这本小说从书架移除吗？阅读进度将不会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromBookshelf(userNovelId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  /// 格式化最后阅读时间
  String _formatLastRead(String? lastReadAt) {
    if (lastReadAt == null) return '';
    try {
      final dateTime = DateTime.parse(lastReadAt);
      final now = DateTime.now().toUtc();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return DateTimeUtils.formatStandard(dateTime);
    } catch (e) {
      return '';
    }
  }

  /// 格式化字数
  String _formatWordCount(int? wordCount) {
    if (wordCount == null || wordCount == 0) return '未知';
    return '${FormatUtils.formatWordCount(wordCount)}字';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          // 进入小说库按钮
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NovelListScreen()),
              );
            },
            tooltip: '小说库',
          ),
          if (_userId != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // 跳转到小说列表页面
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _NovelListForAddScreen()),
                ).then((_) {
                  if (mounted) _loadBookshelf(refresh: true);
                });
              },
              tooltip: '添加小说',
            ),
        ],
      ),
      body: _userId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '请先登录后查看书架',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      // 返回到登录页
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text('去登录'),
                  ),
                ],
              ),
            )
          : _isLoading
              ? SkeletonLoading.list(itemCount: 6, showAvatar: false)
              : _bookshelfItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '书架空空如也',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '去小说列表添加你喜欢的小说吧',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const _NovelListForAddScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('去添加'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadBookshelf(refresh: true),
                      child: Column(
                        children: [
                          // 状态筛选栏
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: SizedBox(
                              height: 48,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                children: [
                                  _FilterChip(
                                    label: '全部',
                                    count: _bookshelfItems.length,
                                    isSelected: _filterStatus == 'all',
                                    onTap: () =>
                                        setState(() => _filterStatus = 'all'),
                                  ),
                                  _FilterChip(
                                    label: '在读',
                                    count: _bookshelfItems.where((i) {
                                      final p = (i['progress'] as num?)?.toDouble() ?? 0.0;
                                      return p > 0 && p < 1;
                                    }).length,
                                    isSelected: _filterStatus == 'reading',
                                    onTap: () => setState(
                                        () => _filterStatus = 'reading'),
                                  ),
                                  _FilterChip(
                                    label: '已读完',
                                    count: _bookshelfItems.where((i) {
                                      final p = (i['progress'] as num?)?.toDouble() ?? 0.0;
                                      return p >= 1;
                                    }).length,
                                    isSelected: _filterStatus == 'completed',
                                    onTap: () => setState(
                                        () => _filterStatus = 'completed'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 书架列表
                          Expanded(
                            child: _filteredItems.isEmpty
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
                                    itemCount: _filteredItems.length + 1,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      if (index == _filteredItems.length) {
                                        return buildLoadMoreIndicator();
                                      }
                                      final item = _filteredItems[index];
                                      return _BookshelfItem(
                                        item: item,
                                        colorScheme: colorScheme,
                                        getStatusText: _getStatusText,
                                        getStatusColor: _getStatusColor,
                                        formatLastRead: _formatLastRead,
                                        formatWordCount: _formatWordCount,
                                        onTap: () => _continueReading(item),
                                        onLongPress: () =>
                                            _showActionBottomSheet(context, item),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

/// 用于从书架添加小说的列表页
/// 从 novels 表查询公共小说列表，支持添加到书架
class _NovelListForAddScreen extends StatefulWidget {
  const _NovelListForAddScreen();

  @override
  State<_NovelListForAddScreen> createState() => _NovelListForAddScreenState();
}

class _NovelListForAddScreenState extends State<_NovelListForAddScreen> {
  List<Map<String, dynamic>> _novels = [];
  Set<String> _addedNovelIds = {};
  Set<String> _addingNovelIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

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
    _loadData();
  }

  /// 加载公共小说列表和用户已添加的书架数据
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _userId;
      if (userId == null || !_checkAuth()) {
        setState(() => _isLoading = false);
        return;
      }

      // 并行请求：公共小说列表 + 用户已添加的书架
      final novelsFuture = ApiClient.get(
        'novels',
        filters: {'user_id': 'is.null'},
        columns: 'id,title,author,cover_url,category,description,chapter_count,word_count,status',
        order: 'created_at.desc',
        limit: 200,
      );
      final shelfFuture = ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$userId',
          'is_collected': 'eq.true',
        },
        columns: 'novel_id',
        limit: 200,
      );

      final results = await Future.wait([novelsFuture, shelfFuture]);
      final novelsResult = results[0];
      final shelfResult = results[1];

      if (novelsResult.isSuccess) {
        final novelsData = novelsResult.data!;
        setState(() {
          _novels = novelsData.cast<Map<String, dynamic>>();
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
                delegate: _NovelSearchDelegate(
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
          ? Center(child: LoadingWidget())
          : _filteredNovels.isEmpty
              ? Center(
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
                )
              : ListView.separated(
                  itemCount: _filteredNovels.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final novel = _filteredNovels[index];
                    final novelId = novel['id'].toString();
                    final isAdded = _addedNovelIds.contains(novelId);
                    final isAdding = _addingNovelIds.contains(novelId);

                    return _NovelListItem(
                      novel: novel,
                      colorScheme: colorScheme,
                      isAdded: isAdded,
                      isAdding: isAdding,
                      onAdd: () => _addToBookshelf(novelId),
                    );
                  },
                ),
    );
  }
}

/// 小说列表项组件
class _NovelListItem extends StatelessWidget {
  final Map<String, dynamic> novel;
  final ColorScheme colorScheme;
  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  const _NovelListItem({
    required this.novel,
    required this.colorScheme,
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final title = novel['title'] as String? ?? '未知';
    final author = novel['author'] as String? ?? '佚名';
    final coverUrl = novel['cover_url'] as String?;
    final description = novel['description'] as String?;
    final chapterCount = novel['chapter_count'] as int? ?? 0;
    final wordCount = novel['word_count'] as int?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 64,
              height: 88,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.book,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.book,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (chapterCount > 0)
                      Text(
                        '$chapterCount章',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (wordCount != null && wordCount > 0) ...[
                      if (chapterCount > 0) const SizedBox(width: 8),
                      Text(
                        wordCount >= 10000
                            ? '${(wordCount / 10000).toStringAsFixed(1)}万字'
                            : '$wordCount字',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 添加按钮
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 64,
              height: 32,
              child: isAdded
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: FittedBox(
                        child: Text(
                          '已添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : isAdding
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: LoadingWidget(size: 18),
                          ),
                        )
                      : FilledButton(
                          onPressed: onAdd,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          child: const FittedBox(
                            child: Text(
                              '添加',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 小说搜索代理
class _NovelSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> novels;
  final Set<String> addedNovelIds;
  final Set<String> addingNovelIds;
  final Future<void> Function(String) onAdd;

  _NovelSearchDelegate({
    required this.novels,
    required this.addedNovelIds,
    required this.addingNovelIds,
    required this.onAdd,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          close(context, '');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('输入小说名称或作者搜索'));
    }

    final searchQuery = query.toLowerCase();
    final results = novels.where((novel) {
      final title = (novel['title'] as String? ?? '').toLowerCase();
      final author = (novel['author'] as String? ?? '').toLowerCase();
      return title.contains(searchQuery) || author.contains(searchQuery);
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('未找到相关小说'));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final novel = results[index];
        final novelId = novel['id'].toString();
        final isAdded = addedNovelIds.contains(novelId);
        final isAdding = addingNovelIds.contains(novelId);

        return _NovelListItem(
          novel: novel,
          colorScheme: colorScheme,
          isAdded: isAdded,
          isAdding: isAdding,
          onAdd: () {
            onAdd(novelId);
            // 刷新搜索结果以更新状态
            showSearch(
              context: context,
              delegate: _NovelSearchDelegate(
                novels: novels,
                addedNovelIds: addedNovelIds,
                addingNovelIds: addingNovelIds,
                onAdd: onAdd,
              ),
            );
          },
        );
      },
    );
  }
}

/// 书架列表项
class _BookshelfItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final ColorScheme colorScheme;
  final String Function(double?) getStatusText;
  final Color Function(double?, ColorScheme) getStatusColor;
  final String Function(String?) formatLastRead;
  final String Function(int?) formatWordCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookshelfItem({
    required this.item,
    required this.colorScheme,
    required this.getStatusText,
    required this.getStatusColor,
    required this.formatLastRead,
    required this.formatWordCount,
    required this.onTap,
    required this.onLongPress,
  });

  /// 根据 progress 计算阅读状态
  String _getReadingStatus(double? progress) {
    if (progress == null || progress == 0) return 'unread';
    if (progress >= 1) return 'completed';
    return 'reading';
  }

  @override
  Widget build(BuildContext context) {
    final novelData = item['novels'] as Map<String, dynamic>?;
    final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
    final status = _getReadingStatus(progress);
    final lastChapter = item['last_chapter'] as int? ?? 0;
    final lastReadAt = item['last_read_at'] as String?;

    if (novelData == null) return const SizedBox.shrink();

    final title = novelData['title'] as String? ?? '未知';
    final author = novelData['author'] as String? ?? '佚名';
    final coverUrl = novelData['cover_url'] as String?;
    final chapterCount = novelData['chapter_count'] as int? ?? 0;
    final wordCount = novelData['word_count'] as int?;
    final category = novelData['category'] as String?;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 76,
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.book,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.book,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                      ),
                      if (category != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: getStatusColor(progress, colorScheme)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          getStatusText(progress),
                          style: TextStyle(
                            fontSize: 11,
                            color: getStatusColor(progress, colorScheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 阅读进度
                      Expanded(
                        child: Text(
                          chapterCount == 0
                              ? '读到第 $lastChapter 章（共0章）'
                              : '读到第 $lastChapter / $chapterCount 章',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (lastReadAt != null || wordCount != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (lastReadAt != null) ...[
                          Text(
                            '上次阅读: ${formatLastRead(lastReadAt)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                          ),
                          if (wordCount != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              formatWordCount(wordCount),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 继续阅读按钮
            if (status == 'reading')
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// 筛选标签
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
