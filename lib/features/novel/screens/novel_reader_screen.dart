import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novel_model.dart';

/// 小说阅读器页面
class NovelReaderScreen extends StatefulWidget {
  final NovelModel novel;

  const NovelReaderScreen({super.key, required this.novel});

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final _scrollController = ScrollController();
  
  List<NovelChapterModel> _chapters = [];
  NovelChapterModel? _currentChapter;
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  bool _showMenu = false;
  
  // 阅读设置
  double _fontSize = 18;
  double _lineHeight = 1.8;
  String _fontFamily = 'system';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadChapters();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('reader_font_size') ?? 18;
      _lineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
      _fontFamily = prefs.getString('reader_font_family') ?? 'system';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setDouble('reader_line_height', _lineHeight);
    await prefs.setString('reader_font_family', _fontFamily);
  }

  Future<void> _loadChapters() async {
    // 本地模拟数据
    await Future.delayed(const Duration(milliseconds: 500));
    
    final chapters = List.generate(
      widget.novel.chapterCount,
      (index) => NovelChapterModel(
        id: 'chapter_$index',
        novelId: widget.novel.id,
        title: '第 ${index + 1} 章',
        content: _generateChapterContent(index + 1),
        chapterOrder: index,
        createdAt: DateTime.now().subtract(Duration(days: widget.novel.chapterCount - index)),
      ),
    );
    
    // 加载阅读进度
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('novel_progress_${widget.novel.id}') ?? 0;
    final startIndex = savedIndex < chapters.length ? savedIndex : 0;
    
    setState(() {
      _chapters = chapters;
      _currentChapterIndex = startIndex;
      _currentChapter = chapters.isNotEmpty ? chapters[startIndex] : null;
      _isLoading = false;
    });
  }

  String _generateChapterContent(int chapterNum) {
    // 生成模拟章节内容
    final buffer = StringBuffer();
    buffer.writeln('第 $chapterNum 章');
    buffer.writeln();
    for (int i = 0; i < 20; i++) {
      buffer.writeln('这是第 $chapterNum 章的第 ${i + 1} 段内容。这里展示的是模拟的章节文本，实际应用中应该从本地存储或网络加载真实的小说内容。');
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<void> _saveProgress() async {
    if (_currentChapter == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('novel_progress_${widget.novel.id}', _currentChapterIndex);
    await prefs.setString('novel_last_read_${widget.novel.id}', DateTime.now().toIso8601String());
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
        _currentChapter = _chapters[_currentChapterIndex];
      });
      _scrollController.jumpTo(0);
      _saveProgress();
    }
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      setState(() {
        _currentChapterIndex++;
        _currentChapter = _chapters[_currentChapterIndex];
      });
      _scrollController.jumpTo(0);
      _saveProgress();
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
              child: Text(
                '目录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  
                  return ListTile(
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
                        _currentChapter = chapter;
                      });
                      _scrollController.jumpTo(0);
                      _saveProgress();
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
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_fontSize > 12) {
                        setModalState(() => _fontSize -= 2);
                        setState(() {});
                        _saveSettings();
                      }
                    },
                  ),
                  Text('${_fontSize.toInt()}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_fontSize < 32) {
                        setModalState(() => _fontSize += 2);
                        setState(() {});
                        _saveSettings();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 行间距
              Row(
                children: [
                  const Text('行间距'),
                  Expanded(
                    child: Slider(
                      value: _lineHeight,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      onChanged: (value) {
                        setModalState(() => _lineHeight = value);
                        setState(() {});
                        _saveSettings();
                      },
                    ),
                  ),
                  Text(_lineHeight.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _showMenu
          ? AppBar(
              title: Text(
                _currentChapter?.title ?? widget.novel.title,
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: _showChapterList,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettings,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() => _showMenu = !_showMenu);
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentChapter == null
                ? const Center(child: Text('暂无章节'))
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _currentChapter!.content,
                            style: TextStyle(
                              fontSize: _fontSize,
                              height: _lineHeight,
                              fontFamily: _fontFamily == 'system' ? null : _fontFamily,
                            ),
                          ),
                        ),
                      ),
                      if (_showMenu)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
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
                                  onPressed: _currentChapterIndex < _chapters.length - 1
                                      ? _nextChapter
                                      : null,
                                  child: const Text('下一章'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
