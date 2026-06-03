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

  ContentPage({
    required this.text,
    required this.pageIndex,
    required this.totalPages,
  });
}

/// 文本分页工具
class TextPaginator {
  /// 将长文本分页
  static List<ContentPage> paginate({
    required String text,
    required double width,
    required double height,
    required TextStyle style,
    required double lineHeight,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    if (text.isEmpty) {
      return [ContentPage(text: '', pageIndex: 0, totalPages: 1)];
    }

    final availableWidth = width - padding.horizontal;
    final availableHeight = height - padding.vertical;

    final pages = <ContentPage>[];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: style),
    );

    int start = 0;
    int pageIndex = 0;

    while (start < text.length) {
      textPainter.text = TextSpan(
        text: text.substring(start),
        style: style,
      );
      textPainter.layout(maxWidth: availableWidth);

      // 计算当前页能容纳多少行
      final lineMetrics = textPainter.computeLineMetrics();
      final lineCount = lineMetrics.length;
      final maxLines = (availableHeight / (style.fontSize! * lineHeight)).floor();

      if (lineCount <= maxLines) {
        // 剩余内容可以放在一页
        pages.add(ContentPage(
          text: text.substring(start),
          pageIndex: pageIndex,
          totalPages: pageIndex + 1,
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

/// 仿真翻页动画组件
class SimulationPageTurn extends StatefulWidget {
  final Widget currentPage;
  final Widget? nextPage;
  final VoidCallback? onTurnNext;
  final VoidCallback? onTurnPrevious;
  final Color backgroundColor;

  const SimulationPageTurn({
    super.key,
    required this.currentPage,
    this.nextPage,
    this.onTurnNext,
    this.onTurnPrevious,
    required this.backgroundColor,
  });

  @override
  State<SimulationPageTurn> createState() => _SimulationPageTurnState();
}

class _SimulationPageTurnState extends State<SimulationPageTurn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragStart = 0;
  double _dragPosition = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStart = details.globalPosition.dx;
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final width = MediaQuery.of(context).size.width;
    _dragPosition = (details.globalPosition.dx - _dragStart) / width;
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    final width = MediaQuery.of(context).size.width;

    if (_dragPosition < -0.2 || velocity < -300) {
      // 翻到下一页
      _controller.forward(from: 0).then((_) {
        widget.onTurnNext?.call();
        setState(() => _dragPosition = 0);
      });
    } else if (_dragPosition > 0.2 || velocity > 300) {
      // 翻到上一页
      _controller.forward(from: 0).then((_) {
        widget.onTurnPrevious?.call();
        setState(() => _dragPosition = 0);
      });
    } else {
      // 回弹
      setState(() => _dragPosition = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          // 下一页（底层）
          if (widget.nextPage != null) widget.nextPage!,
          // 当前页（带翻页效果）
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_dragPosition * math.pi / 2),
            alignment: Alignment.centerRight,
            child: widget.currentPage,
          ),
        ],
      ),
    );
  }
}

/// 覆盖翻页动画组件
class CoverPageTurn extends StatefulWidget {
  final Widget currentPage;
  final Widget? nextPage;
  final VoidCallback? onTurnNext;
  final VoidCallback? onTurnPrevious;

  const CoverPageTurn({
    super.key,
    required this.currentPage,
    this.nextPage,
    this.onTurnNext,
    this.onTurnPrevious,
  });

  @override
  State<CoverPageTurn> createState() => _CoverPageTurnState();
}

class _CoverPageTurnState extends State<CoverPageTurn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragPosition = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _dragPosition = details.delta.dx / width;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;

    if (_dragPosition < -0.15 || velocity < -300) {
      _controller.forward(from: 0).then((_) {
        widget.onTurnNext?.call();
        setState(() => _dragPosition = 0);
      });
    } else if (_dragPosition > 0.15 || velocity > 300) {
      _controller.forward(from: 0).then((_) {
        widget.onTurnPrevious?.call();
        setState(() => _dragPosition = 0);
      });
    } else {
      setState(() => _dragPosition = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          // 下一页
          if (widget.nextPage != null) widget.nextPage!,
          // 当前页（滑动效果）
          Transform.translate(
            offset: Offset(_dragPosition * width, 0),
            child: widget.currentPage,
          ),
        ],
      ),
    );
  }
}
