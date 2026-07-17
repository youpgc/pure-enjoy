import '../../../core/theme/theme_provider.dart';

/// fontScale -> 字体大小名称映射
String scaleToFontSize(double scale) {
  if (scale <= 0.88) return '小';
  if (scale <= 1.05) return '中';
  if (scale <= 1.2) return '大';
  return '特大';
}

/// 阅读背景名称映射
String bgToName(ReaderBackgroundTheme bg) {
  if (bg == ReaderBackgroundTheme.defaultWhite) return '默认';
  if (bg == ReaderBackgroundTheme.warmYellow) return '暖黄';
  if (bg == ReaderBackgroundTheme.darkGray) return '深色';
  if (bg == ReaderBackgroundTheme.pureBlack) return '纯黑';
  if (bg == ReaderBackgroundTheme.lightGreen) return '护眼绿';
  if (bg == ReaderBackgroundTheme.lightBlue) return '淡蓝';
  if (bg == ReaderBackgroundTheme.lightPink) return '淡粉';
  if (bg == ReaderBackgroundTheme.brown) return '牛皮纸';
  return bg.label;
}
