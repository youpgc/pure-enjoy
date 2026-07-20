import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 翻页模式枚举
enum PageTurnMode {
  scroll('上下滚动', Icons.swap_vert),
  slide('左右平移', Icons.swap_horiz),
  cover('覆盖翻页', Icons.layers),
  simulation('仿真翻页', Icons.menu_book);

  const PageTurnMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 分页后的内容页
class ContentPage {
  final String text;
  final int pageIndex;
  final int totalPages;
  /// 该页文本在章节内容中的起始偏移量
  final int startOffset;
  /// 该页文本在章节内容中的结束偏移量
  final int endOffset;

  ContentPage({
    required this.text,
    required this.pageIndex,
    required this.totalPages,
    this.startOffset = 0,
    this.endOffset = 0,
  });
}

/// 文本分页工具
class TextPaginator {
  /// 将长文本分页
  /// [firstPageExtraHeight] 首页额外占用的高度（如章节标题），首页可用高度会减去该值
  /// [textScaler] 系统字体缩放，必须与渲染 Text 使用的缩放一致，
  /// 否则分页测量（默认 1.0）与真机渲染（如 OPPO 系统字体放大）不一致，
  /// 导致每页少排/多排行数，出现底部留白或内容被裁剪
  static List<ContentPage> paginate({
    required String text,
    required double width,
    required double height,
    required TextStyle style,
    required double lineHeight,
    EdgeInsets padding = EdgeInsets.zero,
    double firstPageExtraHeight = 0,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (text.isEmpty) {
      return [ContentPage(text: '', pageIndex: 0, totalPages: 1)];
    }

    final availableWidth = width - padding.horizontal;
    // 首页可用高度需减去额外占用的空间（如章节标题）
    final firstPageAvailableHeight = height - padding.vertical - firstPageExtraHeight;
    final otherPageAvailableHeight = height - padding.vertical;

    final pages = <ContentPage>[];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      text: TextSpan(text: text, style: style),
    );

    int start = 0;
    int pageIndex = 0;

    while (start < text.length) {
      final currentAvailableHeight = pageIndex == 0 ? firstPageAvailableHeight : otherPageAvailableHeight;

      textPainter.text = TextSpan(
        text: text.substring(start),
        style: style,
      );
      textPainter.layout(maxWidth: availableWidth);

      // 计算当前页能容纳多少行
      final lineMetrics = textPainter.computeLineMetrics();
      final lineCount = lineMetrics.length;
      // 行高需按系统字体缩放换算，保证与真机渲染一致
      final fontSize = textScaler.scale(style.fontSize ?? 16.0);
      final lineHeightPx = fontSize * lineHeight;
      final maxLines = lineHeightPx > 0 ? (currentAvailableHeight / lineHeightPx).floor() : 1;

      if (maxLines <= 0 || lineCount <= maxLines) {
        // 剩余内容可以放在一页（或首页空间不足时整段放入首页）
        pages.add(ContentPage(
          text: text.substring(start),
          pageIndex: pageIndex,
          totalPages: pageIndex + 1,
          startOffset: start,
          endOffset: text.length,
        ));
        break;
      }

      // 找到当前页最后一个字符的位置
      int end = text.length;
      if (lineMetrics.length > maxLines) {
        final lastLine = lineMetrics[maxLines - 1];
        final lastLineEnd = textPainter.getPositionForOffset(
          Offset(lastLine.width, lastLine.baseline),
        );
        end = start + lastLineEnd.offset;
      }

      // 避免在单词中间截断，尝试找到合适的断点
      end = _findBreakPoint(text, start, end);

      pages.add(ContentPage(
        text: text.substring(start, end),
        pageIndex: pageIndex,
        totalPages: pageIndex + 1, // 临时值，最后更新
        startOffset: start,
        endOffset: end,
      ));

      start = end;
      pageIndex++;
    }

    // 更新总页数
    final total = pages.length;
    for (int i = 0; i < pages.length; i++) {
      pages[i] = ContentPage(
        text: pages[i].text,
        pageIndex: i,
        totalPages: total,
        startOffset: pages[i].startOffset,
        endOffset: pages[i].endOffset,
      );
    }

    return pages;
  }

  /// 找到合适的文本断点
  static int _findBreakPoint(String text, int start, int end) {
    if (end >= text.length) return text.length;

    // 尝试在标点符号处断行
    const breakChars = '。，、；：？！.，,;:!?\n\r ';
    for (int i = end - 1; i > start; i--) {
      if (breakChars.contains(text[i])) {
        return i + 1;
      }
    }

    // 如果没有合适的标点，直接截断
    return end;
  }
}

/// 仿真翻页控制器
class SimulationPageController {
  _SimulationPageViewState? _state;

  void _attach(_SimulationPageViewState state) {
    _state = state;
  }

  void detach() {
    _state = null;
  }

  /// 翻到下一页
  void nextPage() {
    _state?.nextPage();
  }

  /// 翻到上一页
  void previousPage() {
    _state?.previousPage();
  }

  /// 跳转到指定页
  void jumpToPage(int page) {
    _state?.jumpToPage(page);
  }

  /// 获取当前页码
  int? get currentPage => _state?._currentPage;

  /// 获取总页数
  int? get pageCount => _state?.pageCount;
}

/// 仿真翻页组件 - 使用3D变换实现页面卷曲效果
class SimulationPageView extends StatefulWidget {
  final List<Widget> pages;
  final SimulationPageController? controller;
  final ValueChanged<int>? onPageChanged;
  /// 滑动到章节边界时的回调，isLastPage=true 表示最后一页继续向下一页滑动
  final void Function(bool isLastPage)? onBoundaryReached;
  final Color backgroundColor;
  /// 首帧初始页码（切到上一章时定位末页，避免首帧闪现章节开头）
  final int initialPage;

  const SimulationPageView({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.onBoundaryReached,
    this.backgroundColor = Colors.white,
    this.initialPage = 0,
  });

  @override
  State<SimulationPageView> createState() => _SimulationPageViewState();
}

class _SimulationPageViewState extends State<SimulationPageView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragProgress = 0.0;
  bool _isDragging = false;
  int _currentPage = 0;
  /// 边界外拉累计位移（像素），用于在首/末页触发切章
  double _boundaryDrag = 0.0;

  /// 边界切章的位移阈值（像素）
  static const double _kBoundaryDragThreshold = 60.0;

  int get pageCount => widget.pages.length;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // 以 initialPage 作为首帧页码，避免先渲染第0页（章节开头）再跳转导致的闪现
    _currentPage = widget.initialPage < widget.pages.length
        ? widget.initialPage
        : 0;
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _animationController.dispose();
    super.dispose();
  }

  void nextPage() {
    if (_currentPage < widget.pages.length - 1) {
      _animateToPage(_currentPage + 1, forward: true);
    }
  }

  void previousPage() {
    if (_currentPage > 0) {
      _animateToPage(_currentPage - 1, forward: false);
    }
  }

  void jumpToPage(int page) {
    if (page >= 0 && page < widget.pages.length) {
      setState(() {
        _currentPage = page;
      });
      widget.onPageChanged?.call(_currentPage);
    }
  }

  void _animateToPage(int targetPage, {required bool forward}) {
    setState(() {
      _dragProgress = forward ? -1.0 : 1.0;
    });

    _animationController.forward(from: 0).then((_) {
      setState(() {
        _currentPage = targetPage;
        _dragProgress = 0.0;
      });
      _animationController.reset();
      widget.onPageChanged?.call(_currentPage);
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final width = MediaQuery.of(context).size.width;
    final delta = details.delta.dx;
    final isLast = _currentPage >= widget.pages.length - 1;
    final isFirst = _currentPage <= 0;

    setState(() {
      if (delta < 0 && !isLast) {
        // 向后翻（存在下一页）
        _boundaryDrag = 0;
        _dragProgress = ((_dragProgress * width + delta) / width).clamp(-1.0, 0.0);
      } else if (delta > 0 && !isFirst) {
        // 向前翻（存在上一页）
        _boundaryDrag = 0;
        _dragProgress = ((_dragProgress * width + delta) / width).clamp(0.0, 1.0);
      } else if (delta < 0 && isLast) {
        // 最后一页继续向后拉：累计边界位移并给出轻微视觉反馈（用于切下一章）
        _boundaryDrag += -delta;
        _dragProgress = -(_boundaryDrag / width * 0.5).clamp(0.0, 0.3);
      } else if (delta > 0 && isFirst) {
        // 第一页继续向前拉：累计边界位移（用于切上一章）
        _boundaryDrag += delta;
        _dragProgress = (_boundaryDrag / width * 0.5).clamp(0.0, 0.3);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    final isLast = _currentPage >= widget.pages.length - 1;
    final isFirst = _currentPage <= 0;

    // 1. 边界切章：累计位移达到阈值或快速甩动（向左甩 velocity<0，向右甩 velocity>0）
    if (isLast && (_boundaryDrag > _kBoundaryDragThreshold || velocity < -300)) {
      _boundaryDrag = 0;
      _resetDragProgress();
      widget.onBoundaryReached?.call(true);
      return;
    }
    if (isFirst && (_boundaryDrag > _kBoundaryDragThreshold || velocity > 300)) {
      _boundaryDrag = 0;
      _resetDragProgress();
      widget.onBoundaryReached?.call(false);
      return;
    }
    _boundaryDrag = 0;

    // 2. 页内翻页
    if (_dragProgress.abs() > 0.25 || velocity.abs() > 300) {
      if (_dragProgress < 0 && _currentPage < widget.pages.length - 1) {
        _animateToPage(_currentPage + 1, forward: true);
        return;
      } else if (_dragProgress > 0 && _currentPage > 0) {
        _animateToPage(_currentPage - 1, forward: false);
        return;
      }
    }

    // 3. 回弹
    _animationController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragProgress = 0.0;
        });
      }
      _animationController.reset();
    });
  }

  /// 重置拖拽进度（边界切章触发后清理视觉反馈）
  void _resetDragProgress() {
    if (_dragProgress != 0) {
      setState(() {
        _dragProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final progress = _isDragging
                ? _dragProgress.abs()
                : _animationController.value;
            final isForward = _dragProgress < 0;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 下一页（底层）
                if (isForward && _currentPage < widget.pages.length - 1)
                  widget.pages[_currentPage + 1]
                else if (!isForward && _currentPage > 0)
                  widget.pages[_currentPage - 1]
                else
                  Container(color: widget.backgroundColor),

                // 当前页（带3D翻转效果）
                if (progress > 0)
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // 透视
                      ..rotateY(isForward ? progress * math.pi / 2.5 : -progress * math.pi / 2.5),
                    alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
                    child: widget.pages[_currentPage],
                  )
                else
                  widget.pages[_currentPage],
              ],
            );
          },
        ),
      ),
    );
  }
}
