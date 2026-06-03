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
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _pageController = PageController();

  List<NovelChapterModel> _chapters = [];
  NovelChapterModel? _currentChapter;
  NovelChapterModel? _nextChapterCache; // 预加载下一章
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  bool _isLoadingChapter = false;
  bool _showMenu = false;

  // 分页相关
  List<ContentPage> _contentPages = [];
  int _currentPageIndex = 0;

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
  PageTurnMode _pageTurnMode = PageTurnMode.slide;

  // 书架状态
  bool _isInBookshelf = false;
  bool _isCollected = false;
  String? _bookshelfId;

  // 页面尺寸（用于分页计算）
  Size? _pageSize;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadSettings();
    _loadChapters();
    _checkBookshelfStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _pageController.dispose();
    _saveProgress();
    _scrollController.dispose();
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

  /// 暂停阅读计时器
  void _pauseReadingTimer() {
    if (_readingStartTime != null && _hasStartedReading) {
      _totalReadingTime += DateTime.now().difference(_readingStartTime!);
      _readingStartTime = null;
    }
  }

  /// 恢复阅读计时器
  void _resumeReadingTimer() {
    if (_hasStartedReading) {
      _readingStartTime = DateTime.now();
    }
  }

  /// 开始阅读计时
  void _startReadingTimer() {
    if (!_hasStartedReading) {
      _hasStartedReading = true;
      _readingStartTime = DateTime.now();
    }
  }

  /// 获取当前阅读时长
  Duration get _currentReadingDuration {
    if (_readingStartTime != null) {
      return _totalReadingTime + DateTime.now().difference(_readingStartTime!);
    }
    return _totalReadingTime;
  }

  /// 格式化阅读时长
  String _formatReadingDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '${duration.inSeconds}秒';
    }
  }

  /// 加载阅读设置
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
      final savedMode = prefs.getInt('reader_page_turn_mode') ?? 1;
      _pageTurnMode = PageTurnMode.values[savedMode.clamp(0, PageTurnMode.values.length - 1)];
    });
  }

  /// 保存阅读设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setDouble('reader_line_height', _lineHeight);
    await prefs.setInt('reader_background', _background.index);
    await prefs.setInt('reader_font', _font.index);
    await prefs.setInt('reader_page_turn_mode', _pageTurnMode.index);
  }

  /// 加载章节列表
  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/novel_chapters?novel_id=eq.${widget.novel.id}&select=id,title,chapter_num&order=chapter_num.asc',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final chapters = data.map((json) => NovelChapterModel.fromJson(json)).toList();

        // 过滤掉章节号为0的无效章节
        chapters.removeWhere((c) => c.chapterOrder <= 0);

        // 确定起始章节
        int startIndex = 0;
        for (int i = 0; i < chapters.length; i++) {
          if (chapters[i].chapterOrder >= widget.startChapter) {
            startIndex = i;
            break;
          }
        }

        // 如果已登录，尝试恢复阅读进度
        final userId = _userId;
        if (userId != null) {
          try {
            final progressResponse = await http.get(
              Uri.parse(
                '${AppConfig.supabaseUrl}/rest/v1/user_novels?user_id=eq.$userId&novel_id=eq.${widget.novel.id}&select=last_chapter',
              ),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              },
            );
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

        // 加载当前章节内容
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

  /// 计算分页
  void _calculatePages() {
    if (_currentChapter == null || _pageSize == null) return;
    final content = _currentChapter!.content;
    if (content.isEmpty) return;

    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      color: _background.textColor,
      letterSpacing: 0.5,
      fontFamily: _font.fontFamily == 'system' ? null : _font.fontFamily,
    );

    _contentPages = TextPaginator.paginate(
      text: content,
      width: _pageSize!.width,
      height: _pageSize!.height,
      style: textStyle,
      lineHeight: _lineHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    );

    _currentPageIndex = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  /// 加载章节内容
  Future<void> _loadChapterContent(NovelChapterModel chapter) async {
    setState(() => _isLoadingChapter = true);

    try {
      // 优先使用本地缓存
      final cachedContent = await ChapterCacheService.instance.getCachedContent(chapter.id);
      if (cachedContent != null) {
        setState(() {
          _currentChapter = NovelChapterModel(
            id: chapter.id,
            novelId: chapter.novelId,
            title: chapter.title,
            chapterOrder: chapter.chapterOrder,
            content: cachedContent,
            createdAt: chapter.createdAt,
          );
          _isLoadingChapter = false;
        });
        _calculatePages();
        _saveProgress();
        _startReadingTimer();
        _preloadNextChapter();
        return;
      }

      // 无缓存，从网络加载
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/novel_chapters?id=eq.${chapter.id}&select=*',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final chapterData = data.first;
          setState(() {
            _currentChapter = NovelChapterModel.fromJson(chapterData);
            _isLoadingChapter = false;
          });
          _calculatePages();
          _saveProgress();
          _startReadingTimer();
          _preloadNextChapter();

          // 自动缓存当前章节
          if (_currentChapter!.content.isNotEmpty) {
            ChapterCacheService.instance.cacheChapter(
              chapterId: _currentChapter!.id,
              novelId: widget.novel.id,
              title: _currentChapter!.title,
              chapterOrder: _currentChapter!.chapterOrder,
              content: _currentChapter!.content,
            );
          }
        } else {
          setState(() {
            _currentChapter = chapter;
            _isLoadingChapter = false;
          });
          _calculatePages();
        }
      } else {
        setState(() {
          _currentChapter = chapter;
          _isLoadingChapter = false;
        });
        _calculatePages();
      }
    } catch (e) {
      setState(() {
        _currentChapter = chapter;
        _isLoadingChapter = false;
      });
      _calculatePages();
    }
  }

  /// 滚动到底部自动加载下一章
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (_currentChapterIndex < _chapters.length - 1 && !_isLoadingChapter) {
        _nextChapter();
      }
    }
  }

  /// 预加载下一章内容
  Future<void> _preloadNextChapter() async {
    final nextIndex = _currentChapterIndex + 1;
    if (nextIndex >= _chapters.length) return;

    final nextChapter = _chapters[nextIndex];
    if (_nextChapterCache?.id == nextChapter.id) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/novel_chapters?id=eq.${nextChapter.id}&select=id,content',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          _nextChapterCache = NovelChapterModel.fromJson(data.first);

          // 缓存下一章
          if (_nextChapterCache!.content.isNotEmpty) {
            ChapterCacheService.instance.cacheChapter(
              chapterId: _nextChapterCache!.id,
              novelId: widget.novel.id,
              title: _nextChapterCache!.title,
              chapterOrder: _nextChapterCache!.chapterOrder,
              content: _nextChapterCache!.content,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('预缓存下一章失败: $e');
    }
  }

  /// 检查书架状态
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

  /// 保存阅读进度
  Future<void> _saveProgress() async {
    if (_currentChapter == null) return;

    final userId = _userId;
    if (userId == null) return;

    try {
      final chapterNum = _currentChapter!.chapterOrder;
      final totalChapters = _chapters.length;
      final progress = totalChapters > 0 ? chapterNum / totalChapters : 0.0;

      if (_isInBookshelf && _bookshelfId != null) {
        // 更新已有书架记录
        await http.patch(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/user_novels?id=eq.$_bookshelfId',
          ),
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
        // 自动加入书架并记录进度
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

  /// 加入书架
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

  /// 切换收藏状态
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

  /// 上一章
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

  /// 下一章（使用预加载缓存）
  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      final nextIndex = _currentChapterIndex + 1;
      final nextChapter = _chapters[nextIndex];

      setState(() {
        _currentChapterIndex = nextIndex;
        // 如果有缓存，使用缓存的内容
        if (_nextChapterCache?.id == nextChapter.id) {
          _currentChapter = _nextChapterCache;
          _isLoadingChapter = false;
          _nextChapterCache = null;
        }
      });

      // 如果没有缓存，正常加载
      if (_currentChapter?.id != nextChapter.id) {
        _loadChapterContent(nextChapter);
      } else {
        _calculatePages();
        _saveProgress();
        _startReadingTimer();
        _preloadNextChapter();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一章了')),
        );
      }
    }
  }

  /// 翻到下一页
  void _nextPage() {
    if (_pageTurnMode == PageTurnMode.scroll) return; // 滚动模式不处理

    if (_currentPageIndex < _contentPages.length - 1) {
      setState(() => _currentPageIndex++);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // 当前章最后一页，进入下一章
      _nextChapter();
    }
  }

  /// 翻到上一页
  void _previousPage() {
    if (_pageTurnMode == PageTurnMode.scroll) return;

    if (_currentPageIndex > 0) {
      setState(() => _currentPageIndex--);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // 当前章第一页，进入上一章
      _previousChapter();
    }
  }

  /// 显示章节目录
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
                  Text(
                    '目录',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(
                            Icons.play_arrow,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentChapterIndex = index;
                      });
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

  /// 显示设置底部弹窗
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
              Text(
                '阅读设置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // 字体大小
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
                            _calculatePages();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${_fontSize.toInt()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Text('A+', style: TextStyle(fontSize: 16)),
                    onPressed: _fontSizeIndex < _fontSizes.length - 1
                        ? () {
                            setModalState(() => _fontSizeIndex++);
                            setState(() {});
                            _saveSettings();
                            _calculatePages();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 行高设置
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
                            _calculatePages();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _lineHeight.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: _lineHeightIndex < _lineHeights.length - 1
                        ? () {
                            setModalState(() => _lineHeightIndex++);
                            setState(() {});
                            _saveSettings();
                            _calculatePages();
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 翻页模式
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

              // 字体设置
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
                        _calculatePages();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 背景设置
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
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  )
                                : Border.all(
                                    color: Theme.of(context).colorScheme.outlineVariant,
                                  ),
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

  /// 切换菜单显示
  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
    _setFullScreen(!_showMenu);
  }

  /// 设置全屏
  void _setFullScreen(bool fullScreen) {
    if (fullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// 计算阅读进度百分比
  double get _readingProgress {
    if (_chapters.isEmpty) return 0;
    return (_currentChapterIndex + 1) / _chapters.length;
  }

  /// 格式化进度百分比
  String get _progressText {
    return '${(_readingProgress * 100).toStringAsFixed(1)}%';
  }

  /// 构建单页内容
  Widget _buildPageContent(ContentPage page) {
    return Container(
      color: _background.bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题（只在第一页显示）
          if (page.pageIndex == 0)
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
          // 页面内容
          Expanded(
            child: Text(
              page.text,
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: _background.textColor,
                letterSpacing: 0.5,
                fontFamily: _font.fontFamily == 'system' ? null : _font.fontFamily,
              ),
            ),
          ),
          // 页码
          Center(
            child: Text(
              '${page.pageIndex + 1} / ${page.totalPages}',
              style: TextStyle(
                fontSize: 12,
                color: _background.textColor.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建滚动模式内容
  Widget _buildScrollContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题
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
          // 章节内容
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
          // 章节底部导航
          Center(
            child: Text(
              '${_currentChapter!.title} - 完',
              style: TextStyle(
                fontSize: 14,
                color: _background.textColor.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 构建翻页模式内容
  Widget _buildPagedContent() {
    if (_contentPages.isEmpty) {
      return _buildScrollContent();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 记录页面尺寸用于分页计算
        final newSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_pageSize != newSize) {
          _pageSize = newSize;
          // 延迟计算分页，避免build过程中setState
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _calculatePages();
          });
        }

        return GestureDetector(
          onTapUp: (details) {
            final width = constraints.maxWidth;
            final dx = details.globalPosition.dx;
            if (dx < width * 0.3) {
              _previousPage();
            } else if (dx > width * 0.7) {
              _nextPage();
            } else {
              _toggleMenu();
            }
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -200) {
              _nextPage();
            } else if (details.primaryVelocity! > 200) {
              _previousPage();
            }
          },
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _contentPages.length,
            itemBuilder: (context, index) {
              return _buildPageContent(_contentPages[index]);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background.bgColor,
      appBar: _showMenu
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentChapter?.title ?? widget.novel.title,
                    style: const TextStyle(fontSize: 16),
                  ),
                  // 阅读进度和时长
                  if (_chapters.isNotEmpty)
                    Text(
                      '${_currentChapterIndex + 1}/${_chapters.length}章 · $_progressText${_hasStartedReading ? ' · 已读${_formatReadingDuration(_currentReadingDuration)}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              actions: [
                // 书架按钮
                IconButton(
                  icon: Icon(
                    _isInBookshelf
                        ? Icons.library_books
                        : Icons.library_add_outlined,
                  ),
                  onPressed: _isInBookshelf ? null : _addToBookshelf,
                  tooltip: _isInBookshelf ? '已在书架' : '加入书架',
                ),
                // 收藏按钮
                IconButton(
                  icon: Icon(
                    _isCollected
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: _isCollected ? Colors.red : null,
                  ),
                  onPressed: () => _toggleCollection(),
                  tooltip: '收藏',
                ),
                // 详情按钮
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NovelDetailScreen(novel: widget.novel),
                      ),
                    );
                  },
                  tooltip: '详情',
                ),
              ],
            )
          : null,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _background.textColor.withOpacity(0.5),
              ),
            )
          : _currentChapter == null
              ? Center(
                  child: Text(
                    '暂无章节',
                    style: TextStyle(color: _background.textColor),
                  ),
                )
              : Column(
                  children: [
                    // 阅读进度条
                    if (_chapters.isNotEmpty)
                      LinearProgressIndicator(
                        value: _readingProgress,
                        backgroundColor: _background.textColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _background == ReaderBackground.dark
                              ? Colors.blue
                              : Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 3,
                      ),
                    // 章节内容
                    Expanded(
                      child: _isLoadingChapter
                          ? Center(
                              child: CircularProgressIndicator(
                                color: _background.textColor.withOpacity(0.5),
                              ),
                            )
                          : _pageTurnMode == PageTurnMode.scroll
                              ? GestureDetector(
                                  onTap: _toggleMenu,
                                  child: _buildScrollContent(),
                                )
                              : _buildPagedContent(),
                    ),
                    // 底部工具栏
                    if (_showMenu)
                      Container(
                        decoration: BoxDecoration(
                          color: _background.bgColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 上一章/下一章
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _currentChapterIndex > 0
                                            ? _previousChapter
                                            : null,
                                        child: const Text('上一章'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _currentChapterIndex <
                                                _chapters.length - 1
                                            ? _nextChapter
                                            : null,
                                        child: const Text('下一章'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 工具栏
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // 目录
                                    _ToolbarButton(
                                      icon: Icons.list_outlined,
                                      label: '目录',
                                      textColor: _background.textColor,
                                      onTap: _showChapterList,
                                    ),
                                    // 字体大小
                                    _ToolbarButton(
                                      icon: Icons.text_fields,
                                      label: '字体',
                                      textColor: _background.textColor,
                                      onTap: _showSettings,
                                    ),
                                    // 翻页模式
                                    _ToolbarButton(
                                      icon: _pageTurnMode.icon,
                                      label: '翻页',
                                      textColor: _background.textColor,
                                      onTap: _showSettings,
                                    ),
                                    // 夜间模式快捷
                                    _ToolbarButton(
                                      icon: _background == ReaderBackground.dark
                                          ? Icons.light_mode_outlined
                                          : Icons.dark_mode_outlined,
                                      label: _background == ReaderBackground.dark
                                          ? '日间'
                                          : '夜间',
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
                  ],
                ),
    );
  }
}

/// 工具栏按钮
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
            Text(
              label,
              style: TextStyle(fontSize: 11, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
