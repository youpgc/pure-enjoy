import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import 'reader_text_utils.dart';

/// 带批注高亮的文本 Span 构建器
/// 缓存同章节、同字体样式下的构建结果以避免重复计算
class ReaderAnnotatedTextBuilder {
  final List<NovelAnnotation> annotations;

  TextSpan? _cachedTextSpan;
  String? _cachedSpanForChapterId;
  int? _cachedSpanFontHash;

  ReaderAnnotatedTextBuilder({required this.annotations});

  /// 获取缓存的 TextSpan（如章节和字体样式未变化）
  TextSpan? getCached(String chapterId, int fontStyleHash) {
    if (_cachedSpanForChapterId == chapterId && _cachedSpanFontHash == fontStyleHash) {
      return _cachedTextSpan;
    }
    return null;
  }

  /// 构建带高亮的 TextSpan
  TextSpan build({
    required String content,
    required TextStyle baseStyle,
    required String chapterId,
    required int fontStyleHash,
  }) {
    // 缓存命中
    if (_cachedSpanForChapterId == chapterId && _cachedSpanFontHash == fontStyleHash) {
      return _cachedTextSpan ?? TextSpan(text: content, style: baseStyle);
    }

    if (annotations.isEmpty) {
      final span = TextSpan(text: content, style: baseStyle);
      _cachedTextSpan = span;
      _cachedSpanForChapterId = chapterId;
      _cachedSpanFontHash = fontStyleHash;
      return span;
    }

    final spans = <InlineSpan>[];
    final activeAnnotations = annotations
        .where((a) => a.chapterId == chapterId)
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    if (activeAnnotations.isEmpty) {
      final span = TextSpan(text: content, style: baseStyle);
      _cachedTextSpan = span;
      _cachedSpanForChapterId = chapterId;
      _cachedSpanFontHash = fontStyleHash;
      return span;
    }

    int currentPos = 0;
    for (final annotation in activeAnnotations) {
      final start = annotation.startOffset.clamp(0, content.length);
      final end = annotation.endOffset.clamp(0, content.length);

      if (start > currentPos) {
        spans.add(TextSpan(text: content.substring(currentPos, start), style: baseStyle));
      }

      if (start < end) {
        final highlightColor = parseHighlightColor(annotation.color.name);
        spans.add(
          TextSpan(
            text: content.substring(start, end),
            style: baseStyle.copyWith(
              backgroundColor: highlightColor,
              color: Colors.black87,
            ),
          ),
        );
      }

      currentPos = end;
    }

    if (currentPos < content.length) {
      spans.add(TextSpan(text: content.substring(currentPos), style: baseStyle));
    }

    final span = TextSpan(children: spans, style: baseStyle);
    _cachedTextSpan = span;
    _cachedSpanForChapterId = chapterId;
    _cachedSpanFontHash = fontStyleHash;
    return span;
  }

  /// 清除缓存
  void clearCache() {
    _cachedTextSpan = null;
    _cachedSpanForChapterId = null;
    _cachedSpanFontHash = null;
  }
}
