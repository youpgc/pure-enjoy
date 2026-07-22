// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:math' as math;
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
import '../widgets/reader_settings_panel.dart';
import '../widgets/reader/reader_widgets.dart';
import '../../../core/widgets/widgets.dart';
import 'reader_chapter_drawer.dart';
import 'reader_panels.dart';
import 'novel_reader_screen.dart';

mixin ReaderChapterLoaderMixin on State<NovelReaderScreen>, WidgetsBindingObserver, SingleTickerProviderStateMixin<NovelReaderScreen> {
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

  /// 入口恢复用的页内位置（来自 user_novels.last_page）。
  /// 仅在进入阅读器、加载首章时生效；_goToChapter 导航后重置为 0，
  /// 避免“下一章/上一章”误用旧页内位置。
  int _restorePage = 0;

  /// 边界切章防抖时间戳：OverscrollNotification/仿真翻页边界拖拽会在一次手势中
  /// 多次回调，缓存命中时切章几乎瞬时完成，若不防抖会连续跳过多个章节
  DateTime? _lastBoundarySwitchAt;

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

  // 6.1 新增：书签列表
  List<NovelBookmark> _bookmarks = [];

  // 6.1 新增：批注列表（当前章节）
  List<NovelAnnotation> _annotations = [];

  // 6.1 新增：TTS 状态
  bool _isTtsPlaying = false;

  // 6.1 新增：阅读历史定时器
  Timer? _readingHistoryTimer;
  DateTime? _chapterReadStartTime;

  // 防止重复触发预加载（70% 进度）
  bool _hasTriggeredPreload = false;

  // scroll 模式 overshoot 进度（-1.0 ~ 1.0，负表示向上/上一章，正表示向下/下一章）
  double _overshootProgress = 0.0;

  /// 标记是否需要跳转到最后一页（上一章时）
  bool _shouldJumpToLastPage = false;

  // 渲染优化：带批注的 TextSpan 构建器
  late final ReaderAnnotatedTextBuilder _annotatedTextBuilder;

  // 渲染优化：静态 TextStyle 缓存
  static final Map<int, TextStyle> _textStyleCache = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _fontStyleHash => Object.hash(_fontSize, _lineHeight, _background, _font);

  /// 当前正在加载的章节ID，用于防止快速切换时竞态条件（Bug 2 修复）
  String? _loadingChapterId;

  // 按需加载目录相关状态
  bool _hasMoreChapters = true;      // 是否还有更多章节目录未加载
  bool _isLoadingMoreMeta = false;   // 是否正在加载更多目录
  static const int _metaBatchSize = 50; // 每次加载目录的批次大小

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
    // 初始化阅读器（章节加载与书架检查并行）
    _initializeReader();
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

  /// 下拉刷新：加载前面未加载的章节（插入到列表头部）
  Future<void> _refreshChapterMeta() async {
    final firstOrder = _chapters.first.chapterOrder;
    final rangeStart = math.max(1, firstOrder - 50);
    final rangeEnd = firstOrder - 1;

    final result = await ApiClient.get(
      'novel_chapters',
      filters: {
        'novel_id': 'eq.${widget.novel.id}',
        'and': '(chapter_num.gte.$rangeStart,chapter_num.lte.$rangeEnd)',
      },
      columns: 'id,title,chapter_num',
      order: 'chapter_num.asc',
      limit: null, // 取消默认 limit=10
    );
    if (result.isSuccess && result.data != null && mounted) {
      final newChapters = result.data!
          .map((json) => NovelChapterModel.fromJson(json))
          .toList();
      newChapters.removeWhere((c) => c.chapterOrder <= 0);
      if (newChapters.isNotEmpty) {
        setState(() {
          // 插入到列表头部
          _chapters.insertAll(0, newChapters);
          // 更新当前章节索引（因为前面插入了新章节）
          _currentChapterIndex += newChapters.length;
        });
      }
    }
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

  /// 使用小说总章节数计算阅读进度（而非已加载章节数）
  double get _readingProgress {
    final total = widget.novel.chapterCount;
    if (total <= 0) return 0;
    final currentOrder = _currentChapter?.chapterOrder ?? _currentChapterIndex + 1;
    return currentOrder / total;
  }

  /// 总章节数（优先使用小说元数据）
  int get _totalChapterCount {
    final novelCount = widget.novel.chapterCount;
    return novelCount > 0 ? novelCount : _chapters.length;
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
      chapterCount: _totalChapterCount,
      hasStartedReading: _hasStartedReading,
      currentReadingDuration: _currentReadingDuration,
      isCollected: _isCollected,
      onBack: () => Navigator.pop(context),
      onToggleCollection: _toggleCollection,
      onShowTtsPanel: () => showReaderTtsPanel(
        context,
        isPlaying: _isTtsPlaying,
        onPlayStateChanged: (playing) => setState(() => _isTtsPlaying = playing),
        novelId: widget.novel.id,
        chapterId: _currentChapter?.id ?? '',
        chapterContent: _currentChapter?.content ?? '',
      ),
    );
  }

  /// 构建底部悬浮工具栏
  Widget _buildBottomToolbar() {
    return ReaderBottomToolbar(
      fadeAnimation: _toolbarFadeAnimation,
      slideAnimation: _bottomToolbarSlideAnimation,
      background: _background,
      currentChapterIndex: _currentChapterIndex,
      chapterCount: _totalChapterCount,
      onPreviousChapter: _previousChapter,
      onNextChapter: _nextChapter,
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      onShowBookmarkList: () => showReaderBookmarkList(
        context,
        bookmarks: _bookmarks,
        currentChapter: _currentChapter,
        onBookmarkTap: _jumpToBookmark,
      ),
      onShowAnnotationList: () => showReaderAnnotationList(
        context,
        annotations: _annotations,
        onDelete: _deleteAnnotation,
      ),
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

  /// 初始化阅读器：统一入口，避免重复加载
  /// 优化策略：
  /// 1. 先确定目标章节号（如需查询阅读进度），避免用错误范围查询章节列表
  /// 2. 消除额外的 _loadMoreChapterMeta 串行调用
  /// 3. 并行加载当前章 + 前后各1章内容
  Future<void> _initializeReader() async {
    setState(() => _isLoading = true);

    try {
      final userId = _userId;
      int targetChapterNum = widget.startChapter;

      // 1. 先确定目标章节号：如果需要查询阅读进度，先等待结果
      // 避免用错误的初始范围查询章节列表，导致后续额外的 _loadMoreChapterMeta 调用
      if (targetChapterNum <= 0 && userId != null) {
        final progressResult = await ApiClient.get(
          'user_novels',
          filters: {
            'user_id': 'eq.$userId',
            'novel_id': 'eq.${widget.novel.id}',
          },
          columns: 'last_chapter,last_page',
          // 按最近阅读时间倒序取最新一行，防御重复行(data.first 取到旧行导致定位很早以前)
          // nullslast：避免 last_read_at 为 NULL 的行被优先取到（DESC 默认 NULLS FIRST）
          order: 'last_read_at.desc.nullslast',
          limit: 1,
        );
        if (progressResult.isSuccess &&
            progressResult.data != null &&
            progressResult.data!.isNotEmpty) {
          final row = progressResult.data!.first;
          targetChapterNum = row['last_chapter'] as int? ?? 1;
          // 记录页内位置，供首章显示时恢复到该页（导航后由 _goToChapter 重置为 0）
          _restorePage = (row['last_page'] as int? ?? 0).clamp(0, 1000000);
        }
        if (targetChapterNum <= 0) targetChapterNum = 1;
      }

      // 2. 使用正确的章节号范围查询章节列表
      final rangeStart = math.max(1, targetChapterNum - 25);
      final rangeEnd = targetChapterNum + 25;

      final chaptersResult = await ApiClient.get(
        'novel_chapters',
        filters: {
          'novel_id': 'eq.${widget.novel.id}',
          'and': '(chapter_num.gte.$rangeStart,chapter_num.lte.$rangeEnd)',
        },
        columns: 'id,title,chapter_num',
        order: 'chapter_num.asc',
        limit: null, // 取消默认 limit=10，按范围查询全部章节
      );

      final allChapters = <NovelChapterModel>[];
      if (chaptersResult.isSuccess && chaptersResult.data != null) {
        allChapters.addAll(
          chaptersResult.data!.map((json) => NovelChapterModel.fromJson(json)),
        );
      }
      allChapters.removeWhere((c) => c.chapterOrder <= 0);

      _hasMoreChapters = allChapters.length >= 50;

      // 找到当前章节索引
      int startIndex = 0;
      for (int i = 0; i < allChapters.length; i++) {
        if (allChapters[i].chapterOrder >= targetChapterNum) {
          startIndex = i;
          break;
        }
      }

      _chapters = allChapters;

      // 如果目标章超出已加载范围（小说实际章节数小于目标值），定位到最后一章
      // 避免触发额外的 _loadMoreChapterMeta 串行请求
      if (startIndex == 0 &&
          allChapters.isNotEmpty &&
          targetChapterNum > allChapters.last.chapterOrder) {
        startIndex = allChapters.length - 1;
      }

      if (mounted) {
        setState(() {
          _currentChapterIndex = startIndex;
          _isLoading = false;
        });
      }

      // 并行加载当前章 + 前后各1章内容
      if (_chapters.isNotEmpty) {
        final current = _chapters[startIndex];
        final futures = <Future<void>>[_loadChapterContent(current)];

        if (startIndex > 0) {
          futures.add(_fetchChapterContent(_chapters[startIndex - 1]));
        }
        if (startIndex < _chapters.length - 1) {
          futures.add(_fetchChapterContent(_chapters[startIndex + 1]));
        }

        await Future.wait(futures);
        _preloadAdjacentChapters(startIndex);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('初始化阅读器失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, '加载章节失败，请稍后重试');
      }
    }
  }

  /// 按需加载更多章节目录
  /// [targetChapterNum] 可选，如果需要加载到包含特定章节号的位置
  /// 使用键集分页（chapter_num 游标）替代 offset，避免深度分页性能衰减
  Future<void> _loadMoreChapterMeta({int? targetChapterNum}) async {
    if (_isLoadingMoreMeta) return;
    if (!_hasMoreChapters && targetChapterNum == null) return;

    setState(() => _isLoadingMoreMeta = true);

    try {
      // 获取当前已加载的最大章节号作为游标
      final lastChapterNum = _chapters.isNotEmpty ? _chapters.last.chapterOrder : 0;

      // 如果指定了目标章节号且已在范围内，无需加载
      if (targetChapterNum != null && targetChapterNum <= lastChapterNum) {
        setState(() => _isLoadingMoreMeta = false);
        return;
      }

      // 键集分页：以上一批最后一条 chapter_num 为起点
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {
          'novel_id': 'eq.${widget.novel.id}',
          'chapter_num': 'gt.$lastChapterNum',
        },
        columns: 'id,title,chapter_num',
        order: 'chapter_num.asc',
        limit: _metaBatchSize,
      );

      if (result.isSuccess && result.data != null) {
        final newChapters = result.data!
            .map((json) => NovelChapterModel.fromJson(json))
            .toList();
        newChapters.removeWhere((c) => c.chapterOrder <= 0);

        if (mounted) {
          setState(() {
            _chapters.addAll(newChapters);
            _hasMoreChapters = newChapters.length >= _metaBatchSize;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('加载更多目录失败: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMoreMeta = false);
    }
  }

  /// 确保目标章节索引在已加载的目录范围内
  Future<void> _ensureChapterMetaLoaded(int targetIndex) async {
    while (targetIndex >= _chapters.length && _hasMoreChapters && !_isLoadingMoreMeta) {
      await _loadMoreChapterMeta();
    }
  }

  /// 跳转到指定章节索引（公共逻辑）
  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;

    final isNext = index > _currentChapterIndex;
    _shouldJumpToLastPage = !isNext;
    _hasTriggeredPreload = false;
    _overshootProgress = 0.0;

    setState(() {
      _currentChapterIndex = index;
      // 导航切章不再复用入口恢复页，避免误定位到旧页内位置
      _restorePage = 0;
    });

    _loadChapterContent(_chapters[index]);
    _preloadAdjacentChapters(index);
  }

  Future<void> _loadChapterContent(NovelChapterModel chapter) async {
    // 记录当前加载的章节ID，用于防止竞态条件（Bug 2 修复）
    _loadingChapterId = chapter.id;
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
      // 后台静默更新（如果缓存过期）
      _silentRefreshChapter(chapter);
      return;
    }

    // 设置当前保护章节（内存压力时不清理）
    ChapterCacheService.instance.setProtectedChapter(chapter.id);

    try {
      // 2. 检查本地缓存（L1/L2）
      final cachedContent = await ChapterCacheService.instance.getCachedContent(chapter.id);

      // 检查是否已切换到其他章节
      if (_loadingChapterId != chapter.id) return;

      if (cachedContent != null) {
        // 缓存命中：立即显示缓存内容，不显示loading（无感切换）
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
        _scrollToPosition();
        _saveProgress();
        _startReadingTimer();
        _checkBookmarkStatus();
        _chapterReadStartTime = DateTime.now();

        // 缓存过期时在后台静默刷新
        if (!ChapterCacheService.instance.isCacheFresh(chapter.id)) {
          _silentRefreshChapter(chapter);
        }
        return;
      }

      // 3. 无缓存：显示loading并发起网络请求
      if (mounted) {
        setState(() => _isLoadingChapter = true);
      }

      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      // 再次检查是否已切换到其他章节（Bug 2 核心修复）
      if (_loadingChapterId != chapter.id) return;

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final chapterData = result.data!.first;
        final parsedChapter = NovelChapterModel.fromJson(chapterData);
        final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

        final loadedChapter = parsedChapter.copyWith(content: normalizedContent);
        final loadedIndex = _chapters.indexWhere((c) => c.id == parsedChapter.id);
        if (loadedIndex != -1) {
          _chapters[loadedIndex] = loadedChapter;
        }

        if (mounted) {
          setState(() {
            _currentChapter = loadedChapter;
            _isLoadingChapter = false;
          });
        }
        _scrollToPosition();
        _saveProgress();
        _startReadingTimer();
        _checkBookmarkStatus();
        _chapterReadStartTime = DateTime.now();

        if (normalizedContent.isNotEmpty) {
          ChapterCacheService.instance.cacheChapter(
            chapterId: parsedChapter.id,
            novelId: widget.novel.id,
            title: parsedChapter.title,
            chapterOrder: parsedChapter.chapterOrder,
            content: normalizedContent,
          );
        }
      } else {
        // 网络请求失败且无任何缓存：降级显示空内容章节
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
      if (mounted) {
        setState(() {
          _currentChapter = chapter;
          _isLoadingChapter = false;
        });
      }
      _scrollToPosition();
    }
  }

  /// 后台静默刷新章节内容（不显示loading，不阻塞阅读）
  Future<void> _silentRefreshChapter(NovelChapterModel chapter) async {
    try {
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      if (_loadingChapterId != chapter.id) return;

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final chapterData = result.data!.first;
        final parsedChapter = NovelChapterModel.fromJson(chapterData);
        final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

        // 只有当内容确实变化时才更新UI
        final currentIndex = _chapters.indexWhere((c) => c.id == chapter.id);
        if (currentIndex != -1) {
          final oldContent = _chapters[currentIndex].content;
          _chapters[currentIndex] = parsedChapter.copyWith(content: normalizedContent);

          // 如果当前正在显示此章节且内容有变化，无感更新
          if (_currentChapter?.id == chapter.id && oldContent != normalizedContent) {
            if (mounted) {
              setState(() {
                _currentChapter = _chapters[currentIndex];
              });
            }
          }
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
      if (kDebugMode) debugPrint('静默刷新章节失败: ${chapter.title}');
    }
  }

  /// 静默预加载单个章节内容（不显示 loading，不影响当前章节）
  /// 优化：缓存命中时立即返回，不阻塞等待网络请求
  Future<void> _fetchChapterContent(NovelChapterModel chapter) async {
    // 已加载则跳过
    final idx = _chapters.indexWhere((c) => c.id == chapter.id);
    if (idx != -1 && _chapters[idx].content.isNotEmpty) return;

    try {
      // 优先检查缓存：缓存命中时立即使用，不等待网络
      final cachedContent = await ChapterCacheService.instance.getCachedContent(chapter.id);
      if (cachedContent != null) {
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (idx != -1) {
          _chapters[idx] = chapter.copyWith(content: normalizedContent);
        }
        return; // 缓存命中：直接返回，不阻塞等待网络刷新
      }

      // 缓存未命中：等待网络请求
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
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

  /// 检测网络环境（简化实现，默认非WiFi）
  Future<bool> _isWifiConnected() async {
    // 如需精确检测，可接入 connectivity_plus 包
    return false;
  }

  /// 智能预加载：根据网络环境决定预加载数量
  /// WiFi 环境下预加载前后各2章（共4章），蜂窝网络下预加载前后各1章（共2章）
  void _preloadAdjacentChapters(int index) async {
    _hasTriggeredPreload = false;

    // 检测网络环境（简单判断：如果有WiFi则多加载）
    final isWifi = await _isWifiConnected();
    final preloadCount = isWifi ? 2 : 1;

    final preloadIds = <String>[];

    // 预加载后续章节
    for (int i = index + 1; i < _chapters.length && preloadIds.length < preloadCount; i++) {
      final chapter = _chapters[i];
      if (chapter.content.isEmpty) {
        preloadIds.add(chapter.id);
      }
    }

    // 预加载前面章节
    for (int i = index - 1; i >= 0 && preloadIds.length < preloadCount * 2; i--) {
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
    if (_pageTurnMode != PageTurnMode.scroll) return;
    // 延迟到下一帧执行，避免与正在进行的 BallisticScrollActivity 冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        if (_shouldJumpToLastPage) {
          // 上一章：跳转到末尾
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          // 下一章：跳转到顶部
          _scrollController.jumpTo(0);
        }
      } catch (_) {
        // 忽略滚动中断异常
      }
    });
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

    // 注意：章节切换现在由 overscroll 手势触发（_handleScrollOvershoot），
    // 不再基于滚动位置自动触发，以便用户能明确控制切换时机。
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
      final totalChapters = _totalChapterCount;
      final progress = totalChapters > 0 ? chapterNum / totalChapters : 0.0;

      // 并行执行：记录阅读历史 + 保存阅读进度（两者无依赖关系）
      final historyFuture = _recordReadingHistory(progress);

      // 保存阅读进度到 user_novels
      Future<void> progressFuture;
      if (_isInBookshelf && _bookshelfId != null) {
        progressFuture = _saveReadingProgress(progress: progress, chapterNum: chapterNum);
      } else {
        // 等待书架状态检查完成，避免重复创建记录（Bug 3 修复）
        progressFuture = () async {
          if (!_bookshelfStatusCompleter.isCompleted) {
            await _bookshelfStatusCompleter.future;
          }
          if (_isInBookshelf && _bookshelfId != null) {
            await _saveReadingProgress(progress: progress, chapterNum: chapterNum);
          } else {
            // 二次确认是否已有记录：阅读时自动建行与“加入书架”建行存在竞态，
            // 可能已存在 (user_id, novel_id) 行。若已存在则复用并 PATCH，
            // 避免重复创建导致入口读 data.first 取到旧行（定位到很早以前）。
            final existing = await ApiClient.get(
              'user_novels',
              filters: {
                'user_id': 'eq.$userId',
                'novel_id': 'eq.${widget.novel.id}',
              },
              columns: 'id',
              order: 'last_read_at.desc.nullslast',
              limit: 1,
            );
            if (existing.isSuccess &&
                existing.data != null &&
                existing.data!.isNotEmpty) {
              final id = existing.data!.first['id'].toString();
              if (mounted) {
                setState(() {
                  _isInBookshelf = true;
                  _bookshelfId = id;
                });
              }
              await _saveReadingProgress(progress: progress, chapterNum: chapterNum);
            } else {
              final result = await ApiClient.post(
                'user_novels',
                {
                  'user_id': userId,
                  'novel_id': widget.novel.id,
                  'progress': progress,
                  'last_chapter': chapterNum,
                  'last_page': _currentPageIndex,
                  'is_collected': true,
                  'reading_status': progress >= 1.0 ? 'finished' : 'reading',
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
                    _isCollected = true;
                  });
                }
              }
            }
          }
        }();
      }

      // 等待两个并行任务完成
      await Future.wait([historyFuture, progressFuture]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('保存阅读进度失败');
      }
    }
  }

  /// 6.1 新增：记录阅读历史明细
  /// 保存阅读进度到 user_novels（检查返回值，失败时静默记录日志）
  Future<void> _saveReadingProgress({
    required double progress,
    required int chapterNum,
  }) async {
    final result = await ApiClient.patchByFilter(
      'user_novels',
      filters: {'id': 'eq.$_bookshelfId'},
      body: {
        'last_chapter': chapterNum,
        'progress': progress,
        'last_page': _currentPageIndex,
        'is_collected': true,
        'reading_status': progress >= 1.0 ? 'finished' : 'reading',
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!result.isSuccess && kDebugMode) {
      debugPrint('阅读进度保存失败: ${result.error}');
    }
  }

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

    // 并行加载书签列表和批注，避免串行请求延迟
    final bookmarkFuture = BookmarkService().getBookmarks(widget.novel.id);
    final annotationFuture = _loadAnnotations();

    final bookmarks = await bookmarkFuture;
    await annotationFuture;

    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
      });
    }
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

  /// 6.1 新增：跳转到书签位置（支持字符偏移）
  void _jumpToBookmark(NovelBookmark bookmark) {
    // 安全查找：按 chapterOrder 匹配，避免数组越界
    final index = _chapters.indexWhere((c) => c.chapterOrder == bookmark.chapterOrder);
    if (index == -1) {
      if (mounted) showSnackBar(context, '该章节尚未加载，请稍后再试');
      return;
    }
    _loadChapterContent(_chapters[index]);
    // 章节加载完成后，滚动到字符偏移位置
    if (bookmark.charOffset > 0 && _pageTurnMode == PageTurnMode.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || _currentChapter == null) return;
        final content = _currentChapter!.content;
        final ratio = bookmark.charOffset / content.length;
        final targetOffset = ratio * _scrollController.position.maxScrollExtent;
        try {
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (_) {
          // 忽略滚动中断异常
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
  Future<void> _deleteAnnotation(NovelAnnotation annotation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认删除',
      content: '确定要删除这条批注吗？',
    );
    if (!confirmed) return;
    try {
      await AnnotationService().deleteAnnotation(annotation.id);
      setState(() {
        _annotations.removeWhere((a) => a.id == annotation.id);
      });
      if (mounted) showSnackBar(context, '批注已删除'); // ignore: use_build_context_synchronously
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败'); // ignore: use_build_context_synchronously
    }
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
        showSnackBar(context, '操作失败，请稍后重试');
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
        showSnackBar(context, '操作失败，请稍后重试');
      }
    }
  }

  void _previousChapter() {
    final prevIndex = _currentChapterIndex - 1;

    if (prevIndex >= 0) {
      _goToChapter(prevIndex);
    } else {
      if (mounted) showSnackBar(context, '已经是第一章了');
    }
  }

  void _nextChapter() {
    final nextIndex = _currentChapterIndex + 1;

    if (nextIndex < _chapters.length) {
      _goToChapter(nextIndex);
    } else if (_hasMoreChapters) {
      // 还有更多章节未加载，先加载更多目录
      _ensureChapterMetaLoaded(nextIndex).then((_) {
        if (nextIndex < _chapters.length) {
          _goToChapter(nextIndex);
        } else {
          if (mounted) showSnackBar(context, '已经是最后一章了');
        }
      });
    } else {
      if (mounted) showSnackBar(context, '已经是最后一章了');
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
    // 防抖：一次滑动手势中边界回调可能连续触发多次，
    // 700ms 内只处理一次，避免连续切换跳过多个章节
    final now = DateTime.now();
    if (_lastBoundarySwitchAt != null &&
        now.difference(_lastBoundarySwitchAt!).inMilliseconds < 700) {
      return;
    }
    _lastBoundarySwitchAt = now;

    if (isLastPage) {
      // 到达最后一页，跳转下一章
      if (_currentChapterIndex < _chapters.length - 1 || _hasMoreChapters) {
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

  /// scroll 模式 overshoot 达到阈值时触发章节切换
  void _handleScrollOvershoot(bool isEnd) {
    if (_pageTurnMode != PageTurnMode.scroll) return;
    if (_isLoadingChapter) return;

    if (isEnd) {
      if (_currentChapterIndex < _chapters.length - 1 || _hasMoreChapters) {
        _nextChapter();
      } else {
        showSnackBar(context, '已经是最后一章了');
      }
    } else {
      if (_currentChapterIndex > 0) {
        _previousChapter();
      } else {
        showSnackBar(context, '已经是第一章了');
      }
    }
  }

  /// 更新 overshoot 进度，用于显示视觉指示器
  void _handleScrollOvershootProgress(double progress) {
    if (_pageTurnMode != PageTurnMode.scroll) return;
    if (_overshootProgress == progress) return;
    setState(() {
      _overshootProgress = progress;
    });
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
      // 滚动模式下点击任意位置唤起/关闭菜单
      _toggleMenu();
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
      drawer: ReaderChapterDrawerWidget(
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        background: _background,
        totalChapterCount: _totalChapterCount,
        hasMoreChapters: _hasMoreChapters,
        isLoadingMore: _isLoadingMoreMeta,
        onCloseDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        onChapterTap: (globalIndex, chapter) {
          _shouldJumpToLastPage = false;
          setState(() => _currentChapterIndex = globalIndex);
          _loadChapterContent(chapter);
        },
        onLoadMore: () => _loadMoreChapterMeta(),
        onRefresh: _chapters.isNotEmpty && _chapters.first.chapterOrder > 1
            ? _refreshChapterMeta
            : null,
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : Stack(
              children: [
                // Column 布局：顶部状态栏 → 内容铺满 → 底部状态栏
                Column(
                  children: [
                    // 顶部信息栏
                    _buildTopStatusBar(),
                    // 小说内容（铺满中间剩余空间）
                    // 优先显示已有内容，无缓存且正在加载时才显示loading
                    Expanded(
                      child: (_isLoadingChapter && _currentChapter == null)
                          ? const Center(child: LoadingWidget())
                          : _buildContent(),
                    ),
                    // 底部状态栏
                    _buildBottomStatusBar(),
                  ],
                ),

                // scroll 模式 overshoot 视觉指示器
                if (_pageTurnMode == PageTurnMode.scroll && _overshootProgress != 0)
                  Positioned(
                    top: _overshootProgress < 0 ? 0 : null,
                    bottom: _overshootProgress > 0 ? 0 : null,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: _overshootProgress.abs().clamp(0.0, 1.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _overshootProgress < 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              color: _background.textColor.withValues(alpha: 0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _overshootProgress < 0 ? '释放切换到上一章' : '释放切换到下一章',
                              style: TextStyle(
                                color: _background.textColor.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
        startPage: _restorePage,
        scrollController: _scrollController,
        buildAnnotatedTextSpan: _buildAnnotatedTextSpan,
        onShowAnnotationInput: (selectedText, startOffset, endOffset) =>
            showReaderAnnotationInput(
          context,
          selectedText,
          startOffset,
          endOffset,
          onSave: (selectedText, startOffset, endOffset, note, color) =>
              _addAnnotation(
            selectedText: selectedText,
            startOffset: startOffset,
            endOffset: endOffset,
            note: note,
            color: color,
          ),
        ),
        getCachedTextStyle: _getCachedTextStyle,
        onScrollOvershoot: _handleScrollOvershoot,
        onScrollOvershootProgress: _handleScrollOvershootProgress,
      );
    }
}
