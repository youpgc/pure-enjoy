import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import 'reader_enums.dart';
import 'reader_page_turn.dart';
import '../../../core/widgets/widgets.dart';

/// 分页章节内容组件（slide/cover 模式）
///
/// 使用 PageView + TextPaginator 将长章节内容分页显示，
/// 支持 slide 和 cover 两种翻页动画。
class PagedChapterContent extends StatefulWidget {
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

  const PagedChapterContent({
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
  State<PagedChapterContent> createState() => PagedChapterContentState();
}

class PagedChapterContentState extends State<PagedChapterContent> {
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
  void didUpdateWidget(covariant PagedChapterContent oldWidget) {
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
    // 顶部状态栏高度 = SafeArea top padding + 固定高度 44
    // 底部状态栏高度 = SafeArea bottom padding + 内部内容高度（进度条 ~2 + padding 20 = ~22）
    // 使用动态计算替代硬编码，避免在有安全区域的设备上出现内容截断
    final topStatusBarHeight = mediaQuery.padding.top + 44.0;
    final bottomStatusBarHeight = mediaQuery.padding.bottom + 24.0;
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
      // padding 必须与渲染 Container 的 padding 一致，否则分页器会多算可用高度导致内容被裁剪
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
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
        if (mounted && _pageController.hasClients) {
          // 根据 jumpToLastPage 决定跳转到第一页还是最后一页
          final targetPage = widget.jumpToLastPage ? pages.length - 1 : 0;
          _pageController.jumpToPage(targetPage);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCalculating || _pages.isEmpty) {
      return const Center(child: LoadingWidget());
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
          const topPadding = 12.0;
          const bottomPadding = 36.0;
          return Container(
            color: widget.background.bgColor,
            padding: const EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
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
