import 'package:flutter/foundation.dart';
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

  /// 长按选择文本回调，传递选中的文本、起始偏移和结束偏移
  final void Function(String selectedText, int startOffset, int endOffset)? onLongPressSelectText;

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
    this.onLongPressSelectText,
    this.jumpToLastPage = false,
  });

  @override
  State<PagedChapterContent> createState() => PagedChapterContentState();
}

class PagedChapterContentState extends State<PagedChapterContent> {
  List<ContentPage> _pages = [];
  late PageController _pageController;
  bool _isCalculating = true;
  /// 内容区真实高度，由 build 内的 LayoutBuilder 提供，用于替代 MediaQuery 估算
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首算改由 build 内的 LayoutBuilder 驱动，需要先拿到真实布局约束才能分页
  }

  @override
  void didUpdateWidget(covariant PagedChapterContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有章节切换时才重置页签，字体/行高/背景调整不重置
    if (oldWidget.chapter.id != widget.chapter.id) {
      // 切章期间先进入重算态：PageView 随 LoadingWidget 卸载，避免首帧复用
      // 旧 ScrollPosition（其 pixels 仍停在上一章的绝对页码偏移），否则切到
      // 下一章会直接以「上一章的页码位置」定位（页数更多则串页、更少则被钳到末页），
      // 表现为「跳到未知章节位置」。重算完成后 PageView 以新 initialPage 重新挂载，
      // 首帧即目标页（上一章=末页 / 下一章=首页），不再闪现开头也不再串页。
      // 与 CurlChapterContent（仿真模式）的切章处理保持一致。
      setState(() => _isCalculating = true);
      _scheduleRecalculate(resetPage: true);
    } else if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.font != widget.font) {
      _scheduleRecalculate(resetPage: false);
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

  /// 通过 addPostFrameCallback 调度重算，避免在 build 阶段直接 setState
  void _scheduleRecalculate({bool resetPage = true}) {
    if (_contentHeight == null) return; // 等待 LayoutBuilder 首次提供真实高度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculatePages(resetPage: resetPage);
    });
  }

  void _calculatePages({bool resetPage = true}) {
    if (_contentHeight == null) return; // 真实高度尚未获得，等待 LayoutBuilder 驱动
    final width = MediaQuery.of(context).size.width;
    // 使用 LayoutBuilder 提供的真实内容区高度进行分页，
    // 替代原先基于 MediaQuery 的估算，修复真机安全区更大时底部留白的问题
    final height = _contentHeight!;
    // 系统字体缩放，需与渲染 Text 一致，避免真机（如 OPPO 放大字体）底部留白
    final textScaler = MediaQuery.textScalerOf(context);

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
      textScaler: textScaler,
      text: TextSpan(text: widget.chapter.title, style: titleStyle),
    )..layout(maxWidth: width - 40); // 减去左右 padding 20*2
    final titleLineCount = (titlePainter.computeLineMetrics()).length;
    // 标题实际高度 = 行数 * 缩放后行高 + Padding(bottom: 24)
    final firstPageExtraHeight =
        titleLineCount * textScaler.scale(widget.fontSize + 4) * 1.6 + 24;

    final pages = TextPaginator.paginate(
      text: widget.chapter.content,
      width: width,
      height: height,
      style: textStyle,
      lineHeight: widget.lineHeight,
      // padding 必须与渲染 Container 的 padding 一致，否则分页器会多算可用高度导致内容被裁剪
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      firstPageExtraHeight: firstPageExtraHeight,
      textScaler: textScaler,
    );

    if (kDebugMode) {
      // 真机底部留白诊断日志（仅 debug 构建输出），确认高度/行数/缩放是否匹配
      final lineHeightPx = textScaler.scale(widget.fontSize) * widget.lineHeight;
      debugPrint('[Reader分页-paged] contentH=${height.toStringAsFixed(1)} '
          'textScaler=${textScaler.scale(widget.fontSize) / widget.fontSize} '
          'fontSize=${widget.fontSize} lineHeightPx=${lineHeightPx.toStringAsFixed(1)} '
          'estMaxLines=${((height - 48) / lineHeightPx).floor()} '
          'pages=${pages.length} '
          'mqPadBottom=${MediaQuery.of(context).padding.bottom} '
          'viewPadBottom=${MediaQuery.of(context).viewPadding.bottom}');
    }

    setState(() {
      _pages = pages;
      _isCalculating = false;
    });

    // 通知父组件总页数和当前页码
    // PageView.jumpToPage(0) 不会触发 onPageChanged（页面从0跳到0无变化），
    // 导致父组件 _totalPages 始终为默认值1，点击右侧会错误地触发下一章
    // 必须放在 addPostFrameCallback 中执行，避免在 didChangeDependencies 构建阶段
    // 调用父组件 setState() 触发 setState() or markNeedsBuild() called during build
    final currentPage = resetPage
        ? (widget.jumpToLastPage ? pages.length - 1 : 0)
        : (_pageController.hasClients ? _pageController.page!.round() : 0);
    final totalPages = pages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onPageChanged(currentPage, totalPages);
      }
    });

    // 切换章节（resetPage）时，用目标页作为 PageController 的初始页重建控制器，
    // 让 PageView 首帧即渲染正确页，避免先以初始页0（章节开头）渲染一帧、
    // 再在帧后 jumpToPage 导致的“闪现章节开头”问题（回到上一章时尤为明显）。
    // 字体/行高/背景调整等非 resetPage 场景不重建控制器，保留当前页码。
    if (resetPage) {
      final targetPage = widget.jumpToLastPage ? pages.length - 1 : 0;
      if (mounted) {
        _pageController.dispose();
        _pageController = PageController(initialPage: targetPage);
      }
    }
  }

  /// 计算长按位置对应的字符偏移和选中文本
  void _handleLongPress(LongPressStartDetails details, ContentPage page) {
    if (widget.onLongPressSelectText == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // 将全局坐标转换为局部坐标
    final localPos = renderBox.globalToLocal(details.globalPosition);

    // 计算文本区域的偏移（考虑 PageView 的 padding 和标题）
    const horizontalPadding = 20.0;
    const topPadding = 12.0;
    final textAreaOffset = Offset(horizontalPadding, topPadding + (page.pageIndex == 0 ? _getTitleHeight() : 0));

    // 点击位置相对于文本区域的坐标
    final textPos = localPos - textAreaOffset;

    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      color: widget.background.textColor,
      letterSpacing: 0.5,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );

    // 使用 TextPainter 计算字符偏移
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: page.text, style: textStyle),
    );
    textPainter.layout(maxWidth: renderBox.size.width - horizontalPadding * 2);

    final textPosition = textPainter.getPositionForOffset(textPos);
    final charOffset = textPosition.offset;

    // 选择点击位置前后各 30 个字符
    final start = (charOffset - 30).clamp(0, page.text.length);
    final end = (charOffset + 30).clamp(0, page.text.length);
    final selectedText = page.text.substring(start, end);

    // 转换为章节级别的偏移
    final chapterStart = page.startOffset + start;
    final chapterEnd = page.startOffset + end;

    widget.onLongPressSelectText!(selectedText, chapterStart, chapterEnd);
  }

  /// 计算标题高度
  double _getTitleHeight() {
    final titleStyle = TextStyle(
      fontSize: widget.fontSize + 4,
      height: 1.6,
      fontWeight: FontWeight.bold,
      fontFamily: widget.font.fontFamily == 'system' ? null : widget.font.fontFamily,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final titlePainter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      text: TextSpan(text: widget.chapter.title, style: titleStyle),
    )..layout(maxWidth: MediaQuery.of(context).size.width - 40);
    final titleLineCount = (titlePainter.computeLineMetrics()).length;
    return titleLineCount * textScaler.scale(widget.fontSize + 4) * 1.6 + 24;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = constraints.maxHeight;
        // 首次获得布局约束，或约束发生变化（旋转/安全区变化）时重算分页
        if (_contentHeight == null ||
            (_contentHeight! - contentHeight).abs() > 0.5) {
          _contentHeight = contentHeight;
          // 延迟到帧后执行，避免在 build 阶段调用 setState
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _calculatePages();
          });
        }

        if (_isCalculating || _pages.isEmpty) {
          return const Center(child: LoadingWidget());
        }

        // 使用 RawGestureDetector + GestureRecognizer 避免手势冲突
        // PageView 处理滑动手势，点击通过 behavior + onTapUp 处理
        // 通过 NotificationListener 监听 OverscrollNotification 检测滑动到边界，触发章节切换
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.onTapScreen,
          child: NotificationListener<OverscrollNotification>(
            onNotification: (notification) {
              if (_pages.isEmpty) return false;
              final currentPage = _pageController.hasClients
                  ? _pageController.page?.round() ?? 0
                  : 0;
              // overscroll > 0：越过末尾继续向后滑 → 切换下一章
              // overscroll < 0：越过开头继续向前滑 → 切换上一章
              // 原实现符号写反且条件自相矛盾（末页却判 overscroll<0），永不触发。
              // 单页章节 PageView 不可滚动，Android(ClampingScrollPhysics)
              // 仍会产生 OverscrollNotification，此处同一页同时满足首/末页判断。
              if (notification.overscroll > 0 &&
                  currentPage >= _pages.length - 1) {
                widget.onBoundaryReached(true);
              } else if (notification.overscroll < 0 && currentPage <= 0) {
                widget.onBoundaryReached(false);
              }
              return false;
            },
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
                return GestureDetector(
                  onLongPressStart: widget.onLongPressSelectText != null
                      ? (details) => _handleLongPress(details, page)
                      : null,
                  child: Container(
                    color: widget.background.bgColor,
                    padding: const EdgeInsets.fromLTRB(
                        20, topPadding, 20, bottomPadding),
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
                                  fontFamily: widget.font.fontFamily == 'system'
                                      ? null
                                      : widget.font.fontFamily,
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
                              fontFamily: widget.font.fontFamily == 'system'
                                  ? null
                                  : widget.font.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
