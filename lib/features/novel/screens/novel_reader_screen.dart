import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'novel_detail_screen.dart';
import '../../../core/widgets/widgets.dart';

/// 背景主题枚举
enum ReaderBackground {
  white('白色', Colors.white, Colors.black87),
  yellow('护眼黄', Color(0xFFF5F0E6), Color(0xFF333333)),
  dark('深色', Color(0xFF1A1A2E), Color(0xFFE0E0E0)),
  gray('灰色', Color(0xFFE8E8E8), Color(0xFF333333));

  const ReaderBackground(this.label, this.bgColor, this.textColor);
  final String label;
  final Color bgColor;
  final Color textColor;
}

/// 字体选择枚举
enum ReaderFont {
  system('系统默认', 'system'),
  serif('宋体', 'serif'),
  sansSerif('黑体', 'sans-serif'),
  monospace('等宽', 'monospace');

  const ReaderFont(this.label, this.fontFamily);
  final String label;
  final String fontFamily;
}

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
  final _pagedContentKey = GlobalKey<_PagedChapterContentState>();
  final _curlContentKey = GlobalKey<_CurlChapterContentState>();

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

  // 6.1 新增：当前选中的文本范围
  TextSelection? _selectedTextRange;

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

  // 渲染优化：TextSpan 缓存
  TextSpan? _cachedTextSpan;
  String? _cachedSpanForChapterId;
  int? _cachedSpanFontHash;

  // 渲染优化：静态 TextStyle 缓存
  static final Map<int, TextStyle> _textStyleCache = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // 目录分页
  int _catalogPage = 0;
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

  /// 使用 PopScope 替代 dispose 保存进度，确保在页面真正退出前完成保存
  Future<bool> _onWillPop() async {
    await _saveProgress();
    return true;
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

  String _formatReadingDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '${duration.inSeconds}秒';
    }
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '书签列表',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _bookmarks.isEmpty
                  ? const EmptyWidget(message: '暂无书签')
                  : ListView.builder(
                      itemCount: _bookmarks.length,
                      itemBuilder: (context, index) {
                        final bm = _bookmarks[index];
                        return ListTile(
                          leading: Icon(
                            bm.type == BookmarkType.auto
                                ? Icons.auto_stories
                                : Icons.bookmark,
                            color: bm.type == BookmarkType.auto
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text('第${bm.chapterOrder}章'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (bm.note != null && bm.note!.isNotEmpty)
                                Text(
                                  bm.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              Text(
                                bm.charOffset > 0
                                    ? '进度 ${(bm.charOffset / (_currentChapter?.content.length ?? 1) * 100).toStringAsFixed(0)}%'
                                    : '章节开头',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: bm.note != null && bm.note!.isNotEmpty,
                          trailing: Text(
                            '${bm.createdAt.month}/${bm.createdAt.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _jumpToBookmark(bm);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
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

  /// 6.1 新增：解析高亮色值
  Color _parseHighlightColor(String color) {
    switch (color) {
      case 'yellow': return const Color(0xFFFFF176);
      case 'green': return const Color(0xFFA5D6A7);
      case 'blue': return const Color(0xFF90CAF9);
      case 'pink': return const Color(0xFFF48FB1);
      case 'purple': return const Color(0xFFCE93D8);
      default: return const Color(0xFFFFF176);
    }
  }

  /// 6.1 新增：字符串转 AnnotationColor 枚举
  AnnotationColor _parseAnnotationColor(String color) {
    switch (color) {
      case 'green': return AnnotationColor.green;
      case 'blue': return AnnotationColor.blue;
      case 'red': return AnnotationColor.red;
      default: return AnnotationColor.yellow;
    }
  }

  /// 6.1 新增：构建带高亮的文本 Span（带缓存）
  TextSpan _buildAnnotatedTextSpan(String content, TextStyle baseStyle) {
    final chapterId = _currentChapter?.id ?? '';
    final fontHash = _fontStyleHash;
    final annotationHash = Object.hashAll(_annotations.where((a) => !a.isDeleted).map((a) => Object.hash(a.id, a.startOffset, a.endOffset)));
    final cacheKey = Object.hash(chapterId, fontHash, annotationHash);

    // 缓存命中且章节未变、字体未变、批注未变
    if (_cachedTextSpan != null &&
        _cachedSpanForChapterId == chapterId &&
        _cachedSpanFontHash == cacheKey) {
      return _cachedTextSpan!;
    }

    final activeAnnotations = _annotations.where((a) => !a.isDeleted).toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    TextSpan result;
    if (activeAnnotations.isEmpty) {
      result = TextSpan(text: content, style: baseStyle);
    } else {
      final List<InlineSpan> spans = [];
      int currentPos = 0;

      for (final annotation in activeAnnotations) {
        final start = annotation.startOffset.clamp(0, content.length);
        final end = annotation.endOffset.clamp(0, content.length);

        if (start > currentPos) {
          spans.add(TextSpan(
            text: content.substring(currentPos, start),
            style: baseStyle,
          ));
        }

        if (start < end) {
          spans.add(TextSpan(
            text: content.substring(start, end),
            style: baseStyle.copyWith(
              backgroundColor: _parseHighlightColor(annotation.color.name),
            ),
          ));
        }

        currentPos = end;
      }

      if (currentPos < content.length) {
        spans.add(TextSpan(text: content.substring(currentPos), style: baseStyle));
      }

      result = TextSpan(children: spans);
    }

    // 写入缓存
    _cachedTextSpan = result;
    _cachedSpanForChapterId = chapterId;
    _cachedSpanFontHash = cacheKey;
    return result;
  }

  /// 6.1 新增：显示批注输入面板
  void _showAnnotationInputPanel(String selectedText, int startOffset, int endOffset) {
    final noteController = TextEditingController();
    String selectedColor = 'yellow';
    final colorOptions = [
      ('yellow', const Color(0xFFFFF176)),
      ('green', const Color(0xFFA5D6A7)),
      ('blue', const Color(0xFF90CAF9)),
      ('pink', const Color(0xFFF48FB1)),
      ('purple', const Color(0xFFCE93D8)),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '添加批注',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 原文预览
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      selectedText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 颜色选择
                  Text('高亮颜色', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorOptions.map((option) {
                      final (colorName, color) = option;
                      final isSelected = selectedColor == colorName;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = colorName),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(18),
                            border: isSelected
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 笔记输入
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '输入你的笔记（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _addAnnotation(
                          selectedText: selectedText,
                          startOffset: startOffset,
                          endOffset: endOffset,
                          note: noteController.text.isEmpty ? null : noteController.text,
                          color: selectedColor,
                        );
                      },
                      child: const Text('保存批注'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
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
        color: _parseAnnotationColor(color),
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '我的批注',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _annotations.isEmpty
                  ? const EmptyWidget(message: '暂无批注，长按正文选中文本添加')
                  : ListView.builder(
                      itemCount: _annotations.length,
                      itemBuilder: (context, index) {
                        final annotation = _annotations[index];
                        return ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _parseHighlightColor(annotation.color.name),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(
                            annotation.highlightedText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: annotation.note != null && annotation.note!.isNotEmpty
                              ? Text(
                                  annotation.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () {
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
                          onTap: () {
                            Navigator.pop(context);
                            // 滚动到对应位置（简化实现）
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 6.1 新增：显示TTS控制面板
  void _showTtsPanel() {
    double tempSpeechRate = TtsService().speechRate;
    int? tempTimerMinutes = TtsService().timerMinutes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '听书模式',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // 播放控制
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: '上一句',
                        onPressed: () => TtsService().previousSentence(),
                      ),
                      IconButton(
                        icon: Icon(_isTtsPlaying ? Icons.pause_circle : Icons.play_circle),
                        iconSize: 56,
                        tooltip: _isTtsPlaying ? '暂停' : '播放',
                        onPressed: () {
                          setState(() => _isTtsPlaying = !_isTtsPlaying);
                          if (_isTtsPlaying) {
                            TtsService().playChapter(
                              widget.novel.id,
                              _currentChapter?.id ?? '',
                              _currentChapter?.content ?? '',
                              0,
                            );
                          } else {
                            TtsService().stop();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        tooltip: '下一句',
                        onPressed: () => TtsService().nextSentence(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 当前朗读句子预览
                  if (TtsService().currentSentence != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        TtsService().currentSentence!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  // 语速滑块
                  Row(
                    children: [
                      const Icon(Icons.speed, size: 20),
                      const SizedBox(width: 8),
                      Text('语速: ${tempSpeechRate.toStringAsFixed(1)}x'),
                      Expanded(
                        child: Slider(
                          value: tempSpeechRate,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${tempSpeechRate.toStringAsFixed(1)}x',
                          onChanged: (value) {
                            setModalState(() => tempSpeechRate = value);
                          },
                          onChangeEnd: (value) {
                            TtsService().setSpeechRate(value);
                            TtsService().savePreferences();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 定时关闭
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 20),
                      const SizedBox(width: 8),
                      const Text('定时关闭'),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        children: [
                          (null, '关闭'),
                          (15, '15分'),
                          (30, '30分'),
                          (60, '60分'),
                          (-1, '本章'),
                        ].map((option) {
                          final (minutes, label) = option;
                          final isSelected = tempTimerMinutes == minutes ||
                              (minutes == -1 && tempTimerMinutes == -1);
                          return ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => tempTimerMinutes = minutes);
                                TtsService().setTimer(minutes);
                                TtsService().savePreferences();
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 播放模式
                  Row(
                    children: [
                      const Icon(Icons.playlist_play, size: 20),
                      const SizedBox(width: 8),
                      const Text('播放模式'),
                      const Spacer(),
                      SegmentedButton<TtsPlaybackMode>(
                        segments: const [
                          ButtonSegment(
                            value: TtsPlaybackMode.sentence,
                            label: Text('逐句'),
                          ),
                          ButtonSegment(
                            value: TtsPlaybackMode.paragraph,
                            label: Text('逐段'),
                          ),
                          ButtonSegment(
                            value: TtsPlaybackMode.chapter,
                            label: Text('整章'),
                          ),
                        ],
                        selected: {TtsService().playbackMode},
                        onSelectionChanged: (selected) {
                          final mode = selected.first;
                          TtsService().setPlaybackMode(mode);
                          TtsService().savePreferences();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
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

  Widget _buildChapterDrawer() {
    if (_chapters.isEmpty) return const Drawer(child: Center(child: LoadingWidget()));
    final totalPages = (_chapters.length / _catalogPageSize).ceil();
    final startIndex = _catalogPage * _catalogPageSize;
    final endIndex = (startIndex + _catalogPageSize).clamp(0, _chapters.length);
    final pageChapters = _chapters.sublist(startIndex, endIndex);

    return Drawer(
      backgroundColor: _background.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '目录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _background.textColor,
                      ),
                    ),
                  ),
                  Text(
                    '共 ${_chapters.length} 章',
                    style: TextStyle(
                      fontSize: 12,
                      color: _background.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 页码控制
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: _background.textColor),
                    onPressed: _catalogPage > 0
                        ? () {
                            setState(() => _catalogPage--);
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Text(
                    '${_catalogPage + 1} / $totalPages',
                    style: TextStyle(fontSize: 13, color: _background.textColor),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: _background.textColor),
                    onPressed: _catalogPage < totalPages - 1
                        ? () {
                            setState(() => _catalogPage++);
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: pageChapters.length,
                itemBuilder: (context, i) {
                  final chapter = pageChapters[i];
                  final globalIndex = startIndex + i;
                  final isCurrent = globalIndex == _currentChapterIndex;
                  return ListTile(
                    dense: true,
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : _background.textColor,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _shouldJumpToLastPage = false;
                      setState(() => _currentChapterIndex = globalIndex);
                      _loadChapterContent(chapter);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('阅读设置', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('字体大小'),
                  const Spacer(),
                  IconButton.filledTonal(
                    icon: const Text('A-', style: TextStyle(fontSize: 12)),
                    onPressed: _fontSizeIndex > 0
                        ? () {
                            setModalState(() => _fontSizeIndex--);
                            setState(() {});
                            _saveSettings();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('${_fontSize.toInt()}', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton.filledTonal(
                    icon: const Text('A+', style: TextStyle(fontSize: 16)),
                    onPressed: _fontSizeIndex < _fontSizes.length - 1
                        ? () {
                            setModalState(() => _fontSizeIndex++);
                            setState(() {});
                            _saveSettings();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('行高'),
                  const Spacer(),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: _lineHeightIndex > 0
                        ? () {
                            setModalState(() => _lineHeightIndex--);
                            setState(() {});
                            _saveSettings();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_lineHeight.toStringAsFixed(1), style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: _lineHeightIndex < _lineHeights.length - 1
                        ? () {
                            setModalState(() => _lineHeightIndex++);
                            setState(() {});
                            _saveSettings();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('翻页模式'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: PageTurnMode.values.map((mode) {
                  final isSelected = _pageTurnMode == mode;
                  return ChoiceChip(
                    avatar: Icon(mode.icon, size: 18),
                    label: Text(mode.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => _pageTurnMode = mode);
                        setState(() {});
                        _saveSettings();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('字体'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ReaderFont.values.map((font) {
                  final isSelected = _font == font;
                  return ChoiceChip(
                    label: Text(font.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => _font = font);
                        setState(() {});
                        _saveSettings();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('背景'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ReaderBackground.values.map((bg) {
                  final isSelected = _background == bg;
                  return GestureDetector(
                    onTap: () {
                      setModalState(() => _background = bg);
                      setState(() {});
                      if (bg != ReaderBackground.dark) {
                        _lastDayBackground = bg;
                      }
                      _saveSettings();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: bg.bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: bg.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bg.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部常驻状态栏（始终显示）
  Widget _buildBottomStatusBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 总体进度条
          if (_chapters.isNotEmpty)
            LinearProgressIndicator(
              value: _readingProgress,
              backgroundColor: _background.textColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 2,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_currentTime  $_batteryLevel%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _background.textColor.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '${(_readingProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _background.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  /// 处理屏幕点击分区
  /// 分页模式（slide/cover/simulation）：
  ///   左侧30%：第一页则上一章，否则上一页
  ///   右侧30%：最后一页则下一章，否则下一页
  ///   中间40%：切换菜单
  /// 滚动模式（scroll）：
  ///   中间：切换菜单
  ///   左/右：无操作
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

  /// 构建顶部状态栏（始终显示，层级低）
  Widget _buildTopStatusBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: _background.textColor.withValues(alpha: 0.7),
              ),
              onPressed: () async {
                await _saveProgress();
                if (mounted) Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: '返回',
            ),
            Expanded(
              child: Text(
                _currentChapter?.title ?? widget.novel.title,
                style: TextStyle(
                  fontSize: 13,
                  color: _background.textColor.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部菜单（菜单显示时才显示，层级高）
  Widget _buildTopMenu() {
    return FadeTransition(
      opacity: _toolbarFadeAnimation,
      child: SlideTransition(
        position: _topToolbarSlideAnimation,
        child: Container(
          color: _background.bgColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.novel.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _background.textColor.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_currentChapter != null && _chapters.isNotEmpty)
                          Text(
                            '${_currentChapter!.title} · ${_currentChapterIndex + 1}/${_chapters.length}章${_hasStartedReading ? ' · 已读${_formatReadingDuration(_currentReadingDuration)}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _background.textColor.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isInBookshelf ? Icons.library_books : Icons.library_add_outlined,
                      color: _background.textColor,
                    ),
                    onPressed: _isInBookshelf ? null : _addToBookshelf,
                    tooltip: _isInBookshelf ? '已在书架' : '加入书架',
                  ),
                  IconButton(
                    icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _isBookmarked ? Theme.of(context).colorScheme.primary : _background.textColor,
                    ),
                    onPressed: _toggleBookmark,
                    tooltip: _isBookmarked ? '移除书签' : '添加书签',
                  ),
                  IconButton(
                    icon: Icon(
                      _isCollected ? Icons.favorite : Icons.favorite_border,
                      color: _isCollected ? Theme.of(context).colorScheme.error : _background.textColor,
                    ),
                    onPressed: () => _toggleCollection(),
                    tooltip: '收藏',
                  ),
                  IconButton(
                    icon: Icon(Icons.headphones_outlined, color: _background.textColor),
                    onPressed: _showTtsPanel,
                    tooltip: '听书',
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: _background.textColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: widget.novel)),
                      );
                    },
                    tooltip: '详情',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建底部悬浮工具栏
  Widget _buildBottomToolbar() {
    return FadeTransition(
      opacity: _toolbarFadeAnimation,
      child: SlideTransition(
        position: _bottomToolbarSlideAnimation,
        child: Container(
          color: _background.bgColor,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _background.textColor,
                              side: BorderSide(color: _background.textColor.withValues(alpha: 0.3)),
                            ),
                            child: const Text('上一章'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: FilledButton(
                            onPressed: _currentChapterIndex < _chapters.length - 1 ? _nextChapter : null,
                            child: const Text('下一章'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ToolbarButton(
                        icon: Icons.list_outlined,
                        label: '目录',
                        textColor: _background.textColor,
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      _ToolbarButton(
                        icon: Icons.bookmark_outline,
                        label: '书签',
                        textColor: _background.textColor,
                        onTap: _showBookmarkList,
                      ),
                      _ToolbarButton(
                        icon: Icons.comment_outlined,
                        label: '批注',
                        textColor: _background.textColor,
                        onTap: _showAnnotationList,
                      ),
                      _ToolbarButton(
                        icon: Icons.settings_outlined,
                        label: '设置',
                        textColor: _background.textColor,
                        onTap: _showSettings,
                      ),
                      _ToolbarButton(
                        icon: _background == ReaderBackground.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        label: _background == ReaderBackground.dark ? '日间' : '夜间',
                        textColor: _background.textColor,
                        onTap: () {
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveProgress();
        if (mounted) Navigator.of(context).pop();
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
    if (_pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式：GestureDetector 处理点击（菜单唤起），ScrollView 处理垂直滑动
      // onTap 和 onVerticalDrag 在手势竞技场中可以共存
      // 内容已在 SafeArea 内（顶部/底部状态栏已处理安全区域），不需要再加 mediaQuery.padding
      const topPadding = 12.0;
      const bottomPadding = 36.0;
      final textStyle = _getCachedTextStyle();
      return GestureDetector(
        onTapUp: _handleScreenTap,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      _currentChapter!.title,
                      style: _getCachedTextStyle(isTitle: true),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SelectableText.rich(
                  _buildAnnotatedTextSpan(
                    _currentChapter!.content,
                    textStyle,
                  ),
                  style: textStyle,
                  onSelectionChanged: (selection, cause) {
                    _selectedTextRange = selection;
                  },
                contextMenuBuilder: (context, editableTextState) {
                  final selected = _selectedTextRange;
                  final buttons = <Widget>[
                    ...editableTextState.contextMenuButtonItems.map(
                      (item) => CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onPressed: () {
                          editableTextState.hideToolbar();
                          item.onPressed?.call();
                        },
                        child: Text(item.label ?? ''),
                      ),
                    ),
                  ];
                  if (selected != null && selected.start != selected.end) {
                    final selectedText = _currentChapter!.content.substring(
                      selected.start.clamp(0, _currentChapter!.content.length),
                      selected.end.clamp(0, _currentChapter!.content.length),
                    );
                    buttons.add(
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onPressed: () {
                          editableTextState.hideToolbar();
                          _showAnnotationInputPanel(
                            selectedText,
                            selected.start,
                            selected.end,
                          );
                        },
                        child: const Text('添加批注'),
                      ),
                    );
                  }
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: editableTextState.contextMenuAnchors,
                    buttonItems: [
                      ...editableTextState.contextMenuButtonItems,
                      if (selected != null && selected.start != selected.end)
                        ContextMenuButtonItem(
                          label: '添加批注',
                          onPressed: () {
                            editableTextState.hideToolbar();
                            final selectedText = _currentChapter!.content.substring(
                              selected.start.clamp(0, _currentChapter!.content.length),
                              selected.end.clamp(0, _currentChapter!.content.length),
                            );
                            _showAnnotationInputPanel(
                              selectedText,
                              selected.start,
                              selected.end,
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  '${_currentChapter!.title} - 完',
                  style: TextStyle(fontSize: 14, color: _background.textColor.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    }

    // 仿真翻页模式：使用 SimulationPageView
    if (_pageTurnMode == PageTurnMode.simulation) {
      return _CurlChapterContent(
        key: _curlContentKey,
        chapter: _currentChapter!,
        background: _background,
        font: _font,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        onPageChanged: _onPageChanged,
        onBoundaryReached: _onPageBoundaryReached,
        onTapScreen: _handleScreenTap,
        jumpToLastPage: _shouldJumpToLastPage,
      );
    }

    // 分页模式（slide/cover）：使用 PageView
    return _PagedChapterContent(
      key: _pagedContentKey,
      chapter: _currentChapter!,
      background: _background,
      font: _font,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: _pageTurnMode,
      onPageChanged: _onPageChanged,
      onBoundaryReached: _onPageBoundaryReached,
      onTapScreen: _handleScreenTap,
      jumpToLastPage: _shouldJumpToLastPage,
    );
  }
}

/// 分页章节内容组件（slide/cover 模式）
class _PagedChapterContent extends StatefulWidget {
  final NovelChapterModel chapter;
  final ReaderBackground background;
  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final PageTurnMode pageTurnMode;
  final void Function(int currentPage, int totalPages) onPageChanged;
  final void Function(bool isLastPage) onBoundaryReached;
  /// 屏幕点击回调，由内容层统一处理点击区域逻辑
  final void Function(TapUpDetails details) onTapScreen;
  /// 是否跳转到最后一页（上一章时使用）
  final bool jumpToLastPage;

  const _PagedChapterContent({
    super.key,
    required this.chapter,
    required this.background,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.pageTurnMode,
    required this.onPageChanged,
    required this.onBoundaryReached,
    required this.onTapScreen,
    this.jumpToLastPage = false,
  });

  @override
  State<_PagedChapterContent> createState() => _PagedChapterContentState();
}

class _PagedChapterContentState extends State<_PagedChapterContent> {
  List<ContentPage> _pages = [];
  late PageController _pageController;
  bool _isCalculating = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculatePages();
  }

  @override
  void didUpdateWidget(covariant _PagedChapterContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有章节切换时才重置页签，字体/行高/背景调整不重置
    if (oldWidget.chapter.id != widget.chapter.id) {
      _calculatePages(resetPage: true);
    } else if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.font != widget.font) {
      _calculatePages(resetPage: false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 编程式翻到下一页
  void nextPage() {
    if (_pageController.hasClients && _pageController.page! < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// 编程式翻到上一页
  void previousPage() {
    if (_pageController.hasClients && _pageController.page! > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _calculatePages({bool resetPage = true}) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    // 顶部状态栏高度 = SafeArea top padding + 固定高度 44
    // 底部状态栏高度 = SafeArea bottom padding + 内部内容高度（进度条 ~2 + padding 20 = ~22）
    // 使用动态计算替代硬编码，避免在有安全区域的设备上出现内容截断
    final topStatusBarHeight = mediaQuery.padding.top + 44.0;
    final bottomStatusBarHeight = mediaQuery.padding.bottom + 24.0;
    final height = mediaQuery.size.height - topStatusBarHeight - bottomStatusBarHeight;

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      color: widget.background.textColor,
      letterSpacing: 0.5,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );

    // 计算首页标题占用的额外高度
    // 标题使用 Padding(bottom: 24) + Text(height: 1.6)
    final titleStyle = TextStyle(
      fontSize: widget.fontSize + 4,
      height: 1.6,
      fontWeight: FontWeight.bold,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );
    final titlePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: widget.chapter.title, style: titleStyle),
    )..layout(maxWidth: width - 40); // 减去左右 padding 20*2
    final titleLineCount = (titlePainter.computeLineMetrics()).length;
    // 标题实际高度 = 行数 * 行高 + Padding(bottom: 24)
    final firstPageExtraHeight = titleLineCount * (widget.fontSize + 4) * 1.6 + 24;

    final pages = TextPaginator.paginate(
      text: widget.chapter.content,
      width: width,
      height: height,
      style: textStyle,
      lineHeight: widget.lineHeight,
      // padding 必须与渲染 Container 的 padding 一致，否则分页器会多算可用高度导致内容被裁剪
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      firstPageExtraHeight: firstPageExtraHeight,
    );

    setState(() {
      _pages = pages;
      _isCalculating = false;
    });

    // 只有在明确需要重置页签时才跳转（如切换章节）
    // 菜单唤起、字体调整等操作不应重置页签
    if (resetPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          // 根据 jumpToLastPage 决定跳转到第一页还是最后一页
          final targetPage = widget.jumpToLastPage ? pages.length - 1 : 0;
          _pageController.jumpToPage(targetPage);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCalculating || _pages.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    // 使用 RawGestureDetector + GestureRecognizer 避免手势冲突
    // PageView 处理滑动手势，点击通过 behavior + onTapUp 处理
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: widget.onTapScreen,
      child: PageView.builder(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        itemCount: _pages.length,
        onPageChanged: (index) {
          widget.onPageChanged(index, _pages.length);
        },
        itemBuilder: (context, index) {
          final page = _pages[index];
          const topPadding = 12.0;
          const bottomPadding = 36.0;
          return Container(
            color: widget.background.bgColor,
            padding: const EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index == 0)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        widget.chapter.title,
                        style: TextStyle(
                          fontSize: widget.fontSize + 4,
                          fontWeight: FontWeight.bold,
                          color: widget.background.textColor,
                          height: 1.6,
                          fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    page.text,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      height: widget.lineHeight,
                      color: widget.background.textColor,
                      letterSpacing: 0.5,
                      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 仿真翻页章节内容组件（simulation 模式，使用 SimulationPageView）
class _CurlChapterContent extends StatefulWidget {
  final NovelChapterModel chapter;
  final ReaderBackground background;
  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final void Function(int currentPage, int totalPages) onPageChanged;
  final void Function(bool isLastPage) onBoundaryReached;
  /// 屏幕点击回调，由内容层统一处理点击区域逻辑
  final void Function(TapUpDetails details) onTapScreen;
  /// 是否跳转到最后一页（上一章时使用）
  final bool jumpToLastPage;

  const _CurlChapterContent({
    super.key,
    required this.chapter,
    required this.background,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.onPageChanged,
    required this.onBoundaryReached,
    required this.onTapScreen,
    this.jumpToLastPage = false,
  });

  @override
  State<_CurlChapterContent> createState() => _CurlChapterContentState();
}

class _CurlChapterContentState extends State<_CurlChapterContent> {
  List<ContentPage> _pages = [];
  late SimulationPageController _simulationController;
  bool _isCalculating = true;

  @override
  void initState() {
    super.initState();
    _simulationController = SimulationPageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculatePages();
  }

  @override
  void didUpdateWidget(covariant _CurlChapterContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有章节切换时才重置页签，字体/行高/背景调整不重置
    if (oldWidget.chapter.id != widget.chapter.id) {
      _calculatePages(resetPage: true);
    } else if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.font != widget.font) {
      _calculatePages(resetPage: false);
    }
  }

  @override
  void dispose() {
    _simulationController.detach();
    super.dispose();
  }

  /// 编程式翻到下一页
  void nextPage() {
    _simulationController.nextPage();
  }

  /// 编程式翻到上一页
  void previousPage() {
    _simulationController.previousPage();
  }

  void _calculatePages({bool resetPage = true}) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    // 顶部状态栏高度 = SafeArea top padding + 固定高度 44
    // 底部状态栏高度 = SafeArea bottom padding + 内部内容高度（进度条 ~2 + padding 20 = ~22）
    // 使用动态计算替代硬编码，避免在有安全区域的设备上出现内容截断
    final topStatusBarHeight = mediaQuery.padding.top + 44.0;
    final bottomStatusBarHeight = mediaQuery.padding.bottom + 24.0;
    final height = mediaQuery.size.height - topStatusBarHeight - bottomStatusBarHeight;

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      color: widget.background.textColor,
      letterSpacing: 0.5,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );

    // 计算首页标题占用的额外高度
    // 标题使用 Padding(bottom: 24) + Text(height: 1.6)
    final titleStyle = TextStyle(
      fontSize: widget.fontSize + 4,
      height: 1.6,
      fontWeight: FontWeight.bold,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );
    final titlePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: widget.chapter.title, style: titleStyle),
    )..layout(maxWidth: width - 40); // 减去左右 padding 20*2
    final titleLineCount = (titlePainter.computeLineMetrics()).length;
    // 标题实际高度 = 行数 * 行高 + Padding(bottom: 24)
    final firstPageExtraHeight = titleLineCount * (widget.fontSize + 4) * 1.6 + 24;

    final pages = TextPaginator.paginate(
      text: widget.chapter.content,
      width: width,
      height: height,
      style: textStyle,
      lineHeight: widget.lineHeight,
      // padding 必须与渲染 Container 的 padding 一致，否则分页器会多算可用高度导致内容被裁剪
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      firstPageExtraHeight: firstPageExtraHeight,
    );

    setState(() {
      _pages = pages;
      _isCalculating = false;
    });

    // 只有在明确需要重置页签时才跳转（如切换章节）
    // 菜单唤起、字体调整等操作不应重置页签
    if (resetPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // 根据 jumpToLastPage 决定跳转到第一页还是最后一页
          final targetPage = widget.jumpToLastPage ? pages.length - 1 : 0;
          _simulationController.jumpToPage(targetPage);
        }
      });
    }
  }

  /// 构建单页内容 Widget
  Widget _buildPageWidget(ContentPage page) {
    const topPadding = 12.0;
    const bottomPadding = 36.0;
    return Container(
      color: widget.background.bgColor,
      padding: const EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page.pageIndex == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  widget.chapter.title,
                  style: TextStyle(
                    fontSize: widget.fontSize + 4,
                    fontWeight: FontWeight.bold,
                    color: widget.background.textColor,
                    height: 1.6,
                    fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Expanded(
            child: Text(
              page.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                height: widget.lineHeight,
                color: widget.background.textColor,
                letterSpacing: 0.5,
                fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCalculating || _pages.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    // GestureDetector 处理点击翻页/菜单，SimulationPageView 处理滑动手势
    // onTap 和 onHorizontalDrag 在手势竞技场中可以共存
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: widget.onTapScreen,
      child: SimulationPageView(
        controller: _simulationController,
        backgroundColor: widget.background.bgColor,
        pages: _pages.map((page) => _buildPageWidget(page)).toList(),
        onPageChanged: (index) {
          widget.onPageChanged(index, _pages.length);
        },
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ),
    );
  }
}
