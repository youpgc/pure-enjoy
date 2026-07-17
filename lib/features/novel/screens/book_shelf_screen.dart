import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';
import 'novel_detail_screen.dart';
import 'novel_list_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/widgets/widgets.dart';
import 'novel_list_for_add_screen.dart';
import '../widgets/bookshelf_item.dart';
import 'bookshelf_helpers.dart';
import 'bookshelf_action_sheet.dart';
import 'bookshelf_remove_dialog.dart';
import '../widgets/bookshelf_login_view.dart';
import '../widgets/bookshelf_empty_view.dart';
import '../widgets/bookshelf_filter_bar.dart';

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
  void onLoadMore() {
    _loadBookshelf();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    try {
      await _loadCache();
      await _loadBookshelf(refresh: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BookShelfScreen _initLoad 异常: ');
        debugPrint('堆栈信息: ');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, '初始化失败，请稍后重试');
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
          setState(() => _isLoading = false);
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
        showSnackBar(context, '加载书架失败，请稍后重试');
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
        showSnackBar(context, '移除失败，请稍后重试');
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
        showSnackBar(context, '更新状态失败，请稍后重试');
      }
    }
  }

  /// 获取筛选后的列表
  List<Map<String, dynamic>> get _filteredItems {
    if (_filterStatus == 'all') return _bookshelfItems;
    return _bookshelfItems.where((item) {
      final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
      final status = getReadingStatus(progress);
      return status == _filterStatus;
    }).toList();
  }

  /// 获取状态显示文本
  String _getStatusText(double? progress) {
    final status = getReadingStatus(progress);
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
    final status = getReadingStatus(progress);
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
    ).then((result) {
      if (result == true && mounted) {
        _loadBookshelf(refresh: true);
      }
    });
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
                  MaterialPageRoute(builder: (_) => const NovelListForAddScreen()),
                ).then((_) {
                  if (mounted) _loadBookshelf(refresh: true);
                });
              },
              tooltip: '添加小说',
            ),
        ],
      ),
      body: _userId == null
          ? BookshelfLoginView(
              onLogin: () {
                // 返回到登录页
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
            )
          : _isLoading
              ? SkeletonLoading.list(itemCount: 6, showAvatar: false)
              : _bookshelfItems.isEmpty
                  ? BookshelfEmptyView(
                      onRefresh: () => _loadBookshelf(refresh: true),
                      onAdd: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NovelListForAddScreen(),
                          ),
                        );
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadBookshelf(refresh: true),
                      child: Column(
                        children: [
                          // 状态筛选栏
                          BookshelfFilterBar(
                            items: _bookshelfItems,
                            filterStatus: _filterStatus,
                            onFilterChanged: (status) =>
                                setState(() => _filterStatus = status),
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
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: _filteredItems.length + 1,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      if (index == _filteredItems.length) {
                                        return buildLoadMoreIndicator();
                                      }
                                      final item = _filteredItems[index];
                                      return BookshelfItem(
                                        item: item,
                                        colorScheme: colorScheme,
                                        getStatusText: _getStatusText,
                                        getStatusColor: _getStatusColor,
                                        formatLastRead: formatBookshelfLastRead,
                                        formatWordCount: formatBookshelfWordCount,
                                        onTap: () => _continueReading(item),
                                        onLongPress: () =>
                                            showBookshelfActionSheet(
                                          context,
                                          item,
                                          onContinueReading: () => _continueReading(item),
                                          onOpenDetail: () => _openNovelDetail(item),
                                          onUpdateReadingStatus: (status) =>
                                            _updateReadingStatus(
                                                item['id'].toString(), status),
                                          onConfirmRemove: (userNovelId) =>
                                            showBookshelfRemoveDialog(
                                          context,
                                          onRemove: () => _removeFromBookshelf(userNovelId),
                                        ),
                                        ),
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
