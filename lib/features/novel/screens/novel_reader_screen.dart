import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config.dart';
import '../../../services/supabase_service.dart';
import '../models/novel_model.dart';
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

class _NovelReaderScreenState extends State<NovelReaderScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  List<NovelChapterModel> _chapters = [];
  NovelChapterModel? _currentChapter;
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  bool _isLoadingChapter = false;
  bool _showMenu = false;

  // 阅读设置
  static const List<double> _fontSizes = [14, 16, 18, 20, 22];
  int _fontSizeIndex = 2; // 默认 18
  double get _fontSize => _fontSizes[_fontSizeIndex];
  double _lineHeight = 1.8;
  ReaderBackground _background = ReaderBackground.white;

  // 书架状态
  bool _isInBookshelf = false;
  bool _isCollected = false;
  String? _bookshelfId;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _loadChapters();
    _checkBookshelfStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _saveProgress();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  /// 加载阅读设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedFontSize = prefs.getDouble('reader_font_size') ?? 18;
      _fontSizeIndex = _fontSizes.indexOf(savedFontSize);
      if (_fontSizeIndex < 0) _fontSizeIndex = 2;
      _lineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
      final savedBg = prefs.getInt('reader_background') ?? 0;
      _background = ReaderBackground.values[savedBg.clamp(0, ReaderBackground.values.length - 1)];
    });
  }

  /// 保存阅读设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setDouble('reader_line_height', _lineHeight);
    await prefs.setInt('reader_background', _background.index);
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
                '${AppConfig.supabaseUrl}/rest/v1/book_shelves?user_id=eq.$userId&novel_id=eq.${widget.novel.id}&select=current_chapter',
              ),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              },
            );
            if (progressResponse.statusCode == 200) {
              final progressData = jsonDecode(progressResponse.body);
              if (progressData.isNotEmpty) {
                final savedChapter = progressData.first['current_chapter'] as int? ?? 1;
                for (int i = 0; i < chapters.length; i++) {
                  if (chapters[i].chapterOrder >= savedChapter) {
                    startIndex = i;
                    break;
                  }
                }
              }
            }
          } catch (_) {}
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

  /// 加载章节内容
  Future<void> _loadChapterContent(NovelChapterModel chapter) async {
    setState(() => _isLoadingChapter = true);

    try {
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
          setState(() {
            _currentChapter = NovelChapterModel.fromJson(data.first);
            _isLoadingChapter = false;
          });
          _scrollController.jumpTo(0);
          _saveProgress();
        } else {
          setState(() {
            _currentChapter = chapter;
            _isLoadingChapter = false;
          });
        }
      } else {
        setState(() {
          _currentChapter = chapter;
          _isLoadingChapter = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentChapter = chapter;
        _isLoadingChapter = false;
      });
    }
  }

  /// 检查书架状态
  Future<void> _checkBookshelfStatus() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/book_shelves?user_id=eq.$userId&novel_id=eq.${widget.novel.id}&select=id',
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
          });
        }
      }
    } catch (_) {}
  }

  /// 保存阅读进度
  Future<void> _saveProgress() async {
    if (_currentChapter == null) return;

    final userId = _userId;
    if (userId == null) return;

    try {
      final chapterNum = _currentChapter!.chapterOrder;

      if (_isInBookshelf && _bookshelfId != null) {
        // 更新已有书架记录
        await http.patch(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/book_shelves?id=eq.$_bookshelfId',
          ),
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'current_chapter': chapterNum,
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      } else {
        // 自动加入书架并记录进度
        final response = await http.post(
          Uri.parse('${AppConfig.supabaseUrl}/rest/v1/book_shelves'),
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'user_id': userId,
            'novel_id': widget.novel.id,
            'status': 'reading',
            'current_chapter': chapterNum,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _isInBookshelf = true;
            _bookshelfId = data.first['id'] as String;
          });
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
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/book_shelves'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'user_id': userId,
          'novel_id': widget.novel.id,
          'status': 'reading',
          'current_chapter': _currentChapter?.chapterOrder ?? 1,
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

  /// 下一章
  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      setState(() {
        _currentChapterIndex++;
      });
      _loadChapterContent(_chapters[_currentChapterIndex]);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一章了')),
        );
      }
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
                          }
                        : null,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
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
  }

  /// 设置全屏
  void _setFullScreen(bool fullScreen) {
    if (fullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据背景设置状态栏
    _setFullScreen(!_showMenu);

    return Scaffold(
      backgroundColor: _background.bgColor,
      appBar: _showMenu
          ? AppBar(
              title: Text(
                _currentChapter?.title ?? widget.novel.title,
                style: const TextStyle(fontSize: 16),
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
                  onPressed: () {
                    setState(() => _isCollected = !_isCollected);
                  },
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
      body: GestureDetector(
        onTap: _toggleMenu,
        child: _isLoading
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
                      // 章节内容
                      Expanded(
                        child: _isLoadingChapter
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: _background.textColor.withOpacity(0.5),
                                ),
                              )
                            : SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
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
                              ),
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
                                      // 设置
                                      _ToolbarButton(
                                        icon: Icons.palette_outlined,
                                        label: '背景',
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
