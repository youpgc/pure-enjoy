/// fontScale -> 字体大小名称映射
String scaleToFontSize(double scale) {
  if (scale <= 0.88) return '小';
  if (scale <= 1.05) return '中';
  if (scale <= 1.2) return '大';
  return '特大';
}
