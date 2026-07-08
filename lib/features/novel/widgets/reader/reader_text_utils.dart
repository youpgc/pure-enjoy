import 'package:flutter/material.dart';
import '../../models/novel_model.dart';

/// 格式化阅读时长为易读字符串
String formatReadingDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟';
  } else if (duration.inMinutes > 0) {
    return '${duration.inMinutes}分钟';
  } else {
    return '${duration.inSeconds}秒';
  }
}

/// 将高亮颜色字符串解析为 [Color]
Color parseHighlightColor(String color) {
  switch (color) {
    case 'yellow': return const Color(0xFFFFF176);
    case 'green': return const Color(0xFFA5D6A7);
    case 'blue': return const Color(0xFF90CAF9);
    case 'pink': return const Color(0xFFF48FB1);
    case 'purple': return const Color(0xFFCE93D8);
    default: return const Color(0xFFFFF176);
  }
}

/// 将批注颜色字符串解析为 [AnnotationColor]
AnnotationColor parseAnnotationColor(String color) {
  switch (color) {
    case 'yellow': return AnnotationColor.yellow;
    case 'green': return AnnotationColor.green;
    case 'blue': return AnnotationColor.blue;
    case 'pink': return AnnotationColor.pink;
    case 'purple': return AnnotationColor.purple;
    default: return AnnotationColor.yellow;
  }
}
