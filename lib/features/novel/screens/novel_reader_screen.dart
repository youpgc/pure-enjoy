import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config.dart';
import '../../../services/supabase_service.dart';
import '../../../services/chapter_cache_service.dart';
import '../models/novel_model.dart';
import '../widgets/reader_page_turn.dart';
import 'novel_detail_screen.dart';

/// 背景主题枚举
enum ReaderBackground {
  white('白色', Colors.white, Colors.black87),
  yellow('护眼黄', Color(0xFFF5E6C8), Color(0xFF5C4B37)),
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
  int _fontSizeIndex = 3; // 默认 18
  double get _fontSize => _fontSizes[_fontSizeIndex];
  static const List<double> _lineHeights = [1.4, 1.6, 1.8, 2.0, 2.2];
  int _lineHeightIndex = 2; // 默认 1.8
  double get _lineHeight => _lineHeights[_lineHeightIndex];
  ReaderBackground _background = ReaderBackground.white;
  ReaderFont _font = ReaderFont.system;
  PageTurnMode _pageTurnMode = PageTurnMode.scroll;

  // 书架状态
  bool _isInBookshelf = false;
  bool _isCollected = false;
  String? _bookshelfId;

  // 防止重复触发下一章
  bool _hasTriggeredNextChapter = false;

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
      final chaptersFuture = http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/novel_chapters?novel_id=eq.${widget.novel.id}&select=id,title,chapter_num&order=chapter_num.asc',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      final userId = _userId;
      Future<http.Response>? progressFuture;
      if (userId != null) {
        progressFuture = http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/user_novels?user_id=eq.$userId&novel_id=eq.${widget.novel.id}&select=last_chapter',
          ),
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          },
        );
      }

      final response = await chaptersFuture;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
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
            final progressResponse = await progressFuture;
            if (progressResponse.statusCode == 200) {
              final progressData = jsonDecode(progressResponse.body);
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

        setState(() {
          _chapters = chapters;
          _currentChapterIndex = startIndex;
          _isLoading = false;
        });

        if (_chapters.isNotEmpty) {
          _loadChapterContent(_chapters[startIndex]);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
      final networkFuture = http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/novel_chapters?id=eq.${chapter.id}&select=*',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      // 等待缓存结果
      final cachedContent = await cacheFuture;
      if (cachedContent != null) {
        // 有缓存，先显示缓存内容
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
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
        _scrollToTop();
        _saveProgress();
        _startReadingTimer();
        // 继续等待网络请求更新缓存
      }

      // 等待网络请求
      final response = await networkFuture;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final chapterData = data.first;
          final parsedChapter = NovelChapterModel.fromJson(chapterData);
          // 归一化换行符，避免 \r\n 导致渲染异常
          final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

          // 只有当网络内容比缓存新或不同才更新UI
          if (_currentChapter == null || _currentChapter!.content != normalizedContent) {
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
            _scrollToTop();
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
          setState(() {
            _currentChapter = chapter;
            _isLoadingChapter = false;
          });
          _scrollToTop();
        }
      } else if (_currentChapter == null) {
        setState(() {
          _currentChapter = chapter;
          _isLoadingChapter = false;
        });
        _scrollToTop();
      }
    } catch (e) {
      if (_currentChapter == null) {
        setState(() {
          _currentChapter = chapter;
          _isLoadingChapter = false;
        });
        _scrollToTop();
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/user_novels?user_id=eq.$userId&novel_id=eq.${widget.novel.id}&select=id,is_collected',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
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
        await http.patch(
          Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_novels?id=eq.$_bookshelfId'),
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'last_chapter': chapterNum,
            'progress': progress,
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      } else {
        final response = await http.post(
          Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_novels'),
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'user_id': userId,
            'novel_id': widget.novel.id,
            'progress': progress,
            'last_chapter': chapterNum,
            'is_collected': true,
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final List<dynamic> data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _isInBookshelf = true;
              _bookshelfId = data.first['id'] as String;
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
      final response = await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_novels'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'user_id': userId,
          'novel_id': widget.novel.id,
          'progress': 0,
          'last_chapter': _currentChapter?.chapterOrder ?? 1,
          'is_collected': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _isInBookshelf = true;
          _bookshelfId = data.first['id'] as String;
        });
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
      final response = await http.patch(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_novels?id=eq.$_bookshelfId'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'is_collected': !_isCollected}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
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

  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
    if (_showMenu) {
      _toolbarAnimationController.forward();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      _toolbarAnimationController.reverse();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  double get _readingProgress {
    if (_chapters.isEmpty) return 0;
    return (_currentChapterIndex + 1) / _chapters.length;
  }

  String get _progressText {
    return '${(_readingProgress * 100).toStringAsFixed(1)}%';
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

  /// 构建顶部悬浮工具栏
  Widget _buildTopToolbar() {
    return FadeTransition(
      opacity: _toolbarFadeAnimation,
      child: SlideTransition(
        position: _topToolbarSlideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _background.bgColor.withOpacity(0.95),
                _background.bgColor.withOpacity(0.0),
              ],
              stops: const [0.7, 1.0],
            ),
          ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _background.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_chapters.isNotEmpty)
                          Text(
                            '${_currentChapterIndex + 1}/${_chapters.length}章 · $_progressText${_hasStartedReading ? ' · 已读${_formatReadingDuration(_currentReadingDuration)}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _background.textColor.withOpacity(0.6),
                            ),
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
                      _isCollected ? Icons.favorite : Icons.favorite_border,
                      color: _isCollected ? Theme.of(context).colorScheme.error : _background.textColor,
                    ),
                    onPressed: () => _toggleCollection(),
                    tooltip: '收藏',
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                _background.bgColor.withOpacity(0.95),
                _background.bgColor.withOpacity(0.0),
              ],
              stops: const [0.7, 1.0],
            ),
          ),
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
                    // 底层：内容区域，填满整个屏幕
                    Positioned.fill(
                      child: _isLoadingChapter
                          ? Center(child: CircularProgressIndicator(color: _background.textColor.withOpacity(0.5)))
                          : _buildContent(),
                    ),

                    // 顶部进度条（始终显示）
                    if (_chapters.isNotEmpty)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
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

                    // 中间区域点击层：只在屏幕中间40%区域放置点击检测，
                    // 左右两侧不覆盖，让下层内容（ScrollView/PageView）正常接收手势
                    // 滚动模式：整层忽略指针事件，让ScrollView自行处理滚动和点击
                    // 分页模式：仅中间40%响应点击（切换菜单），左右滑动交给下层PageView
                    Positioned.fill(
                      child: _pageTurnMode == PageTurnMode.scroll
                          ? GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: _handleScreenTap,
                              // 明确不处理垂直方向手势，让ScrollView处理
                              onVerticalDragStart: null,
                              onVerticalDragUpdate: null,
                              onVerticalDragEnd: null,
                              child: Container(color: Colors.transparent),
                            )
                          : Row(
                              children: [
                                // 左侧30%：忽略指针事件，让下层PageView处理滑动手势
                                // 点击翻页由PageView的onPageChanged处理
                                Expanded(
                                  flex: 3,
                                  child: IgnorePointer(
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                                // 中间40%：点击切换菜单
                                Expanded(
                                  flex: 4,
                                  child: GestureDetector(
                                    onTap: _toggleMenu,
                                    behavior: HitTestBehavior.translucent,
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                                // 右侧30%：忽略指针事件，让下层PageView处理滑动手势
                                Expanded(
                                  flex: 3,
                                  child: IgnorePointer(
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    // 顶部悬浮工具栏
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildTopToolbar(),
                    ),

                    // 底部悬浮工具栏
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomToolbar(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildContent() {
    if (_pageTurnMode == PageTurnMode.scroll) {
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
      );
    }

    // 仿真翻页模式：使用 FlipPage
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
    // 可用高度 = 屏幕高度 - 顶部状态栏 - 底部安全区 - 顶部进度条(3px) - 底部工具栏预留(48px)
    final height = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - 3 - 48;

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      color: widget.background.textColor,
      letterSpacing: 0.5,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );

    // 计算首页标题占用的额外高度（标题字号 + 行高 + 底部间距24）
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
    final firstPageExtraHeight = titleLineCount * (widget.fontSize + 4) * 1.6 + 24; // 标题行高 + 底部间距

    final pages = TextPaginator.paginate(
      text: widget.chapter.content,
      width: width,
      height: height,
      style: textStyle,
      lineHeight: widget.lineHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      firstPageExtraHeight: firstPageExtraHeight,
    );

    setState(() {
      _pages = pages;
      _isCalculating = false;
    });

    // 只有在明确需要重置页签时才跳转到第一页（如切换章节）
    // 菜单唤起、字体调整等操作不应重置页签
    if (resetPage && _pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCalculating || _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        widget.onPageChanged(index, _pages.length);
        // 注意：不在边界页自动触发跳章
        // PageView 会自然限制在第一页/最后一页
        // 跳章由父组件的点击逻辑处理
      },
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Container(
          color: widget.background.bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              // 分页内容直接显示，不需要SingleChildScrollView
              // TextPaginator已经确保内容在一页内
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

  const _CurlChapterContent({
    super.key,
    required this.chapter,
    required this.background,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.onPageChanged,
    required this.onBoundaryReached,
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
    // 可用高度 = 屏幕高度 - 顶部状态栏 - 底部安全区 - 顶部进度条(3px) - 底部工具栏预留(48px)
    final height = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - 3 - 48;

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      color: widget.background.textColor,
      letterSpacing: 0.5,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );

    // 计算首页标题占用的额外高度（标题字号 + 行高 + 底部间距24）
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
    final firstPageExtraHeight = titleLineCount * (widget.fontSize + 4) * 1.6 + 24; // 标题行高 + 底部间距

    final pages = TextPaginator.paginate(
      text: widget.chapter.content,
      width: width,
      height: height,
      style: textStyle,
      lineHeight: widget.lineHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      firstPageExtraHeight: firstPageExtraHeight,
    );

    setState(() {
      _pages = pages;
      _isCalculating = false;
    });

    // 只有在明确需要重置页签时才跳转到第一页（如切换章节）
    // 菜单唤起、字体调整等操作不应重置页签
    if (resetPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _simulationController.jumpToPage(0);
        }
      });
    }
  }

  /// 构建单页内容 Widget
  Widget _buildPageWidget(ContentPage page) {
    return Container(
      color: widget.background.bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

    return SimulationPageView(
      controller: _simulationController,
      backgroundColor: widget.background.bgColor,
      pages: _pages.map((page) => _buildPageWidget(page)).toList(),
      onPageChanged: (index) {
        widget.onPageChanged(index, _pages.length);
        // 注意：不在边界页自动触发跳章
        // SimulationPageView 会自然限制在第一页/最后一页
        // 跳章由父组件的点击逻辑处理
      },
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
