// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../../services/supabase_service.dart';
import '../../../services/chapter_cache_service.dart';
import '../../../services/api_client.dart';
import '../models/novel_model.dart';
import '../services/bookmark_service.dart';
import '../services/reading_history_service.dart';
import '../services/annotation_service.dart';
import '../services/tts_service.dart';
import '../widgets/reader_page_turn.dart';
import '../widgets/paged_chapter_content.dart';
import '../widgets/curl_chapter_content.dart';
import '../widgets/reader_enums.dart';
import '../widgets/tts_panel.dart';
import '../widgets/reader_settings_panel.dart';
import '../widgets/reader/reader_widgets.dart';
import '../widgets/reader/reader_text_utils.dart';
import '../widgets/reader/reader_annotated_text_builder.dart';
import '../../../core/widgets/widgets.dart';


/// 小说阅读器页面
class NovelReaderScreen extends StatefulWidget {
  final NovelModel novel;
  final int startChapter;

  const NovelReaderScreen({
    super.key,
    required this.novel,
    this.startChapter = 1,
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

  // 分页内容组件的 Key，用于获取当前页码
  final _pagedContentKey = GlobalKey<PagedChapterContentState>();
  final _curlContentKey = GlobalKey<CurlChapterContentState>();

  // 电池相关
  final Battery _battery = Battery();
  int _batteryLevel = 100;

  List<NovelChapterModel> _chapters = [];
  NovelChapterModel? _currentChapter;
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  bool _isLoadingChapter = false;
  bool _showMenu = false;

  // 悬浮工具栏动画控制器
  late AnimationController _toolbarAnimationController;
  late Animation<Offset> _topToolbarSlideAnimation;
  late Animation<Offset> _bottomToolbarSlideAnimation;
  late Animation<double> _toolbarFadeAnimation;

  // 当前页码信息（由子组件回调更新）
  int _currentPageIndex = 0;
  int _totalPages = 1;

  // 阅读时长统计
  DateTime? _readingStartTime;
  Duration _totalReadingTime = Duration.zero;
  bool _hasStartedReading = false;

  // 阅读设置
  static const List<double> _fontSizes = [12, 14, 16, 18, 20, 22, 24, 26, 28];
  int _fontSizeIndex = 4; // 默认 20
  double get _fontSize => _fontSizes[_fontSizeIndex];
  static const List<double> _lineHeights = [1.4, 1.6, 1.8, 2.0, 2.2];
  int _lineHeightIndex = 2; // 默认 1.8
  double get _lineHeight => _lineHeights[_lineHeightIndex];
  ReaderBackground _background = ReaderBackground.yellow;
  ReaderBackground _lastDayBackground = ReaderBackground.yellow;
  ReaderFont _font = ReaderFont.serif;
  PageTurnMode _pageTurnMode = PageTurnMode.scroll;

  // 书架状态
  bool _isInBookshelf = false;
  bool _isCollected = false;
  String? _bookshelfId;

  // 6.1 新增：书签状态
  bool _isBookmarked = false;
  List<NovelBookmark> _bookmarks = [];

  // 6.1 新增：批注列表（当前章节）
  List<NovelAnnotation> _annotations = [];

  // 6.1 新增：TTS 状态
  bool _isTtsPlaying = false;

  // 6.1 新增：阅读历史定时器
  Timer? _readingHistoryTimer;
  DateTime? _chapterReadStartTime;

  // 防止重复触发下一章
  bool _hasTriggeredNextChapter = false;

  // 防止重复触发预加载（70% 进度）
  bool _hasTriggeredPreload = false;

  /// 标记是否需要跳转到最后一页（上一章时）
  bool _shouldJumpToLastPage = false;

  // 渲染优化：带批注的 TextSpan 构建器
  late final ReaderAnnotatedTextBuilder _annotatedTextBuilder;

  // 渲染优化：静态 TextStyle 缓存
  static final Map<int, TextStyle> _textStyleCache = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const int _catalogPageSize = 20;

  int get _fontStyleHash => Object.hash(_fontSize, _lineHeight, _background, _font);

  /// 当前正在加载的章节ID，用于防止快速切换时竞态条件（Bug 2 修复）
  String? _loadingChapterId;

  /// 书架状态检查完成信号，防止 _saveProgress 在检查完成前创建重复记录（Bug 3 修复）
  final Completer<void> _bookshelfStatusCompleter = Completer<void>();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化悬浮工具栏动画
    _toolbarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _topToolbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOut,
    ));
    _bottomToolbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOut,
    ));
    _toolbarFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOut,
    ));

    _annotatedTextBuilder = ReaderAnnotatedTextBuilder(annotations: _annotations);
    _scrollController.addListener(_onScroll);
    _loadSettings();
    _loadChapters();
    _checkBookshelfStatus();

    // 初始化电池电量
    _battery.batteryLevel.then((level) {
      if (mounted) setState(() => _batteryLevel = level);
    });

    // 初始进入时设置沉浸式模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _toolbarAnimationController.dispose();
    _scrollController.dispose();
    // 6.1 新增：清理 TTS 和阅读历史定时器
    TtsService().dispose();
    _readingHistoryTimer?.cancel();
    // 退出阅读器时恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveProgress();
      _pauseReadingTimer();
    } else if (state == AppLifecycleState.resumed) {
      _resumeReadingTimer();
    }
  }

  void _pauseReadingTimer() {
    if (_readingStartTime != null && _hasStartedReading) {
      _totalReadingTime += DateTime.now().difference(_readingStartTime!);
      _readingStartTime = null;
    }
  }

  void _resumeReadingTimer() {
    if (_hasStartedReading) {
      _readingStartTime = DateTime.now();
    }
  }

  void _startReadingTimer() {
    if (!_hasStartedReading) {
      _hasStartedReading = true;
      _readingStartTime = DateTime.now();
    }
  }

  Duration get _currentReadingDuration {
    if (_readingStartTime != null) {
      return _totalReadingTime + DateTime.now().difference(_readingStartTime!);
    }
    return _totalReadingTime;
  }

  Widget _buildChapterDrawer() {
    return ReaderChapterDrawer(
      chapters: _chapters,
      currentChapterIndex: _currentChapterIndex,
      background: _background,
      catalogPageSize: _catalogPageSize,
      onCloseDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
      onChapterTap: (globalIndex, chapter) {
        _shouldJumpToLastPage = false;
        setState(() => _currentChapterIndex = globalIndex);
        _loadChapterContent(chapter);
      },
    );
  }

  Widget _buildBottomStatusBar() {
    return ReaderBottomStatusBar(
      background: _background,
      chaptersNotEmpty: _chapters.isNotEmpty,
      readingProgress: _readingProgress,
      currentTime: _currentTime,
      batteryLevel: _batteryLevel,
    );
  }

  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
    if (_showMenu) {
      _toolbarAnimationController.forward();
      // 保持沉浸式模式，避免状态栏显示导致内容偏移
      // 工具栏使用 SafeArea 自动适配状态栏高度
    } else {
      _toolbarAnimationController.reverse();
    }
  }

  double get _readingProgress {
    if (_chapters.isEmpty) return 0;
    return (_currentChapterIndex + 1) / _chapters.length;
  }

  String get _currentTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// 构建顶部状态栏（始终显示，层级低）
  Widget _buildTopStatusBar() {
    return ReaderTopStatusBar(
      background: _background,
      currentChapter: _currentChapter,
      novelTitle: widget.novel.title,
      onBack: () async {
        await _saveProgress();
        if (mounted) Navigator.pop(context);
      },
    );
  }

  /// 构建顶部菜单（菜单显示时才显示，层级高）
  Widget _buildTopMenu() {
    return ReaderTopMenu(
      fadeAnimation: _toolbarFadeAnimation,
      slideAnimation: _topToolbarSlideAnimation,
      background: _background,
      novel: widget.novel,
      currentChapter: _currentChapter,
      currentChapterIndex: _currentChapterIndex,
      chapterCount: _chapters.length,
      hasStartedReading: _hasStartedReading,
      currentReadingDuration: _currentReadingDuration,
      isInBookshelf: _isInBookshelf,
      isBookmarked: _isBookmarked,
      isCollected: _isCollected,
      onAddToBookshelf: _addToBookshelf,
      onToggleBookmark: _toggleBookmark,
      onToggleCollection: _toggleCollection,
      onShowTtsPanel: _showTtsPanel,
    );
  }

  /// 构建底部悬浮工具栏
  Widget _buildBottomToolbar() {
    return ReaderBottomToolbar(
      fadeAnimation: _toolbarFadeAnimation,
      slideAnimation: _bottomToolbarSlideAnimation,
      background: _background,
      currentChapterIndex: _currentChapterIndex,
      chapterCount: _chapters.length,
      onPreviousChapter: _previousChapter,
      onNextChapter: _nextChapter,
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      onShowBookmarkList: _showBookmarkList,
      onShowAnnotationList: _showAnnotationList,
      onShowSettings: _showSettings,
      onToggleDayNight: () {
        setState(() {
          if (_background == ReaderBackground.dark) {
            _background = _lastDayBackground;
          } else {
            _lastDayBackground = _background;
            _background = ReaderBackground.dark;
          }
        });
        _saveSettings();
      },
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final savedFontSize = prefs.getDouble('reader_font_size') ?? 18;
      _fontSizeIndex = _fontSizes.indexOf(savedFontSize);
      if (_fontSizeIndex < 0) _fontSizeIndex = 3;
      final savedLineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
      _lineHeightIndex = _lineHeights.indexOf(savedLineHeight);
      if (_lineHeightIndex < 0) _lineHeightIndex = 2;
      final savedBg = prefs.getInt('reader_background') ?? 2;
      _background = ReaderBackground.values[savedBg.clamp(0, ReaderBackground.values.length - 1)];
      final savedLastDayBg = prefs.getInt('reader_last_day_background') ?? 2;
      _lastDayBackground = ReaderBackground.values[savedLastDayBg.clamp(0, ReaderBackground.values.length - 1)];
      final savedFont = prefs.getInt('reader_font') ?? 0;
      _font = ReaderFont.values[savedFont.clamp(0, ReaderFont.values.length - 1)];
      final savedMode = prefs.getInt('reader_page_turn_mode') ?? 0;
      _pageTurnMode = PageTurnMode.values[savedMode.clamp(0, PageTurnMode.values.length - 1)];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setDouble('reader_line_height', _lineHeight);
    await prefs.setInt('reader_background', _background.index);
    await prefs.setInt('reader_last_day_background', _lastDayBackground.index);
    await prefs.setInt('reader_font', _font.index);
    await prefs.setInt('reader_page_turn_mode', _pageTurnMode.index);
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);

    try {
      // 分批加载章节列表（id,title,chapter_num 轻量查询）
      const batchSize = 50;
      final allChapters = <NovelChapterModel>[];
      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        final result = await ApiClient.get(
          'novel_chapters',
          filters: {'novel_id': 'eq.${widget.novel.id}'},
          columns: 'id,title,chapter_num',
          order: 'chapter_num.asc',
          limit: batchSize,
          offset: offset,
        );

        if (result.isSuccess && result.data != null) {
          final batch = result.data!
              .map((json) => NovelChapterModel.fromJson(json))
              .toList();
          allChapters.addAll(batch);
          hasMore = batch.length >= batchSize;
          offset += batchSize;
        } else {
          hasMore = false;
        }
      }

      allChapters.removeWhere((c) => c.chapterOrder <= 0);

      // 获取阅读进度
      final userId = _userId;
      int startIndex = 0;
      if (userId != null) {
        try {
          final progressResult = await ApiClient.get(
            'user_novels',
            filters: {
              'user_id': 'eq.$userId',
              'novel_id': 'eq.${widget.novel.id}',
            },
            columns: 'last_chapter',
          );
          if (progressResult.isSuccess) {
            final progressData = progressResult.data!;
            if (progressData.isNotEmpty) {
              final savedChapter = progressData.first['last_chapter'] as int? ?? 1;
              for (int i = 0; i < allChapters.length; i++) {
                if (allChapters[i].chapterOrder >= savedChapter) {
                  startIndex = i;
                  break;
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('解析已读章节进度失败');
        }
      }

      // 也考虑 widget.startChapter
      for (int i = 0; i < allChapters.length; i++) {
        if (allChapters[i].chapterOrder >= widget.startChapter) {
          if (i > startIndex) startIndex = i;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _chapters = allChapters;
          _currentChapterIndex = startIndex;
          _isLoading = false;
        });
      }

      if (_chapters.isNotEmpty) {
        _loadChapterContent(_chapters[startIndex]);
        _preloadAdjacentChapters(startIndex);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) showSnackBar(context, '加载章节失败: $e');
    }
  }

  Future<void> _loadChapterContent(NovelChapterModel chapter) async {
    // 记录当前加载的章节ID，用于防止竞态条件（Bug 2 修复）
    _loadingChapterId = chapter.id;
    setState(() => _isLoadingChapter = true);
    _hasTriggeredNextChapter = false;
    // 重置页码信息
    _currentPageIndex = 0;
    _totalPages = 1;

    // 1. 优先从 _chapters 列表中加载已缓存的内容（无感切换）
    final index = _chapters.indexWhere((c) => c.id == chapter.id);
    if (index != -1 && _chapters[index].content.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentChapter = _chapters[index];
          _isLoadingChapter = false;
        });
      }
      _scrollToPosition();
      _saveProgress();
      _startReadingTimer();
      _checkBookmarkStatus();
      _chapterReadStartTime = DateTime.now();
      return;
    }

    // 设置当前保护章节（内存压力时不清理）
    ChapterCacheService.instance.setProtectedChapter(chapter.id);

    try {
      // 2. 检查本地持久化缓存，同时发起网络请求（并行加载）
      final cacheFuture = ChapterCacheService.instance.getCachedContent(chapter.id);
      final networkFuture = ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
      );

      // 等待缓存结果
      final cachedContent = await cacheFuture;

      // 检查是否已切换到其他章节
      if (_loadingChapterId != chapter.id) return;

      if (cachedContent != null) {
        // 有缓存，先显示缓存内容
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final cachedChapter = chapter.copyWith(content: normalizedContent);
        final chapterIndex = _chapters.indexWhere((c) => c.id == chapter.id);
        if (chapterIndex != -1) {
          _chapters[chapterIndex] = cachedChapter;
        }
        if (mounted) {
          setState(() {
            _currentChapter = cachedChapter;
            _isLoadingChapter = false;
          });
        }
        // 根据方向决定滚动位置：上一章到末尾，下一章到顶部
        _scrollToPosition();
        _saveProgress();
        _startReadingTimer();
        _checkBookmarkStatus();
        _chapterReadStartTime = DateTime.now();
        // 继续等待网络请求更新缓存
      }

      // 等待网络请求
      final result = await networkFuture;

      // 再次检查是否已切换到其他章节（Bug 2 核心修复）
      if (_loadingChapterId != chapter.id) return;

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          final chapterData = data.first;
          final parsedChapter = NovelChapterModel.fromJson(chapterData);
          // 归一化换行符，避免 \r\n 导致渲染异常
          final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

          // 更新 _chapters 列表中的章节内容
          final loadedChapter = parsedChapter.copyWith(content: normalizedContent);
          final loadedIndex = _chapters.indexWhere((c) => c.id == parsedChapter.id);
          if (loadedIndex != -1) {
            _chapters[loadedIndex] = loadedChapter;
          }

          // 只有当网络内容比缓存新或不同才更新UI
          if (_currentChapter == null || _currentChapter!.content != normalizedContent) {
            if (mounted) {
              setState(() {
                _currentChapter = loadedChapter;
                _isLoadingChapter = false;
              });
            }
            // 根据方向决定滚动位置
            _scrollToPosition();
            _saveProgress();
            _startReadingTimer();
            _checkBookmarkStatus();
            _chapterReadStartTime = DateTime.now();
          }

          if (normalizedContent.isNotEmpty) {
            ChapterCacheService.instance.cacheChapter(
              chapterId: parsedChapter.id,
              novelId: widget.novel.id,
              title: parsedChapter.title,
              chapterOrder: parsedChapter.chapterOrder,
              content: normalizedContent,
            );
          }
        } else if (_currentChapter == null) {
          if (mounted) {
            setState(() {
              _currentChapter = chapter;
              _isLoadingChapter = false;
            });
          }
          _scrollToPosition();
        }
      } else if (_currentChapter == null) {
        if (mounted) {
          setState(() {
            _currentChapter = chapter;
            _isLoadingChapter = false;
          });
        }
        _scrollToPosition();
      }
    } catch (e) {
      // 异常时也检查是否已切换章节
      if (_loadingChapterId != chapter.id) return;
      if (_currentChapter == null) {
        if (mounted) {
          setState(() {
            _currentChapter = chapter;
            _isLoadingChapter = false;
          });
        }
        _scrollToPosition();
      }
    }
  }

  /// 静默预加载单个章节内容（不显示 loading，不影响当前章节）
  Future<void> _fetchChapterContent(NovelChapterModel chapter) async {
    // 已加载则跳过
    final idx = _chapters.indexWhere((c) => c.id == chapter.id);
    if (idx != -1 && _chapters[idx].content.isNotEmpty) return;

    try {
      final cacheFuture = ChapterCacheService.instance.getCachedContent(chapter.id);
      final networkFuture = ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
      );

      final cachedContent = await cacheFuture;
      if (cachedContent != null) {
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (idx != -1) {
          _chapters[idx] = chapter.copyWith(content: normalizedContent);
        }
      }

      final result = await networkFuture;
      if (result.isSuccess && result.data!.isNotEmpty) {
        final chapterData = result.data!.first;
        final parsedChapter = NovelChapterModel.fromJson(chapterData);
        final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final parsedIdx = _chapters.indexWhere((c) => c.id == parsedChapter.id);
        if (parsedIdx != -1) {
          _chapters[parsedIdx] = _chapters[parsedIdx].copyWith(content: normalizedContent);
        }
        if (normalizedContent.isNotEmpty) {
          ChapterCacheService.instance.cacheChapter(
            chapterId: parsedChapter.id,
            novelId: widget.novel.id,
            title: parsedChapter.title,
            chapterOrder: parsedChapter.chapterOrder,
            content: normalizedContent,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('预加载章节失败: ${chapter.title}');
      }
    }
  }

  /// 智能预加载：根据网络环境决定预加载数量
  /// WiFi 环境下预加载 5 章，蜂窝网络下预加载 2 章
  void _preloadAdjacentChapters(int index) {
    // 重置预加载触发标志
    _hasTriggeredPreload = false;

    final preloadIds = <String>[];
    // 优先预加载后续章节（阅读主要向前）
    for (int i = index + 1; i < _chapters.length && preloadIds.length < 5; i++) {
      final chapter = _chapters[i];
      if (chapter.content.isEmpty) {
        preloadIds.add(chapter.id);
      }
    }

    if (preloadIds.isEmpty) return;

    ChapterCacheService.instance.triggerPreload(
      chapterIds: preloadIds,
      fetcher: (chapterId) async {
        final chapter = _chapters.firstWhere((c) => c.id == chapterId);
        await _fetchChapterContent(chapter);
        return chapter.content;
      },
    );
  }

  /// 根据阅读方向滚动到合适位置
  /// - 上一章：滚动到末尾（显示最后一页/底部）
  /// - 下一章：滚动到顶部（显示第一页/顶部）
  void _scrollToPosition() {
    if (_pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式：使用 ScrollController
      if (_scrollController.hasClients) {
        if (_shouldJumpToLastPage) {
          // 上一章：跳转到末尾
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          // 下一章：跳转到顶部
          _scrollController.jumpTo(0);
        }
      }
    }
    // 分页模式：通过 _shouldJumpToLastPage 标志，在 _calculatePages 中处理
  }

  /// 滚动到底部自动加载下一章 - 带防重复触发
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_pageTurnMode != PageTurnMode.scroll) return; // 只在滚动模式下生效

    // 70% 进度触发预加载（智能预加载）
    if (!_hasTriggeredPreload && !_isLoadingChapter) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        final progress = _scrollController.position.pixels / maxExtent;
        if (progress >= 0.7) {
          _hasTriggeredPreload = true;
          _preloadAdjacentChapters(_currentChapterIndex);
        }
      }
    }

    if (_hasTriggeredNextChapter) return; // 防止重复触发
    if (_isLoadingChapter) return;

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (_currentChapterIndex < _chapters.length - 1) {
        _hasTriggeredNextChapter = true;
        _nextChapter();
      }
    }
  }

  Future<void> _checkBookshelfStatus() async {
    final userId = _userId;
    if (userId == null) {
      if (!_bookshelfStatusCompleter.isCompleted) _bookshelfStatusCompleter.complete();
      return;
    }

    try {
      final result = await ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$userId',
          'novel_id': 'eq.${widget.novel.id}',
        },
        columns: 'id,is_collected',
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty && mounted) {
          setState(() {
            _isInBookshelf = true;
            _bookshelfId = data.first['id'].toString();
            _isCollected = data.first['is_collected'] as bool? ?? false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('检查书架状态失败');
      }
    } finally {
      if (!_bookshelfStatusCompleter.isCompleted) _bookshelfStatusCompleter.complete();
    }
  }

  Future<void> _saveProgress() async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      final chapterNum = _currentChapter!.chapterOrder;
      final totalChapters = _chapters.length;
      final progress = totalChapters > 0 ? chapterNum / totalChapters : 0.0;

      // 6.1 新增：记录阅读历史
      await _recordReadingHistory(progress);

      if (_isInBookshelf && _bookshelfId != null) {
        await ApiClient.patchByFilter(
          'user_novels',
          filters: {'id': 'eq.$_bookshelfId'},
          body: {
            'last_chapter': chapterNum,
            'progress': progress,
            'is_collected': true,
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } else {
        // 等待书架状态检查完成，避免重复创建记录（Bug 3 修复）
        if (!_bookshelfStatusCompleter.isCompleted) {
          await _bookshelfStatusCompleter.future;
        }
        // 再次检查，可能在等待期间 _checkBookshelfStatus 已完成并设置了书架状态
        if (_isInBookshelf && _bookshelfId != null) {
          await ApiClient.patchByFilter(
            'user_novels',
            filters: {'id': 'eq.$_bookshelfId'},
            body: {
              'last_chapter': chapterNum,
              'progress': progress,
              'is_collected': true,
              'last_read_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        } else {
          final result = await ApiClient.post(
            'user_novels',
            {
              'user_id': userId,
              'novel_id': widget.novel.id,
              'progress': progress,
              'last_chapter': chapterNum,
              'is_collected': true,
              'last_read_at': DateTime.now().toUtc().toIso8601String(),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          );

          if (result.isSuccess) {
            final data = result.data!;
            if (data.isNotEmpty && mounted) {
              setState(() {
                _isInBookshelf = true;
                _bookshelfId = data.first['id'].toString();
                _isCollected = true; // Bug 7 修复：同步收藏状态
              });
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('保存阅读进度失败');
      }
    }
  }

  /// 6.1 新增：记录阅读历史明细
  Future<void> _recordReadingHistory(double progress) async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) return;

    final now = DateTime.now();
    final readDuration = _chapterReadStartTime != null
        ? now.difference(_chapterReadStartTime!).inSeconds
        : 0;

    // 至少阅读了5秒才记录
    if (readDuration < 5) return;

    await ReadingHistoryService().recordReading(
      novelId: widget.novel.id,
      chapterId: _currentChapter!.id,
      chapterOrder: _currentChapter!.chapterOrder,
      readDurationSeconds: readDuration,
      progress: progress,
    );

    _chapterReadStartTime = now;
  }

  /// 6.1 新增：检查当前位置是否有书签
  Future<void> _checkBookmarkStatus() async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) return;

    final bookmarked = await BookmarkService().hasBookmark(
      widget.novel.id,
      _currentChapter!.id,
      0, // 简化为章节级别书签
    );
    if (mounted) {
      setState(() => _isBookmarked = bookmarked);
    }

    // 加载本书所有书签
    final bookmarks = await BookmarkService().getBookmarks(widget.novel.id);
    if (mounted) {
      setState(() => _bookmarks = bookmarks);
    }

    // 同时加载当前章节批注
    await _loadAnnotations();
  }

  /// 6.1 新增：加载当前章节批注
  Future<void> _loadAnnotations() async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) {
      setState(() => _annotations = []);
      return;
    }

    try {
      final result = await AnnotationService().getChapterAnnotations(
        widget.novel.id,
        _currentChapter!.id,
      );
      if (mounted) {
        setState(() => _annotations = result);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载批注失败');
      }
      if (mounted) {
        setState(() => _annotations = []);
      }
    }
  }

  /// 6.1 新增：估算当前阅读字符偏移
  int _estimateCharOffset() {
    if (_currentChapter == null) return 0;
    final content = _currentChapter!.content;
    if (_pageTurnMode == PageTurnMode.scroll &&
        _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        final ratio = _scrollController.offset / maxScroll;
        return (ratio * content.length).toInt().clamp(0, content.length);
      }
    }
    return 0;
  }

  /// 6.1 新增：获取段落预览文本
  String _getParagraphPreview(int charOffset) {
    if (_currentChapter == null) return '';
    final content = _currentChapter!.content;
    final start = charOffset.clamp(0, content.length);
    final end = (start + 50).clamp(0, content.length);
    return content.substring(start, end);
  }

  /// 6.1 新增：切换书签
  Future<void> _toggleBookmark() async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) {
      if (mounted) showSnackBar(context, '请先登录');
      return;
    }

    final charOffset = _estimateCharOffset();
    final preview = _getParagraphPreview(charOffset);

    final success = await BookmarkService().toggleBookmark(
      novelId: widget.novel.id,
      chapterId: _currentChapter!.id,
      chapterOrder: _currentChapter!.chapterOrder,
      charOffset: charOffset,
      note: preview.isNotEmpty ? preview : null,
    );

    if (success && mounted) {
      setState(() => _isBookmarked = !_isBookmarked);
      showSnackBar(context, _isBookmarked ? '书签已添加' : '书签已移除');
      await _checkBookmarkStatus();
    }
  }

  /// 6.1 新增：显示书签列表
  void _showBookmarkList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReaderBookmarkPanel(
        bookmarks: _bookmarks,
        currentChapter: _currentChapter,
        onClose: () => Navigator.pop(context),
        onBookmarkTap: (bm) {
          Navigator.pop(context);
          _jumpToBookmark(bm);
        },
      ),
    );
  }

  /// 6.1 新增：跳转到书签位置（支持字符偏移）
  void _jumpToBookmark(NovelBookmark bookmark) {
    _loadChapterContent(_chapters[bookmark.chapterOrder - 1]);
    // 章节加载完成后，滚动到字符偏移位置
    if (bookmark.charOffset > 0 && _pageTurnMode == PageTurnMode.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _currentChapter != null) {
          final content = _currentChapter!.content;
          final ratio = bookmark.charOffset / content.length;
          final targetOffset = ratio * _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 6.1 新增：构建带高亮的文本 Span（委托给 ReaderAnnotatedTextBuilder）
  TextSpan _buildAnnotatedTextSpan(String content, TextStyle baseStyle) {
    return _annotatedTextBuilder.build(
      content: content,
      baseStyle: baseStyle,
      chapterId: _currentChapter?.id ?? '',
      fontStyleHash: _fontStyleHash,
    );
  }

  /// 6.1 新增：显示批注输入面板
  void _showAnnotationInputPanel(String selectedText, int startOffset, int endOffset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReaderAnnotationPanel(
        selectedText: selectedText,
        startOffset: startOffset,
        endOffset: endOffset,
        onSave: (selectedText, startOffset, endOffset, note, color) async {
          await _addAnnotation(
            selectedText: selectedText,
            startOffset: startOffset,
            endOffset: endOffset,
            note: note,
            color: color,
          );
        },
      ),
    );
  }

  /// 6.1 新增：添加批注
  Future<void> _addAnnotation({
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required String? note,
    required String color,
  }) async {
    final userId = _userId;
    if (userId == null) {
      showSnackBar(context, '请先登录');
      return;
    }
    if (_currentChapter == null) return;

    try {
      await AnnotationService().addAnnotation(
        novelId: widget.novel.id,
        chapterId: _currentChapter!.id,
        chapterOrder: _currentChapter!.chapterOrder,
        startOffset: startOffset,
        endOffset: endOffset,
        highlightedText: selectedText,
        note: note,
        color: parseAnnotationColor(color),
      );
      if (mounted) {
        showSnackBar(context, '批注已添加');
        await _loadAnnotations();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '添加批注失败');
      }
    }
  }

  /// 6.1 新增：删除批注
  Future<void> _deleteAnnotation(String annotationId) async {
    try {
      await AnnotationService().deleteAnnotation(annotationId);
      if (mounted) {
        showSnackBar(context, '批注已删除');
        await _loadAnnotations();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '删除失败');
      }
    }
  }

  /// 6.1 新增：显示批注列表
  void _showAnnotationList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReaderAnnotationListPanel(
        annotations: _annotations,
        onClose: () => Navigator.pop(context),
        onDelete: (annotation) {
          showConfirmDialog(
            context,
            title: '删除批注',
            content: '确定要删除这条批注吗？',
          ).then((confirmed) {
            if (confirmed == true) {
              if (!mounted) return;
              Navigator.pop(context); // ignore: use_build_context_synchronously
              _deleteAnnotation(annotation.id);
            }
          });
        },
      ),
    );
  }

  /// 6.1 新增：显示TTS控制面板
  void _showTtsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TtsPanel(
        isPlaying: _isTtsPlaying,
        onPlayStateChanged: (playing) {
          setState(() => _isTtsPlaying = playing);
        },
        novelId: widget.novel.id,
        chapterId: _currentChapter?.id ?? '',
        chapterContent: _currentChapter?.content ?? '',
      ),
    );
  }

  Future<void> _addToBookshelf() async {
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
          'novel_id': widget.novel.id,
          'progress': 0,
          'last_chapter': _currentChapter?.chapterOrder ?? 1,
          'is_collected': true,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty && mounted) {
          setState(() {
            _isInBookshelf = true;
            _bookshelfId = data.first['id'].toString();
          });
        }
        if (mounted) {
          showSnackBar(context, '已加入书架');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '操作失败: $e');
      }
    }
  }

  Future<void> _toggleCollection() async {
    if (_bookshelfId == null) {
      await _addToBookshelf();
      return;
    }

    try {
      final result = await ApiClient.patchByFilter(
        'user_novels',
        filters: {'id': 'eq.$_bookshelfId'},
        body: {'is_collected': !_isCollected},
      );

      if (result.isSuccess) {
        if (mounted) {
          setState(() => _isCollected = !_isCollected);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '操作失败: $e');
      }
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      // 标记需要跳转到最后一页（上一章）
      _shouldJumpToLastPage = true;
      // 重置预加载触发标志
      _hasTriggeredPreload = false;
      _hasTriggeredNextChapter = false;
      final prevIndex = _currentChapterIndex - 1;
      setState(() {
        _currentChapterIndex = prevIndex;
      });
      _loadChapterContent(_chapters[prevIndex]);
      // 预加载新的相邻章节
      _preloadAdjacentChapters(prevIndex);
    } else {
      if (mounted) {
        showSnackBar(context, '已经是第一章了');
      }
    }
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      // 标记需要跳转到第一页（下一章）
      _shouldJumpToLastPage = false;
      // 重置预加载触发标志
      _hasTriggeredPreload = false;
      _hasTriggeredNextChapter = false;
      final nextIndex = _currentChapterIndex + 1;
      setState(() {
        _currentChapterIndex = nextIndex;
      });
      _loadChapterContent(_chapters[nextIndex]);
      // 预加载新的相邻章节
      _preloadAdjacentChapters(nextIndex);
    } else {
      if (mounted) {
        showSnackBar(context, '已经是最后一章了');
      }
    }
  }

  /// 子组件回调：页码变化
  void _onPageChanged(int currentPage, int totalPages) {
    setState(() {
      _currentPageIndex = currentPage;
      _totalPages = totalPages;
    });
  }

  /// 子组件回调：PageView 到达边界
  void _onPageBoundaryReached(bool isLastPage) {
    if (isLastPage) {
      // 到达最后一页，跳转下一章
      if (_currentChapterIndex < _chapters.length - 1) {
        _nextChapter();
      } else {
        showSnackBar(context, '已经是最后一章了');
      }
    } else {
      // 到达第一页，跳转上一章
      if (_currentChapterIndex > 0) {
        _previousChapter();
      } else {
        showSnackBar(context, '已经是第一章了');
      }
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ReaderSettingsPanel(
          fontSize: _fontSize,
          fontSizeIndex: _fontSizeIndex,
          fontSizes: _fontSizes,
          lineHeight: _lineHeight,
          lineHeightIndex: _lineHeightIndex,
          lineHeights: _lineHeights,
          pageTurnMode: _pageTurnMode,
          font: _font,
          background: _background,
          onFontSizeIndexChanged: (index) {
            setModalState(() => _fontSizeIndex = index);
            setState(() {});
          },
          onLineHeightIndexChanged: (index) {
            setModalState(() => _lineHeightIndex = index);
            setState(() {});
          },
          onPageTurnModeChanged: (mode) {
            setModalState(() => _pageTurnMode = mode);
            setState(() {});
          },
          onFontChanged: (font) {
            setModalState(() => _font = font);
            setState(() {});
          },
          onBackgroundChanged: (bg) {
            setModalState(() => _background = bg);
            setState(() {});
            if (bg != ReaderBackground.dark) {
              _lastDayBackground = bg;
            }
          },
          onSave: _saveSettings,
        ),
      ),
    );
  }

  /// 构建底部常驻状态栏（始终显示）
  void _handleScreenTap(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (_pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式下只有中间区域有操作
      if (dx >= width * 0.3 && dx <= width * 0.7) {
        _toggleMenu();
      }
      return;
    }

    // 分页模式
    if (dx < width * 0.3) {
      // 左侧区域
      if (_currentPageIndex <= 0) {
        // 第一页，跳转上一章
        _previousChapter();
      } else {
        // 上一页
        _pagedContentKey.currentState?.previousPage();
        _curlContentKey.currentState?.previousPage();
      }
    } else if (dx > width * 0.7) {
      // 右侧区域
      if (_currentPageIndex >= _totalPages - 1) {
        // 最后一页，跳转下一章
        _nextChapter();
      } else {
        // 下一页
        _pagedContentKey.currentState?.nextPage();
        _curlContentKey.currentState?.nextPage();
      }
    } else {
      // 中间区域：切换菜单
      _toggleMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveProgress();
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background.bgColor,
      appBar: null, // 始终不显示 AppBar
      drawer: _buildChapterDrawer(),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _currentChapter == null
              ? Center(child: Text('暂无章节', style: TextStyle(color: _background.textColor)))
              : Stack(
                  children: [
                    // Column 布局：顶部状态栏 → 内容铺满 → 底部状态栏
                    Column(
                      children: [
                        // 顶部信息栏
                        _buildTopStatusBar(),
                        // 小说内容（铺满中间剩余空间）
                        Expanded(
                          child: _isLoadingChapter
                              ? const Center(child: LoadingWidget())
                              : _buildContent(),
                        ),
                        // 底部状态栏
                        _buildBottomStatusBar(),
                      ],
                    ),

                    // 顶部菜单（菜单显示时才显示，覆盖在内容上方）
                    if (_showMenu)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: _buildTopMenu(),
                      ),

                    // 底部菜单（菜单显示时才显示，覆盖在内容上方）
                    if (_showMenu)
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: _buildBottomToolbar(),
                      ),
                  ],
                ),
              ),
            );
  }

  /// 渲染优化：获取缓存的 TextStyle，避免每帧重建
  TextStyle _getCachedTextStyle({bool isTitle = false}) {
    final hash = Object.hash(_fontStyleHash, isTitle);
    return _textStyleCache.putIfAbsent(hash, () => TextStyle(
      fontSize: isTitle ? _fontSize + 4 : _fontSize,
      height: isTitle ? 1.6 : _lineHeight,
      color: _background.textColor,
      letterSpacing: isTitle ? 0 : 0.5,
      fontFamily: _font.fontFamily == 'system' ? null : _font.fontFamily,
      fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
    ));
  }

  Widget _buildContent() {
    return ReaderContentArea(
      pageTurnMode: _pageTurnMode,
      chapter: _currentChapter,
      background: _background,
      font: _font,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pagedContentKey: _pagedContentKey,
      curlContentKey: _curlContentKey,
      onPageChanged: _onPageChanged,
      onBoundaryReached: _onPageBoundaryReached,
      onTapScreen: _handleScreenTap,
      shouldJumpToLastPage: _shouldJumpToLastPage,
      scrollController: _scrollController,
      buildAnnotatedTextSpan: _buildAnnotatedTextSpan,
      onShowAnnotationInput: _showAnnotationInputPanel,
      getCachedTextStyle: _getCachedTextStyle,
    );
  }

}

