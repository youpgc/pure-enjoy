import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../data/novel_model.dart';

/// 小说阅读页面
class NovelReaderPage extends StatefulWidget {
  final NovelModel novel;

  const NovelReaderPage({
    super.key,
    required this.novel,
  });

  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage> {
  bool _showControls = true;
  double _fontSize = 18;
  int _currentChapter = 0;
  
  // 示例章节内容（实际应从API获取）
  final List<String> _chapters = [
    '第一章 测试章节',
    '第二章 测试章节',
    '第三章 测试章节',
  ];
  
  final String _sampleContent = '''
这是小说的示例内容。在实际应用中，这里会显示从服务器获取的小说章节内容。

用户可以在这里阅读小说，调整字体大小、背景颜色等阅读设置。

阅读进度会自动保存，下次打开时会自动回到上次阅读的位置。

（此处为占位文本，用于演示阅读器界面）

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

这是小说的示例内容。在实际应用中，这里会显示从服务器获取的小说章节内容。

用户可以在这里阅读小说，调整字体大小、背景颜色等阅读设置。

阅读进度会自动保存，下次打开时会自动回到上次阅读的位置。

（此处为占位文本，用于演示阅读器界面）

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
'''.trim();

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.novel.lastChapterIndex;
    // 进入阅读模式，隐藏系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _saveProgress();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final updatedNovel = widget.novel.copyWith(
      lastReadAt: DateTime.now(),
      lastChapterIndex: _currentChapter,
      progress: (_currentChapter + 1) / _chapters.length,
    );
    await StorageService().novelBox.put(updatedNovel.id, updatedNovel);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5DC), // 护眼米色背景
        body: SafeArea(
          child: Stack(
            children: [
              // 阅读内容
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 章节标题
                    Text(
                      _chapters[_currentChapter],
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 章节内容
                    Text(
                      _sampleContent,
                      style: TextStyle(
                        fontSize: _fontSize,
                        color: AppTheme.textPrimary,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // 下一章按钮
                    if (_currentChapter < _chapters.length - 1)
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentChapter++;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('下一章'),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 顶部控制栏
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color(0xFFF5F5DC),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                widget.novel.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: _showReaderSettings,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // 底部控制栏
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color(0xFFF5F5DC),
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 进度条
                          Row(
                            children: [
                              Text(
                                '第${_currentChapter + 1}章',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _currentChapter.toDouble(),
                                  min: 0,
                                  max: (_chapters.length - 1).toDouble(),
                                  onChanged: (value) {
                                    setState(() {
                                      _currentChapter = value.toInt();
                                    });
                                  },
                                ),
                              ),
                              Text(
                                '共${_chapters.length}章',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 操作按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildBottomButton(
                                icon: Icons.format_list_bulleted,
                                label: '目录',
                                onTap: _showChapterList,
                              ),
                              _buildBottomButton(
                                icon: Icons.text_fields,
                                label: '设置',
                                onTap: _showReaderSettings,
                              ),
                              _buildBottomButton(
                                icon: Icons.brightness_6,
                                label: '夜间',
                                onTap: () {
                                  // TODO: 切换夜间模式
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '目录',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_chapters[index]),
                    selected: index == _currentChapter,
                    selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _currentChapter = index;
                      });
                      Navigator.pop(context);
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

  void _showReaderSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '阅读设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text('字体大小'),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (_fontSize > 12) {
                      setState(() {
                        _fontSize -= 2;
                      });
                    }
                  },
                ),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 12,
                    max: 32,
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_fontSize < 32) {
                      setState(() {
                        _fontSize += 2;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('背景颜色'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorOption(const Color(0xFFF5F5DC), '护眼'),
                _buildColorOption(Colors.white, '白色'),
                _buildColorOption(const Color(0xFF2D2D2D), '夜间'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.textHint,
              width: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
