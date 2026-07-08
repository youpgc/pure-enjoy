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
part 'novel_reader_screen_logic.dart';


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

  // 渲染优化：带批注的 TextSpan 构建器
  late final ReaderAnnotatedTextBuilder _annotatedTextBuilder;

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveProgress();
        if (!mounted) return;
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
      onSelectionChanged: (selection) => _selectedTextRange = selection,
      onShowAnnotationInput: _showAnnotationInputPanel,
      getCachedTextStyle: _getCachedTextStyle,
    );
  }

}

