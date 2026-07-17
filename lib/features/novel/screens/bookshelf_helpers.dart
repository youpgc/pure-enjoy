import '../../../utils/date_time_utils.dart';
import '../../../utils/format_utils.dart';

/// 根据 progress 计算阅读状态
String getReadingStatus(double? progress) {
  if (progress == null || progress == 0) return 'unread';
  if (progress >= 1) return 'completed';
  return 'reading';
}

/// 格式化最后阅读时间
String formatBookshelfLastRead(String? lastReadAt) {
  if (lastReadAt == null) return '';
  try {
    final dateTime = DateTime.parse(lastReadAt);
    final now = DateTime.now().toUtc();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateTimeUtils.formatStandard(dateTime);
  } catch (e) {
    return '';
  }
}

/// 格式化字数
String formatBookshelfWordCount(int? wordCount) {
  if (wordCount == null || wordCount == 0) return '未知';
  return '${FormatUtils.formatWordCount(wordCount)}字';
}
