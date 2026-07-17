import '../../../utils/format_utils.dart';

/// 格式化字数
String formatNovelWordCount(int? wordCount) {
  if (wordCount == null) return '未知';
  return FormatUtils.formatWordCount(wordCount);
}
