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
  });

  @override
  Widget build(BuildContext context) {
    if (chapter == null) {
      return Center(child: Text('暂无章节', style: TextStyle(color: background.textColor)));
    }

    if (pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式：Stack 叠加透明点击层，使用 Listener 检测点击（不参与手势竞技场，避免与 SelectableText 冲突）
      const topPadding = 12.0;
      const bottomPadding = 36.0;
      final textStyle = getCachedTextStyle();
      return _ScrollTapDetector(
        onTapUp: onTapScreen,
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

/// 滚动模式点击检测组件
/// 使用 Listener 监听指针事件（不参与手势竞技场），避免与 SelectableText 的手势冲突
class _ScrollTapDetector extends StatefulWidget {
  final void Function(TapUpDetails) onTapUp;
  final Widget child;

  const _ScrollTapDetector({required this.onTapUp, required this.child});

  @override
  State<_ScrollTapDetector> createState() => _ScrollTapDetectorState();
}

class _ScrollTapDetectorState extends State<_ScrollTapDetector> {
  Offset? _downPos;
  int? _downTime;

  static const double _kMaxTapDistance = 24.0;
  static const int _kMaxTapDurationMs = 400;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
    );
  }
}
