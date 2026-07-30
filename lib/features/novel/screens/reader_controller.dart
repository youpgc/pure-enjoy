// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/chapter_cache_service.dart';
import '../../../services/api_client.dart';
import '../../../core/utils/event_bus.dart';
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
import './reader_chapter_drawer.dart';
import './reader_panels.dart';

part 'reader_controller_meta.dart';
part 'reader_controller_content.dart';
part 'reader_controller_progress.dart';
part 'reader_controller_annotations.dart';
part 'reader_controller_settings.dart';
part 'reader_controller_navigation.dart';
part 'reader_controller_ui.dart';

/// 阅读器控制器（门面）：持有全部共享状态与生命周期，行为委托给独立模块类。
///
/// 架构：门面 + 模块协作者。共享 `_` 字段留在本类；行为按职责拆到同库 `part`
/// 文件中的独立模块类（各持 `_c` 指回本门面，同库内可访问私有字段）：
/// - ReaderMetaModule       章节元数据分页加载/刷新（reader_controller_meta.dart）
/// - ReaderContentModule    章节内容加载/预加载/滚动（reader_controller_content.dart）
/// - ReaderProgressModule   进度保存/阅读计时/书架收藏（reader_controller_progress.dart）
/// - ReaderAnnotationsModule 书签/划线标注（reader_controller_annotations.dart）
/// - ReaderSettingsModule   字号/行距/背景/字体设置（reader_controller_settings.dart）
/// - ReaderNavigationModule 翻页边界/章节切换（reader_controller_navigation.dart）
/// - ReaderUiModule         UI 构建 build/_build*（reader_controller_ui.dart）
///
/// 刷新机制：方法内的 `setState(...)` 已重命名为 `_setState(...)`，由 State 在
/// `bindState` 时注入 `(fn) => setState(fn)`，从而无需 `ChangeNotifier` 即可触发重建。
class ReaderController with WidgetsBindingObserver {
  final NovelModel novel;
  final int startChapter;
  final AnimationController _toolbarAnimationController;
  late final Animation<Offset> _topToolbarSlideAnimation;
  late final Animation<Offset> _bottomToolbarSlideAnimation;
  late final Animation<double> _toolbarFadeAnimation;

  BuildContext? _context;
  bool _disposed = false;
  // 由 State 注入的真实 setState（卸载后回退为空操作，避免对已 dispose 的 State 调用）
  void Function(VoidCallback) _setState = (fn) {};

  // ---- 视图/状态字段（原 mixin 字段，逐字保留）----
  final _scrollController = ScrollController();
  final _pagedContentKey = GlobalKey<PagedChapterContentState>();
  final _curlContentKey = GlobalKey<CurlChapterContentState>();

  final Battery _battery = Battery();
  int _batteryLevel = 100;

  List<NovelChapterModel> _chapters = [];
  NovelChapterModel? _currentChapter;
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  bool _isLoadingChapter = false;
  bool _showMenu = false;

  int _currentPageIndex = 0;
  int _totalPages = 1;

  int _restorePage = 0;
  DateTime? _lastBoundarySwitchAt;

  DateTime? _readingStartTime;
  Duration _totalReadingTime = Duration.zero;
  bool _hasStartedReading = false;

  static const List<double> _fontSizes = [12, 14, 16, 18, 20, 22, 24, 26, 28];
  int _fontSizeIndex = 4; // 默认 20
  double get _fontSize => _fontSizes[_fontSizeIndex];
  static const List<double> _lineHeights = [1.4, 1.6, 1.8, 2.0, 2.2];
  int _lineHeightIndex = 2; // 默认 1.8
  double get _lineHeight => _lineHeights[_lineHeightIndex];
  ReaderBackground _background = ReaderBackground.defaultWhite;
  ReaderBackground _lastDayBackground = ReaderBackground.defaultWhite;
  ReaderFont _font = ReaderFont.serif;
  PageTurnMode _pageTurnMode = PageTurnMode.scroll;

  bool _isInBookshelf = false;
  bool _isCollected = false;
  String? _bookshelfId;

  List<NovelBookmark> _bookmarks = [];
  List<NovelAnnotation> _annotations = [];
  bool _isTtsPlaying = false;

  DateTime? _chapterReadStartTime;

  bool _hasTriggeredPreload = false;
  double _overshootProgress = 0.0;
  bool _shouldJumpToLastPage = false;

  late final ReaderAnnotatedTextBuilder _annotatedTextBuilder;

  static final Map<int, TextStyle> _textStyleCache = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _fontStyleHash => Object.hash(_fontSize, _lineHeight, _background, _font);

  String? _loadingChapterId;

  bool _hasMoreChapters = true;
  bool _isLoadingMoreMeta = false;
  static const int _metaBatchSize = 50;

  final Completer<void> _bookshelfStatusCompleter = Completer<void>();

  // 模块协作者：各自承载一类职责（行为模块化，共享状态留在本门面）
  late final ReaderMetaModule meta;
  late final ReaderContentModule content;
  late final ReaderProgressModule progress;
  late final ReaderAnnotationsModule annotations;
  late final ReaderSettingsModule settings;
  late final ReaderNavigationModule navigation;
  late final ReaderUiModule ui;

  String? get _userId => AuthService.instance.currentUserId;

  ReaderController({
    required this.novel,
    required this.startChapter,
    required AnimationController toolbarAnimationController,
  }) : _toolbarAnimationController = toolbarAnimationController {
    meta = ReaderMetaModule(this);
    content = ReaderContentModule(this);
    progress = ReaderProgressModule(this);
    annotations = ReaderAnnotationsModule(this);
    settings = ReaderSettingsModule(this);
    navigation = ReaderNavigationModule(this);
    ui = ReaderUiModule(this);
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
    _scrollController.addListener(content._onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  void bindState(void Function(VoidCallback) fn, BuildContext context) {
    _setState = fn;
    _context = context;
  }

  void unbind() {
    _setState = (fn) {};
    _context = null;
  }

  /// 对外公开的构建入口（由薄 State 委托调用）
  Widget build(BuildContext context) => ui.build(context);

  void _safeSnack(String message) {
    final ctx = _context;
    if (ctx != null && !_disposed) showSnackBar(ctx, message);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      progress._saveProgress();
      progress._pauseReadingTimer();
    } else if (state == AppLifecycleState.resumed) {
      progress._resumeReadingTimer();
    }
  }

  Future<void> init() async {
    settings._loadSettings();
    meta._initializeReader();
    progress._checkBookshelfStatus();
    _battery.batteryLevel.then((level) {
      if (!_disposed) _setState(() => _batteryLevel = level);
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(content._onScroll);
    _scrollController.dispose();
    TtsService().dispose();
    // 退出阅读器时恢复系统 UI（与 init 中的 immersiveSticky 配对）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
