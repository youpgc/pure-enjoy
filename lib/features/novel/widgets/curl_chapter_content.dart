import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import 'reader_enums.dart';
import 'reader_page_turn.dart';
import '../../../core/widgets/widgets.dart';

class CurlChapterContent extends StatefulWidget {
  final NovelChapterModel chapter;
  final ReaderBackground background;
  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final void Function(int currentPage, int totalPages) onPageChanged;
  final void Function(bool isLastPage) onBoundaryReached;
  /// 屏幕点击回调，由内容层统一处理点击区域逻辑
  final void Function(TapUpDetails details) onTapScreen;
  /// 长按选择文本回调，传递选中的文本、起始偏移和结束偏移
  final void Function(String selectedText, int startOffset, int endOffset)? onLongPressSelectText;
  /// 是否跳转到最后一页（上一章时使用）
  final bool jumpToLastPage;

  const CurlChapterContent({
    super.key,
    required this.chapter,
    required this.background,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.onPageChanged,
    required this.onBoundaryReached,
    required this.onTapScreen,
    this.onLongPressSelectText,
    this.jumpToLastPage = false,
  });

  @override
  State<CurlChapterContent> createState() => CurlChapterContentState();
}

class CurlChapterContentState extends State<CurlChapterContent> {
  List<ContentPage> _pages = [];
  late SimulationPageController _simulationController;
  bool _isCalculating = true;
  /// 内容区真实高度，由 build 内的 LayoutBuilder 提供，用于替代 MediaQuery 估算
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    _simulationController = SimulationPageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首算改由 build 内的 LayoutBuilder 驱动，需要先拿到真实布局约束才能分页
  }

  @override
  void didUpdateWidget(covariant CurlChapterContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有章节切换时才重置页签，字体/行高/背景调整不重置
    if (oldWidget.chapter.id != widget.chapter.id) {
      _scheduleRecalculate(resetPage: true);
    } else if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.font != widget.font) {
      _scheduleRecalculate(resetPage: false);
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

    // 通知父组件总页数和当前页码
    // SimulationPageView.jumpToPage(0) 不会触发 onPageChanged，
    // 导致父组件 _totalPages 始终为默认值1，点击右侧会错误地触发下一章
    // 必须放在 addPostFrameCallback 中执行，避免在构建阶段调用父组件 setState()
    final currentPage = resetPage
        ? (widget.jumpToLastPage ? pages.length - 1 : 0)
        : (_simulationController.currentPage ?? 0);
    final totalPages = pages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onPageChanged(currentPage, totalPages);
      }
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

  /// 计算长按位置对应的字符偏移和选中文本
  void _handleLongPress(LongPressStartDetails details, ContentPage page) {
    if (widget.onLongPressSelectText == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // 将全局坐标转换为局部坐标
    final localPos = renderBox.globalToLocal(details.globalPosition);

    // 计算文本区域的偏移（考虑 padding 和标题）
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
    final titlePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: widget.chapter.title, style: titleStyle),
    )..layout(maxWidth: MediaQuery.of(context).size.width - 40);
    final titleLineCount = (titlePainter.computeLineMetrics()).length;
    return titleLineCount * (widget.fontSize + 4) * 1.6 + 24;
  }

  /// 构建单页内容 Widget
  Widget _buildPageWidget(ContentPage page) {
    const topPadding = 12.0;
    const bottomPadding = 36.0;
    return GestureDetector(
      onLongPressStart: widget.onLongPressSelectText != null
          ? (details) => _handleLongPress(details, page)
          : null,
      child: Container(
        color: widget.background.bgColor,
        padding: const EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
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
      ),
    );
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
            onBoundaryReached: widget.onBoundaryReached,
          ),
        );
      },
    );
  }
}
