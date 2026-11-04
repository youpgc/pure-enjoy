import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 签到弹窗暖色视觉 Token（集章卡风格，与宠物主页暖色系同源）
abstract class PetCheckinStyle {
  /// 弹窗底色
  static const sheetBg = Color(0xFFFFF9EF);

  /// 暖底卡片（统计条 / 补签条 / 已签格）
  static const warmCard = Color(0xFFFBF0DB);

  /// 次级暖底（待签格 / 说明区）
  static const softCard = Color(0xFFFAF4E8);

  /// 已签格描边
  static const cellSignedBorder = Color(0xFFE8C98A);

  /// 下次格底色（近白，突出待盖章）
  static const cellNextBg = Color(0xFFFFFDF6);

  /// 待签格描边
  static const cellFaintBorder = Color(0xFFEADFC8);

  /// 今日待签格底（陶土橙实底，参考样式）
  static const cellTodayBg = Color(0xFFC97B57);

  /// 今日待签红点徽标
  static const todayDot = Color(0xFFE6453A);

  /// 主强调金（按钮 / 下次描边 / 达标环）
  static const gold = Color(0xFFE8A33D);

  /// 深金（下次态文字 / 达标徽章文字）
  static const goldDeep = Color(0xFFC98A1F);

  /// 金币主色 / 深金币文字
  static const coin = Color(0xFFF1C04C);
  static const coinDeep = Color(0xFF7A5210);

  /// 待签金币弱化色
  static const coinFaint = Color(0xFFF5E3C0);
  static const coinFaintDeep = Color(0xFFB99B5F);

  /// 陶土红邮戳（已签戳 / 补签态）
  static const stamp = Color(0xFFD97B4A);
  static const stampBg = Color(0xFFF6DCC8);
  static const stampText = Color(0xFFC0663A);

  /// 「下次」胶囊底
  static const nextPillBg = Color(0xFFFBEDCB);

  /// 文字层级（深棕 → 浅驼）
  static const textDark = Color(0xFF5A4432);
  static const textMid = Color(0xFF8A6F4D);
  static const textLight = Color(0xFFB09A78);
  static const textFaint = Color(0xFFC4B092);
  static const textRule = Color(0xFFA08356);

  /// 点线弱色（未达连线 / 未达环）
  static const lineFaint = Color(0xFFE8D8B8);

  /// 未达徽章底
  static const badgeFaintBg = Color(0xFFF7F1E4);
}

/// 虚线圆角描边（预留画笔；日签待签格改橙底红点实底样式
///  暂无消费方，保留供补签胶囊/里程碑环等后续复用）
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    this.strokeWidth = 1.6,
    this.dash = 5,
    this.gap = 3.5,
    this.radius = 12,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap ||
      old.radius != radius;
}

/// 点状线（统计分隔线 / 里程碑连线，横竖两用）
class DottedLinePainter extends CustomPainter {
  DottedLinePainter({
    required this.color,
    this.axis = Axis.horizontal,
    this.strokeWidth = 2.5,
    this.dot = 1,
    this.gap = 6,
  });

  final Color color;
  final Axis axis;
  final double strokeWidth;
  final double dot;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final step = dot + gap;
    if (axis == Axis.horizontal) {
      for (var x = 0.0; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, size.height / 2),
            Offset(math.min(x + dot, size.width), size.height / 2), paint);
      }
    } else {
      for (var y = 0.0; y <= size.height; y += step) {
        canvas.drawLine(Offset(size.width / 2, y),
            Offset(size.width / 2, math.min(y + dot, size.height)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DottedLinePainter old) =>
      old.color != color ||
      old.axis != axis ||
      old.strokeWidth != strokeWidth ||
      old.dot != dot ||
      old.gap != gap;
}
