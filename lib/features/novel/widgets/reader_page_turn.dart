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

/// 仿真翻页控制器
class SimulationPageController {
  _SimulationPageViewState? _state;

  void _attach(_SimulationPageViewState state) {
    _state = state;
  }

  void _detach() {
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
  int? get pageCount => _state?._pages.length;
}

/// 仿真翻页组件 - 使用Canvas实现页面卷曲效果
class SimulationPageView extends StatefulWidget {
  final List<Widget> pages;
  final SimulationPageController? controller;
  final ValueChanged<int>? onPageChanged;
  final Color backgroundColor;
  final double shadowOpacity;

  const SimulationPageView({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.backgroundColor = Colors.white,
    this.shadowOpacity = 0.3,
  });

  @override
  State<SimulationPageView> createState() => _SimulationPageViewState();
}

class _SimulationPageViewState extends State<SimulationPageView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragProgress = 0.0; // -1.0 到 1.0，负值表示向左翻（下一页），正值表示向右翻（上一页）
  bool _isDragging = false;
  int _currentPage = 0;
  double _dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach();
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
    _dragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final width = MediaQuery.of(context).size.width;
    final delta = details.globalPosition.dx - _dragStartX;

    setState(() {
      // 根据拖动方向和当前页码限制翻页
      if (delta < 0 && _currentPage < widget.pages.length - 1) {
        // 向左拖动，翻到下一页
        _dragProgress = (delta / width).clamp(-1.0, 0.0);
      } else if (delta > 0 && _currentPage > 0) {
        // 向右拖动，翻到上一页
        _dragProgress = (delta / width).clamp(0.0, 1.0);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    final width = MediaQuery.of(context).size.width;

    // 根据拖动进度和速度决定是否翻页
    if (_dragProgress.abs() > 0.3 || velocity.abs() > 300) {
      if (_dragProgress < 0 && _currentPage < widget.pages.length - 1) {
        // 翻到下一页
        _animateToPage(_currentPage + 1, forward: true);
        return;
      } else if (_dragProgress > 0 && _currentPage > 0) {
        // 翻到上一页
        _animateToPage(_currentPage - 1, forward: false);
        return;
      }
    }

    // 回弹
    _animationController.forward(from: 0).then((_) {
      setState(() {
        _dragProgress = 0.0;
      });
      _animationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _isDragging
              ? _dragProgress.abs()
              : _animationController.value;
          final direction = _dragProgress < 0 ? -1 : 1;

          return CustomPaint(
            size: Size.infinite,
            painter: _PageCurlPainter(
              currentPage: widget.pages[_currentPage],
              nextPage: _dragProgress < 0 && _currentPage < widget.pages.length - 1
                  ? widget.pages[_currentPage + 1]
                  : _dragProgress > 0 && _currentPage > 0
                      ? widget.pages[_currentPage - 1]
                      : null,
              progress: progress,
              direction: direction,
              backgroundColor: widget.backgroundColor,
              shadowOpacity: widget.shadowOpacity,
            ),
          );
        },
      ),
    );
  }
}

/// 页面卷曲绘制器
class _PageCurlPainter extends CustomPainter {
  final Widget currentPage;
  final Widget? nextPage;
  final double progress; // 0.0 到 1.0
  final int direction; // -1 表示向左翻（下一页），1 表示向右翻（上一页）
  final Color backgroundColor;
  final double shadowOpacity;

  _PageCurlPainter({
    required this.currentPage,
    this.nextPage,
    required this.progress,
    required this.direction,
    required this.backgroundColor,
    required this.shadowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) {
      // 没有翻页动作，只绘制当前页
      _drawWidget(canvas, size, currentPage);
      return;
    }

    final width = size.width;
    final height = size.height;

    // 计算卷曲位置
    final curlX = direction < 0
        ? width * (1 - progress) // 向左翻，从右边缘开始
        : width * progress; // 向右翻，从左边缘开始

    // 绘制下一页（底层）
    if (nextPage != null) {
      _drawWidget(canvas, size, nextPage!);
    } else {
      // 没有下一页，绘制背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = backgroundColor,
      );
    }

    // 绘制当前页的卷曲效果
    _drawCurledPage(canvas, size, curlX, direction);

    // 绘制阴影
    _drawShadow(canvas, size, curlX, direction);
  }

  void _drawWidget(Canvas canvas, Size size, Widget widget) {
    // 使用 PictureRecorder 将 Widget 转为 Image
    final recorder = PictureRecorder();
    final canvas2 = Canvas(recorder);

    // 创建一个虚拟的 BuildContext 来渲染 widget
    // 这里简化处理，实际应该使用 RepaintBoundary
    // 由于 CustomPainter 中无法直接渲染 Widget，我们使用占位符
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );
  }

  void _drawCurledPage(Canvas canvas, Size size, double curlX, int direction) {
    final width = size.width;
    final height = size.height;

    // 创建页面路径
    final path = Path();

    if (direction < 0) {
      // 向左翻页 - 从右边缘卷曲
      path.moveTo(0, 0);
      path.lineTo(curlX, 0);

      // 卷曲的曲线
      final controlPointX = curlX + (width - curlX) * 0.5;
      path.quadraticBezierTo(controlPointX, height * 0.25, curlX, height * 0.5);
      path.quadraticBezierTo(controlPointX, height * 0.75, curlX, height);

      path.lineTo(0, height);
      path.close();
    } else {
      // 向右翻页 - 从左边缘卷曲
      path.moveTo(width, 0);
      path.lineTo(curlX, 0);

      // 卷曲的曲线
      final controlPointX = curlX * 0.5;
      path.quadraticBezierTo(controlPointX, height * 0.25, curlX, height * 0.5);
      path.quadraticBezierTo(controlPointX, height * 0.75, curlX, height);

      path.lineTo(width, height);
      path.close();
    }

    // 绘制页面背景
    canvas.drawPath(
      path,
      Paint()..color = backgroundColor,
    );

    // 绘制页面边缘的高光效果（模拟纸张厚度）
    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: direction < 0 ? Alignment.centerRight : Alignment.centerLeft,
        end: direction < 0 ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(path, edgePaint);
  }

  void _drawShadow(Canvas canvas, Size size, double curlX, int direction) {
    final width = size.width;
    final height = size.height;

    // 阴影路径
    final shadowPath = Path();
    final shadowWidth = 20.0 * progress;

    if (direction < 0) {
      // 向左翻页的阴影
      shadowPath.moveTo(curlX, 0);
      shadowPath.lineTo(curlX + shadowWidth, 0);
      shadowPath.lineTo(curlX + shadowWidth, height);
      shadowPath.lineTo(curlX, height);
    } else {
      // 向右翻页的阴影
      shadowPath.moveTo(curlX - shadowWidth, 0);
      shadowPath.lineTo(curlX, 0);
      shadowPath.lineTo(curlX, height);
      shadowPath.lineTo(curlX - shadowWidth, height);
    }
    shadowPath.close();

    // 绘制渐变阴影
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: direction < 0 ? Alignment.centerLeft : Alignment.centerRight,
        end: direction < 0 ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Colors.black.withOpacity(shadowOpacity * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(shadowPath, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _PageCurlPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction ||
        oldDelegate.currentPage != currentPage ||
        oldDelegate.nextPage != nextPage;
  }
}

/// 简化的仿真翻页组件 - 使用3D变换实现
class SimpleSimulationPageView extends StatefulWidget {
  final List<Widget> pages;
  final SimulationPageController? controller;
  final ValueChanged<int>? onPageChanged;
  final Color backgroundColor;

  const SimpleSimulationPageView({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.backgroundColor = Colors.white,
  });

  @override
  State<SimpleSimulationPageView> createState() => _SimpleSimulationPageViewState();
}

class _SimpleSimulationPageViewState extends State<SimpleSimulationPageView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragProgress = 0.0;
  bool _isDragging = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    widget.controller?._attach(this as _SimulationPageViewState);
  }

  @override
  void dispose() {
    widget.controller?._detach();
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

    setState(() {
      if (delta < 0 && _currentPage < widget.pages.length - 1) {
        _dragProgress = ((_dragProgress * width + delta) / width).clamp(-1.0, 0.0);
      } else if (delta > 0 && _currentPage > 0) {
        _dragProgress = ((_dragProgress * width + delta) / width).clamp(0.0, 1.0);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;

    if (_dragProgress.abs() > 0.25 || velocity.abs() > 300) {
      if (_dragProgress < 0 && _currentPage < widget.pages.length - 1) {
        _animateToPage(_currentPage + 1, forward: true);
        return;
      } else if (_dragProgress > 0 && _currentPage > 0) {
        _animateToPage(_currentPage - 1, forward: false);
        return;
      }
    }

    // 回弹
    _animationController.forward(from: 0).then((_) {
      setState(() {
        _dragProgress = 0.0;
      });
      _animationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _isDragging
              ? _dragProgress.abs()
              : _animationController.value;
          final isForward = _dragProgress < 0;

          return Stack(
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
    );
  }
}
