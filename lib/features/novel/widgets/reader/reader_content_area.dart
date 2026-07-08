import 'package:flutter/cupertino.dart';
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
      // 滚动模式：GestureDetector 处理点击（菜单唤起），ScrollView 处理垂直滑动
      // onTap 和 onVerticalDrag 在手势竞技场中可以共存
      // 内容已在 SafeArea 内（顶部/底部状态栏已处理安全区域），不需要再加 mediaQuery.padding
      const topPadding = 12.0;
      const bottomPadding = 36.0;
      final textStyle = getCachedTextStyle();
      return GestureDetector(
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
                    final buttons = <Widget>[
                      ...editableTextState.contextMenuButtonItems.map(
                        (item) => CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onPressed: () {
                            editableTextState.hideToolbar();
                            item.onPressed?.call();
                          },
                          child: Text(item.label ?? ''),
                        ),
                      ),
                    ];
                    if (selected.start != selected.end) {
                      final selectedText = chapter!.content.substring(
                        selected.start.clamp(0, chapter!.content.length),
                        selected.end.clamp(0, chapter!.content.length),
                      );
                      buttons.add(
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onPressed: () {
                            editableTextState.hideToolbar();
                            onShowAnnotationInput(
                              selectedText,
                              selected.start,
                              selected.end,
                            );
                          },
                          child: const Text('添加批注'),
                        ),
                      );
                    }
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

    // 仿真翻页模式：使用 CurlChapterContent
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
        jumpToLastPage: shouldJumpToLastPage,
      );
    }

    // 分页模式（slide/cover）：使用 PagedChapterContent
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
      jumpToLastPage: shouldJumpToLastPage,
    );
  }
}
