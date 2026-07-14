import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../reader_enums.dart';
import '../reader_page_turn.dart';
import '../paged_chapter_content.dart';
import '../curl_chapter_content.dart';

/// 小说阅读器正文内容区域
/// 根据翻页模式渲染不同的内容组件：滚动、仿真翻页、分页（滑动/覆盖）
class ReaderContentArea extends StatelessWidget {
  final PageTurnMode pageTurnMode;
  final NovelChapterModel? chapter;
  final ReaderBackground background;
  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final GlobalKey<PagedChapterContentState> pagedContentKey;
  final GlobalKey<CurlChapterContentState> curlContentKey;
  final void Function(int currentPage, int totalPages) onPageChanged;
  final void Function(bool isLastPage) onBoundaryReached;
  final void Function(TapUpDetails) onTapScreen;
  final bool shouldJumpToLastPage;
  final ScrollController scrollController;
  final TextSpan Function(String content, TextStyle baseStyle) buildAnnotatedTextSpan;
  final void Function(TextSelection?)? onSelectionChanged;
  final void Function(String selectedText, int startOffset, int endOffset) onShowAnnotationInput;
  final TextStyle Function({bool isTitle}) getCachedTextStyle;
  final void Function(bool isEnd)? onScrollOvershoot;
  final void Function(double progress)? onScrollOvershootProgress;

  const ReaderContentArea({
    super.key,
    required this.pageTurnMode,
    this.chapter,
    required this.background,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.pagedContentKey,
    required this.curlContentKey,
    required this.onPageChanged,
    required this.onBoundaryReached,
    required this.onTapScreen,
    required this.shouldJumpToLastPage,
    required this.scrollController,
    required this.buildAnnotatedTextSpan,
    this.onSelectionChanged,
    required this.onShowAnnotationInput,
    required this.getCachedTextStyle,
    this.onScrollOvershoot,
    this.onScrollOvershootProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (chapter == null) {
      return Center(child: Text('暂无章节', style: TextStyle(color: background.textColor)));
    }

    if (pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式：Stack 叠加透明点击层，使用 Listener 检测点击（不参与手势竞技场，避免与 SelectableText 冲突）
      // 同时通过 NotificationListener 检测 overscroll 以实现章节切换
      const topPadding = 12.0;
      const bottomPadding = 36.0;
      final textStyle = getCachedTextStyle();
      return _ScrollModeWrapper(
        onTapUp: onTapScreen,
        onOvershoot: onScrollOvershoot,
        onOvershootProgress: onScrollOvershootProgress,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      chapter!.title,
                      style: getCachedTextStyle(isTitle: true),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SelectableText.rich(
                  buildAnnotatedTextSpan(
                    chapter!.content,
                    textStyle,
                  ),
                  style: textStyle,
                  onSelectionChanged: (selection, cause) {
                    onSelectionChanged?.call(selection);
                  },
                  contextMenuBuilder: (context, editableTextState) {
                    final selected = editableTextState.textEditingValue.selection;
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: [
                        ...editableTextState.contextMenuButtonItems,
                        if (selected.start != selected.end)
                          ContextMenuButtonItem(
                            label: '添加批注',
                            onPressed: () {
                              editableTextState.hideToolbar();
                              final selectedText = chapter!.content.substring(
                                selected.start.clamp(0, chapter!.content.length),
                                selected.end.clamp(0, chapter!.content.length),
                              );
                              onShowAnnotationInput(
                                selectedText,
                                selected.start,
                                selected.end,
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    '${chapter!.title} - 完',
                    style: TextStyle(fontSize: 14, color: background.textColor.withValues(alpha: 0.5)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    // 仿真翻页模式：使用 CurlChapterContent，长按选择文本
    if (pageTurnMode == PageTurnMode.simulation) {
      return CurlChapterContent(
        key: curlContentKey,
        chapter: chapter!,
        background: background,
        font: font,
        fontSize: fontSize,
        lineHeight: lineHeight,
        onPageChanged: onPageChanged,
        onBoundaryReached: onBoundaryReached,
        onTapScreen: onTapScreen,
        onLongPressSelectText: onShowAnnotationInput,
        jumpToLastPage: shouldJumpToLastPage,
      );
    }

    // 分页模式（slide/cover）：使用 PagedChapterContent，长按选择文本
    return PagedChapterContent(
      key: pagedContentKey,
      chapter: chapter!,
      background: background,
      font: font,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageTurnMode: pageTurnMode,
      onPageChanged: onPageChanged,
      onBoundaryReached: onBoundaryReached,
      onTapScreen: onTapScreen,
      onLongPressSelectText: onShowAnnotationInput,
      jumpToLastPage: shouldJumpToLastPage,
    );
  }
}

/// 滚动模式包装组件
/// 同时处理：1) 点击检测（Listener，不参与手势竞技场） 2) overscroll 检测（NotificationListener）
/// 避免与 SelectableText 的手势冲突
class _ScrollModeWrapper extends StatefulWidget {
  final void Function(TapUpDetails) onTapUp;
  final void Function(bool isEnd)? onOvershoot;
  final void Function(double progress)? onOvershootProgress;
  final Widget child;

  const _ScrollModeWrapper({
    required this.onTapUp,
    this.onOvershoot,
    this.onOvershootProgress,
    required this.child,
  });

  @override
  State<_ScrollModeWrapper> createState() => _ScrollModeWrapperState();
}

class _ScrollModeWrapperState extends State<_ScrollModeWrapper> {
  Offset? _downPos;
  int? _downTime;
  double _overshootAccumulated = 0.0;
  int _overshootDirection = 0; // 1 = end (next), -1 = start (prev)

  static const double _kMaxTapDistance = 24.0;
  static const int _kMaxTapDurationMs = 400;
  static const double _kOvershootThreshold = 120.0;

  void _resetOvershoot() {
    if (_overshootAccumulated != 0 || _overshootDirection != 0) {
      _overshootAccumulated = 0.0;
      _overshootDirection = 0;
      widget.onOvershootProgress?.call(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          final delta = notification.scrollDelta ?? 0;

          // 底部 overshoot：滚动到底后继续向下滑动（scrollDelta > 0）
          if (metrics.pixels >= metrics.maxScrollExtent - 0.5 && delta > 0) {
            if (_overshootDirection == -1) _overshootAccumulated = 0;
            _overshootDirection = 1;
            _overshootAccumulated += delta;
            final progress = (_overshootAccumulated / _kOvershootThreshold).clamp(0.0, 1.0);
            widget.onOvershootProgress?.call(progress);
            if (_overshootAccumulated >= _kOvershootThreshold) {
              _resetOvershoot();
              widget.onOvershoot?.call(true);
            }
          }
          // 顶部 overshoot：滚动到顶后继续向上滑动（scrollDelta < 0）
          else if (metrics.pixels <= 0.5 && delta < 0) {
            if (_overshootDirection == 1) _overshootAccumulated = 0;
            _overshootDirection = -1;
            _overshootAccumulated += delta.abs();
            final progress = -(_overshootAccumulated / _kOvershootThreshold).clamp(0.0, 1.0);
            widget.onOvershootProgress?.call(progress);
            if (_overshootAccumulated >= _kOvershootThreshold) {
              _resetOvershoot();
              widget.onOvershoot?.call(false);
            }
          } else {
            _resetOvershoot();
          }
        } else if (notification is ScrollEndNotification) {
          if (_overshootAccumulated > 0 && _overshootAccumulated < _kOvershootThreshold) {
            _resetOvershoot();
          }
        }
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _downPos = e.position;
                _downTime = DateTime.now().millisecondsSinceEpoch;
              },
              onPointerUp: (e) {
                if (_downPos == null || _downTime == null) return;
                final dist = (e.position - _downPos!).distance;
                final duration = DateTime.now().millisecondsSinceEpoch - _downTime!;
                _downPos = null;
                _downTime = null;
                // 轻触（短距离 + 短时间）视为点击，触发菜单
                if (dist < _kMaxTapDistance && duration < _kMaxTapDurationMs) {
                  widget.onTapUp(TapUpDetails(kind: e.kind, globalPosition: e.position));
                } else if (_overshootAccumulated > 0 && _overshootAccumulated < _kOvershootThreshold) {
                  // 手指释放时 overshoot 未达到阈值，重置
                  _resetOvershoot();
                }
              },
              onPointerCancel: (_) {
                _downPos = null;
                _downTime = null;
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}
