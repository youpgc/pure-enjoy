class FormatUtils {
  static String formatWordCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}千';
    }
    return '$count';
  }
}
