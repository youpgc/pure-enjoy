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
