import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../core/utils/event_bus.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../models/novel_model.dart';
import '../../../constants/app_constants.dart';
import 'novel_detail_screen.dart';
import 'ranking_screen.dart';
import 'recommendation_screen.dart';
import 'novel_search_dialog.dart';
import '../../../core/widgets/widgets.dart';
import 'novel_list_screen_content.dart';

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
  /// 是否首次加载（仅首次显示整页骨架屏；切换标签/刷新时保留列表，仅顶部细进度条提示）
  bool _isFirstLoad = true;
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
        showSnackBar(context, '初始化失败，请稍后重试');
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
        order: 'created_at.desc,id.asc',
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

      // 合并 + 按 id 去重：批量导入导致 created_at 相同、offset 分页顺序漂移会产生重复，
      // 加 id.asc tie-break（见 order 参数）让分页稳定，此处再去重作为双保险。
      final List<NovelModel> merged = refresh
          ? _dedupeById(novels)
          : _dedupeById([..._allNovels, ...novels]);
      final int newCount = merged.length - (refresh ? 0 : _allNovels.length);

      setState(() {
        _allNovels = merged;
        // 搜索态下按关键词过滤，否则展示全集（loadMore 时保持 _novels 与 _allNovels 一致）
        _novels = _searchQuery.isEmpty
            ? merged
            : merged.where((n) {
                final q = _searchQuery.toLowerCase();
                return n.title.toLowerCase().contains(q) ||
                    (n.author?.toLowerCase().contains(q) ?? false);
              }).toList();
        _userNovels = userNovels;
        _isLoading = false;
        _isFirstLoad = false;
      });
      onPaginationDataLoaded(newCount);

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
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
      if (mounted) {
        showSnackBar(context, '加载失败，请稍后重试');
      }
    }
  }

  /// 按 id 去重，保留首次出现的元素
  /// 用于防御 offset 分页顺序漂移 / 缓存与网络数据叠加导致的列表重复
  List<NovelModel> _dedupeById(List<NovelModel> list) {
    final seen = <String>{};
    final result = <NovelModel>[];
    for (final n in list) {
      if (!seen.add(n.id)) continue;
      result.add(n);
    }
    return result;
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
          EventBus.instance.fire(EventType.bookshelfUpdated);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '添加失败，请稍后重试');
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
    showNovelSearchDialog(
      context,
      controller: _searchController,
      onSearchChanged: _onSearchChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NovelListScreenContent(
      isFirstLoad: _isFirstLoad,
      isLoading: _isLoading,
      searchQuery: _searchQuery,
      novels: _novels,
      readingNovels: _readingNovels,
      userNovels: _userNovels,
      categories: _categories,
      statuses: _statuses,
      selectedCategory: _selectedCategory,
      selectedStatus: _selectedStatus,
      scrollController: scrollController,
      loadMoreIndicator: buildLoadMoreIndicator(),
      onRefresh: () => _loadNovels(refresh: true),
      onSearchChanged: _onSearchChanged,
      onClearSearch: () {
        _searchController.clear();
        _onSearchChanged('');
      },
      onCategoryChanged: _onCategoryChanged,
      onStatusChanged: _onStatusChanged,
      onShowSearchDialog: _showSearchDialog,
      onOpenNovelDetail: _openNovelDetail,
      onAddToBookshelf: _addToBookshelf,
      onOpenRanking: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RankingScreen()),
        );
      },
      onOpenRecommendation: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecommendationScreen()),
        );
      },
    );
  }
}
