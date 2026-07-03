import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/gutendex_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/public_domain_book_model.dart';

/// 背景主题枚举
enum _ReaderBackground {
  white('白色', Colors.white, Colors.black87),
  yellow('护眼黄', Color(0xFFF5F0E6), Color(0xFF333333)),
  dark('深色', Color(0xFF1A1A2E), Color(0xFFE0E0E0)),
  gray('灰色', Color(0xFFE8E8E8), Color(0xFF333333));

  const _ReaderBackground(this.label, this.bgColor, this.textColor);
  final String label;
  final Color bgColor;
  final Color textColor;
}

/// 字体选择枚举
enum _ReaderFont {
  system('系统默认', null),
  serif('宋体', 'serif'),
  sansSerif('黑体', 'sans-serif'),
  monospace('等宽', 'monospace');

  const _ReaderFont(this.label, this.fontFamily);
  final String label;
  final String? fontFamily;
}

/// 公版书纯文本阅读器
/// 从 Gutendex 下载整本纯文本，支持滚动阅读、设置调整、进度保存
class PublicDomainReaderScreen extends StatefulWidget {
  final PublicDomainBookModel book;

  const PublicDomainReaderScreen({
    super.key,
    required this.book,
  });

  @override
  State<PublicDomainReaderScreen> createState() =>
      _PublicDomainReaderScreenState();
}

class _PublicDomainReaderScreenState extends State<PublicDomainReaderScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

  String _content = '';
  bool _isLoading = true;
  bool _isLoadingError = false;
  String? _errorMessage;
  bool _showMenu = false;

  // 工具栏动画
  late AnimationController _menuAnimationController;
  late Animation<double> _menuOpacityAnimation;

  // 阅读设置
  static const List<double> _fontSizes = [14, 16, 18, 20, 22, 24, 26, 28];
  int _fontSizeIndex = 3; // 默认 20
  double get _fontSize => _fontSizes[_fontSizeIndex];

  static const List<double> _lineHeights = [1.5, 1.8, 2.0, 2.2, 2.5];
  int _lineHeightIndex = 2; // 默认 2.0
  double get _lineHeight => _lineHeights[_lineHeightIndex];

  _ReaderBackground _background = _ReaderBackground.yellow;
  _ReaderFont _font = _ReaderFont.serif;

  // 阅读进度
  double _readProgress = 0.0;
  bool _hasLoadedProgress = false;

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _menuOpacityAnimation = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(_onScroll);
    _loadSettings();
    _loadContent();
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }

  /// 加载保存的设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'pd_reader_${widget.book.id}';

      setState(() {
        _fontSizeIndex = prefs.getInt('${prefix}_font_size') ?? 3;
        _lineHeightIndex = prefs.getInt('${prefix}_line_height') ?? 2;

        final bgIndex = prefs.getInt('${prefix}_background') ?? 1;
        if (bgIndex >= 0 && bgIndex < _ReaderBackground.values.length) {
          _background = _ReaderBackground.values[bgIndex];
        }

        final fontIndex = prefs.getInt('${prefix}_font') ?? 1;
        if (fontIndex >= 0 && fontIndex < _ReaderFont.values.length) {
          _font = _ReaderFont.values[fontIndex];
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('加载阅读设置失败: $e');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'pd_reader_${widget.book.id}';
      await prefs.setInt('${prefix}_font_size', _fontSizeIndex);
      await prefs.setInt('${prefix}_line_height', _lineHeightIndex);
      await prefs.setInt('${prefix}_background', _background.index);
      await prefs.setInt('${prefix}_font', _font.index);
    } catch (e) {
      if (kDebugMode) debugPrint('保存阅读设置失败: $e');
    }
  }

  /// 保存阅读进度
  Future<void> _saveProgress() async {
    if (!_hasLoadedProgress || _content.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'pd_reader_${widget.book.id}';
      await prefs.setDouble('${prefix}_progress', _readProgress);
      await prefs.setInt('${prefix}_scroll_offset', _scrollController.offset.toInt());
    } catch (e) {
      if (kDebugMode) debugPrint('保存阅读进度失败: $e');
    }
  }

  /// 加载保存的进度并跳转
  Future<void> _restoreProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'pd_reader_${widget.book.id}';
      final savedOffset = prefs.getInt('${prefix}_scroll_offset');

      if (savedOffset != null && savedOffset > 0 && _scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(
            savedOffset.toDouble().clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            ),
          );
        }
      }
      _hasLoadedProgress = true;
    } catch (e) {
      if (kDebugMode) debugPrint('恢复阅读进度失败: $e');
      _hasLoadedProgress = true;
    }
  }

  /// 加载文本内容
  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _isLoadingError = false;
      _errorMessage = null;
    });

    try {
      String? url = widget.book.textUrl;
      // 如果没有纯文本，尝试 HTML
      if (url == null && widget.book.htmlUrl != null) {
        url = widget.book.htmlUrl;
      }

      if (url == null) {
        throw Exception('该书暂无可读格式');
      }

      final text = await GutendexService.instance.downloadText(url);

      if (mounted) {
        setState(() {
          _content = _cleanText(text);
          _isLoading = false;
        });
        // 内容加载完成后恢复进度
        _restoreProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 清洗文本：移除 Project Gutenberg 的协议头尾、多余空行等
  String _cleanText(String text) {
    // 移除回车符
    text = text.replaceAll('\r', '');

    // 移除 PG 协议头（常见标记）
    final startMarkers = [
      '*** START OF THIS PROJECT GUTENBERG',
      '*** START OF THE PROJECT GUTENBERG',
      '***START OF THIS PROJECT GUTENBERG',
      '***START OF THE PROJECT GUTENBERG',
    ];
    for (final marker in startMarkers) {
      final idx = text.indexOf(marker);
      if (idx != -1) {
        final endIdx = text.indexOf('\n', idx);
        if (endIdx != -1) {
          text = text.substring(endIdx + 1);
        }
        break;
      }
    }

    // 移除 PG 协议尾
    final endMarkers = [
      '*** END OF THIS PROJECT GUTENBERG',
      '*** END OF THE PROJECT GUTENBERG',
      '***END OF THIS PROJECT GUTENBERG',
      '***END OF THE PROJECT GUTENBERG',
    ];
    for (final marker in endMarkers) {
      final idx = text.indexOf(marker);
      if (idx != -1) {
        text = text.substring(0, idx);
        break;
      }
    }

    // 压缩连续空行（超过 3 个换行压缩为 2 个）
    while (text.contains('\n\n\n\n')) {
      text = text.replaceAll('\n\n\n\n', '\n\n\n');
    }

    return text.trim();
  }

  /// 滚动监听，更新进度
  void _onScroll() {
    if (!_scrollController.hasClients || _content.isEmpty) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _readProgress = 1.0;
      return;
    }

    final currentOffset = _scrollController.offset.clamp(0.0, maxScroll);
    final progress = currentOffset / maxScroll;

    setState(() {
      _readProgress = progress.clamp(0.0, 1.0);
    });
  }

  /// 切换菜单显示
  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
    if (_showMenu) {
      _menuAnimationController.forward();
    } else {
      _menuAnimationController.reverse();
    }
  }

  /// 增大字体
  void _increaseFontSize() {
    if (_fontSizeIndex < _fontSizes.length - 1) {
      setState(() => _fontSizeIndex++);
      _saveSettings();
    }
  }

  /// 减小字体
  void _decreaseFontSize() {
    if (_fontSizeIndex > 0) {
      setState(() => _fontSizeIndex--);
      _saveSettings();
    }
  }

  /// 切换背景
  void _switchBackground() {
    setState(() {
      final nextIndex = (_background.index + 1) % _ReaderBackground.values.length;
      _background = _ReaderBackground.values[nextIndex];
    });
    _saveSettings();
  }

  /// 切换字体
  void _switchFont() {
    setState(() {
      final nextIndex = (_font.index + 1) % _ReaderFont.values.length;
      _font = _ReaderFont.values[nextIndex];
    });
    _saveSettings();
  }

  /// 切换行高
  void _switchLineHeight() {
    setState(() {
      final nextIndex = (_lineHeightIndex + 1) % _lineHeights.length;
      _lineHeightIndex = nextIndex;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _background.bgColor,
      body: Stack(
        children: [
          // 阅读内容区域
          _buildContent(),

          // 点击区域（中间区域切换菜单）
          GestureDetector(
            onTap: _toggleMenu,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
              // 中间 40% 区域用于点击切换菜单
              margin: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.height * 0.3,
                horizontal: MediaQuery.of(context).size.width * 0.2,
              ),
            ),
          ),

          // 顶部工具栏
          _buildTopBar(colorScheme),

          // 底部工具栏
          _buildBottomBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在加载文本...',
              style: TextStyle(
                color: _background.textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: _background.textColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _background.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '未知错误',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _background.textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadContent,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 文本内容
    return SafeArea(
      child: SelectionArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
          child: Text(
            _content,
            style: TextStyle(
              fontSize: _fontSize,
              height: _lineHeight,
              color: _background.textColor,
              fontFamily: _font.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _menuOpacityAnimation,
      builder: (context, child) {
        final opacity = _menuOpacityAnimation.value;
        if (opacity <= 0) return const SizedBox.shrink();

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                color: _background.bgColor.withValues(alpha: 0.95),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      // 返回按钮
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: _background.textColor,
                        ),
                      ),
                      // 书名
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _background.textColor,
                              ),
                            ),
                            Text(
                              widget.book.authorNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _background.textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 更多操作
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: _background.textColor,
                        ),
                        color: _background.bgColor,
                        onSelected: (value) {
                          switch (value) {
                            case 'copy_title':
                              Clipboard.setData(ClipboardData(
                                text: '${widget.book.title} - ${widget.book.authorNames}',
                              ));
                              showSnackBar(context, '书名已复制');
                              break;
                            case 'reset_progress':
                              _showResetProgressDialog();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'copy_title',
                            child: Row(
                              children: [
                                Icon(Icons.copy,
                                    size: 18, color: _background.textColor),
                                const SizedBox(width: 8),
                                Text(
                                  '复制书名',
                                  style: TextStyle(color: _background.textColor),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'reset_progress',
                            child: Row(
                              children: [
                                Icon(Icons.restart_alt,
                                    size: 18, color: _background.textColor),
                                const SizedBox(width: 8),
                                Text(
                                  '重置进度',
                                  style: TextStyle(color: _background.textColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _menuOpacityAnimation,
      builder: (context, child) {
        final opacity = _menuOpacityAnimation.value;
        if (opacity <= 0) return const SizedBox.shrink();

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                color: _background.bgColor.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 进度条
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${(_readProgress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: _background.textColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.primaryOrange,
                                inactiveTrackColor:
                                    colorScheme.outlineVariant.withValues(alpha: 0.3),
                                thumbColor: AppTheme.primaryOrange,
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: _readProgress,
                                onChanged: (value) {
                                  setState(() => _readProgress = value);
                                },
                                onChangeEnd: (value) {
                                  if (_scrollController.hasClients) {
                                    final maxScroll = _scrollController
                                        .position.maxScrollExtent;
                                    _scrollController.jumpTo(
                                      (value * maxScroll).clamp(0.0, maxScroll),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 工具按钮行
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildToolButton(
                            icon: Icons.text_decrease,
                            label: 'A-',
                            onTap: _decreaseFontSize,
                          ),
                          _buildToolButton(
                            icon: Icons.text_increase,
                            label: 'A+',
                            onTap: _increaseFontSize,
                          ),
                          _buildToolButton(
                            icon: Icons.format_line_spacing,
                            label: '行高',
                            badge: '${(_lineHeight * 10).toInt()}',
                            onTap: _switchLineHeight,
                          ),
                          _buildToolButton(
                            icon: Icons.font_download_outlined,
                            label: _font.label,
                            onTap: _switchFont,
                          ),
                          _buildToolButton(
                            icon: Icons.color_lens_outlined,
                            label: _background.label,
                            onTap: _switchBackground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: _background.textColor.withValues(alpha: 0.8),
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: _background.textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetProgressDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置进度'),
        content: const Text('确定要重置阅读进度吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final prefs = await SharedPreferences.getInstance();
              final prefix = 'pd_reader_${widget.book.id}';
              await prefs.remove('${prefix}_progress');
              await prefs.remove('${prefix}_scroll_offset');
              if (mounted && _scrollController.hasClients) {
                _scrollController.jumpTo(0);
                setState(() => _readProgress = 0);
              }
              if (mounted) showSnackBar(context, '进度已重置');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
