import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../../services/supabase_service.dart';
import '../../../services/chapter_cache_service.dart';
import '../../../services/api_client.dart';
import '../models/novel_model.dart';
import '../widgets/reader_page_turn.dart';
import 'novel_detail_screen.dart';

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
  ReaderFont _font = ReaderFont.serif;
  PageTurnMode _pageTurnMode = PageTurnMode.scroll;

  // 书架状态
  bool _isInBookshelf = false;
  bool _isCollected = false;
  String? _bookshelfId;

  // 防止重复触发下一章
  bool _hasTriggeredNextChapter = false;

  /// 标记是否需要跳转到最后一页（上一章时）
  bool _shouldJumpToLastPage = false;

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
    _saveProgress();
    _scrollController.dispose();
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
      final savedBg = prefs.getInt('reader_background') ?? 0;
      _background = ReaderBackground.values[savedBg.clamp(0, ReaderBackground.values.length - 1)];
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
    await prefs.setInt('reader_font', _font.index);
    await prefs.setInt('reader_page_turn_mode', _pageTurnMode.index);
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);

    try {
      // 并行加载章节列表和阅读进度
      final chaptersFuture = ApiClient.get(
        'novel_chapters',
        filters: {'novel_id': 'eq.${widget.novel.id}'},
        columns: 'id,title,chapter_num',
        order: 'chapter_num.asc',
        limit: 200,
      );

      final userId = _userId;
      Future<ApiResponse>? progressFuture;
      if (userId != null) {
        progressFuture = ApiClient.get(
          'user_novels',
          filters: {
            'user_id': 'eq.$userId',
            'novel_id': 'eq.${widget.novel.id}',
          },
          columns: 'last_chapter',
        );
      }

      final result = await chaptersFuture;

      if (result.isSuccess) {
        final data = result.data!;
        final chapters = data.map((json) => NovelChapterModel.fromJson(json)).toList();
        chapters.removeWhere((c) => c.chapterOrder <= 0);

        int startIndex = 0;
        for (int i = 0; i < chapters.length; i++) {
          if (chapters[i].chapterOrder >= widget.startChapter) {
            startIndex = i;
            break;
          }
        }

        // 并行获取阅读进度
        if (progressFuture != null) {
          try {
            final progressResult = await progressFuture;
            if (progressResult.isSuccess) {
              final progressData = progressResult.data!;
              if (progressData.isNotEmpty) {
                final savedChapter = progressData.first['last_chapter'] as int? ?? 1;
                for (int i = 0; i < chapters.length; i++) {
                  if (chapters[i].chapterOrder >= savedChapter) {
                    startIndex = i;
                    break;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('解析已读章节进度失败: $e');
          }
        }

        if (mounted) {
          setState(() {
            _chapters = chapters;
            _currentChapterIndex = startIndex;
            _isLoading = false;
          });
        }

        if (_chapters.isNotEmpty) {
          _loadChapterContent(_chapters[startIndex]);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载章节失败: $e')),
        );
      }
    }
  }

  Future<void> _loadChapterContent(NovelChapterModel chapter) async {
    setState(() => _isLoadingChapter = true);
    _hasTriggeredNextChapter = false;
    // 重置页码信息
    _currentPageIndex = 0;
    _totalPages = 1;

    try {
      // 先检查缓存，同时发起网络请求（并行加载）
      final cacheFuture = ChapterCacheService.instance.getCachedContent(chapter.id);
      final networkFuture = ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
      );

      // 等待缓存结果
      final cachedContent = await cacheFuture;
      if (cachedContent != null) {
        // 有缓存，先显示缓存内容
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (mounted) {
          setState(() {
            _currentChapter = NovelChapterModel(
              id: chapter.id,
              novelId: chapter.novelId,
              title: chapter.title,
              chapterOrder: chapter.chapterOrder,
              content: normalizedContent,
              createdAt: chapter.createdAt,
            );
            _isLoadingChapter = false;
          });
        }
        // 根据方向决定滚动位置：上一章到末尾，下一章到顶部
        _scrollToPosition();
        _saveProgress();
        _startReadingTimer();
        // 继续等待网络请求更新缓存
      }

      // 等待网络请求
      final result = await networkFuture;

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          final chapterData = data.first;
          final parsedChapter = NovelChapterModel.fromJson(chapterData);
          // 归一化换行符，避免 \r\n 导致渲染异常
          final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

          // 只有当网络内容比缓存新或不同才更新UI
          if (_currentChapter == null || _currentChapter!.content != normalizedContent) {
            if (mounted) {
              setState(() {
                _currentChapter = NovelChapterModel(
                  id: parsedChapter.id,
                  novelId: parsedChapter.novelId,
                  title: parsedChapter.title,
                  chapterOrder: parsedChapter.chapterOrder,
                  content: normalizedContent,
                  createdAt: parsedChapter.createdAt,
                );
                _isLoadingChapter = false;
              });
            }
            // 根据方向决定滚动位置
            _scrollToPosition();
            _saveProgress();
            _startReadingTimer();
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

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
    if (userId == null) return;

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
            _bookshelfId = data.first['id'] as String;
            _isCollected = data.first['is_collected'] as bool? ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('检查书架状态失败: $e');
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

      if (_isInBookshelf && _bookshelfId != null) {
        await ApiClient.patchByFilter(
          'user_novels',
          filters: {'id': 'eq.$_bookshelfId'},
          body: {
            'last_chapter': chapterNum,
            'progress': progress,
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
          if (mounted) {
            setState(() {
              _isInBookshelf = true;
              _bookshelfId = data['id'] as String;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('保存阅读进度失败: $e');
    }
  }

  Future<void> _addToBookshelf() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
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
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (mounted) {
          setState(() {
            _isInBookshelf = true;
            _bookshelfId = data['id'] as String;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已加入书架')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      // 标记需要跳转到最后一页（上一章）
      _shouldJumpToLastPage = true;
      setState(() {
        _currentChapterIndex--;
      });
      _loadChapterContent(_chapters[_currentChapterIndex]);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是第一章了')),
        );
      }
    }
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      // 标记需要跳转到第一页（下一章）
      _shouldJumpToLastPage = false;
      final nextIndex = _currentChapterIndex + 1;
      setState(() {
        _currentChapterIndex = nextIndex;
      });
      _loadChapterContent(_chapters[nextIndex]);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一章了')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一章了')),
        );
      }
    } else {
      // 到达第一页，跳转上一章
      if (_currentChapterIndex > 0) {
        _previousChapter();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是第一章了')),
        );
      }
    }
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('目录', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '${widget.novel.title} - 共 ${_chapters.length} 章',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  return ListTile(
                    dense: true,
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentChapterIndex = index);
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_currentTime  $_batteryLevel%',
              style: TextStyle(
                fontSize: 12,
                color: _background.textColor.withOpacity(0.5),
              ),
            ),
            Text(
              '${(_readingProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: _background.textColor.withOpacity(0.5),
              ),
            ),
          ],
        ),
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

  String get _progressText {
    return '${(_readingProgress * 100).toStringAsFixed(1)}%';
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
                color: _background.textColor.withOpacity(0.7),
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: '返回',
            ),
            Expanded(
              child: Text(
                _currentChapter?.title ?? widget.novel.title,
                style: TextStyle(
                  fontSize: 13,
                  color: _background.textColor.withOpacity(0.6),
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
          color: Colors.black.withOpacity(0.5),
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
                          _currentChapter?.title ?? widget.novel.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_chapters.isNotEmpty)
                          Text(
                            '${_currentChapterIndex + 1}/${_chapters.length}章 · $_progressText${_hasStartedReading ? ' · 已读${_formatReadingDuration(_currentReadingDuration)}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isInBookshelf ? Icons.library_books : Icons.library_add_outlined,
                      color: Colors.white,
                    ),
                    onPressed: _isInBookshelf ? null : _addToBookshelf,
                    tooltip: _isInBookshelf ? '已在书架' : '加入书架',
                  ),
                  IconButton(
                    icon: Icon(
                      _isCollected ? Icons.favorite : Icons.favorite_border,
                      color: _isCollected ? Theme.of(context).colorScheme.error : Colors.white,
                    ),
                    onPressed: () => _toggleCollection(),
                    tooltip: '收藏',
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
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
          color: Colors.black.withOpacity(0.5),
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
                              side: BorderSide(color: _background.textColor.withOpacity(0.3)),
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
                        onTap: _showChapterList,
                      ),
                      _ToolbarButton(
                        icon: Icons.text_fields,
                        label: '字体',
                        textColor: _background.textColor,
                        onTap: _showSettings,
                      ),
                      _ToolbarButton(
                        icon: _pageTurnMode.icon,
                        label: '翻页',
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
                            _background = _background == ReaderBackground.dark
                                ? ReaderBackground.white
                                : ReaderBackground.dark;
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
    return Scaffold(
      backgroundColor: _background.bgColor,
      appBar: null, // 始终不显示 AppBar
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _background.textColor.withOpacity(0.5)))
          : _currentChapter == null
              ? Center(child: Text('暂无章节', style: TextStyle(color: _background.textColor)))
              : Stack(
                  children: [
                    // 第1层：内容区域
                    Positioned.fill(
                      child: _isLoadingChapter
                          ? Center(child: CircularProgressIndicator(color: _background.textColor.withOpacity(0.5)))
                          : _buildContent(),
                    ),

                    // 第2层：顶部状态栏（始终显示）
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: _buildTopStatusBar(),
                    ),

                    // 第3层：底部状态栏（始终显示）
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: _buildBottomStatusBar(),
                    ),

                    // 第4层：顶部菜单（菜单显示时才显示，覆盖状态栏）
                    if (_showMenu)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: _buildTopMenu(),
                      ),

                    // 第5层：底部菜单（菜单显示时才显示，覆盖状态栏）
                    if (_showMenu)
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: _buildBottomToolbar(),
                      ),

                    // 第6层：进度条（菜单显示时才显示）
                    if (_chapters.isNotEmpty && _showMenu)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 44),
                          child: LinearProgressIndicator(
                            value: _readingProgress,
                            backgroundColor: _background.textColor.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _background == ReaderBackground.dark
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            minHeight: 3,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildContent() {
    if (_pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式：GestureDetector 处理点击（菜单唤起），ScrollView 处理垂直滑动
      // onTap 和 onVerticalDrag 在手势竞技场中可以共存
      return GestureDetector(
        onTapUp: _handleScreenTap,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _currentChapter!.title,
                    style: TextStyle(
                      fontSize: _fontSize + 4,
                      fontWeight: FontWeight.bold,
                      color: _background.textColor,
                      height: 1.6,
                      fontFamily: _font.fontFamily == 'system' ? null : _font.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Text(
                _currentChapter!.content,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: _lineHeight,
                  color: _background.textColor,
                  letterSpacing: 0.5,
                  fontFamily: _font.fontFamily == 'system' ? null : _font.fontFamily,
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  '${_currentChapter!.title} - 完',
                  style: TextStyle(fontSize: 14, color: _background.textColor.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 24),
            ],
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
    // 减去顶部状态栏(44) + 底部状态栏(~36) + 间距
    final topStatusBarHeight = 56.0; // 状态栏44 + 间距12
    final bottomStatusBarHeight = 48.0; // 状态栏~36 + 间距12
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
      // 垂直方向不额外加 padding，因为 Container 已经加了 padding
      // 水平方向保留 padding 用于文本宽度计算
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      firstPageExtraHeight: firstPageExtraHeight,
    );

    setState(() {
      _pages = pages;
      _isCalculating = false;
    });

    // 只有在明确需要重置页签时才跳转（如切换章节）
    // 菜单唤起、字体调整等操作不应重置页签
    if (resetPage && _pageController.hasClients) {
      // 根据 jumpToLastPage 决定跳转到第一页还是最后一页
      final targetPage = widget.jumpToLastPage ? pages.length - 1 : 0;
      _pageController.jumpToPage(targetPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCalculating || _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
          return Container(
            color: widget.background.bgColor,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 48),
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
    // 减去顶部状态栏(44) + 底部状态栏(~36) + 间距
    final topStatusBarHeight = 56.0; // 状态栏44 + 间距12
    final bottomStatusBarHeight = 48.0; // 状态栏~36 + 间距12
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
      // 垂直方向不额外加 padding，因为 Container 已经加了 padding
      // 水平方向保留 padding 用于文本宽度计算
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
    return Container(
      color: widget.background.bgColor,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 48),
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
      return const Center(child: CircularProgressIndicator());
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
