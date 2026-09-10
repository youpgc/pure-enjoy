import 'dart:math' show pi;

import 'package:flutter/material.dart';

/// 关卡目标叠加层与盘面底衬绘制（网格底 / 果冻底 / 冰封盖 / 选中框）。
///
/// 与糖果绘制分离，绘制顺序由引擎控制：
/// 网格底 → 果冻（糖果**下方**，底层装饰）→ 糖果 → 冰封（糖果**上方**，
/// 遮罩感）→ 选中框。
class Match3Overlays {
  /// 网格底：表格样式（2026-09-10 二次调整）——整片深色格底 + 贯通网格线，
  /// 相邻方格间共享一条线（去圆角、去逐格描边），如同一张表格。
  /// 内线白 @12% 宽 1、外框白 @20% 宽 1.5；低饱和深底久看不疲劳。
  static void drawGrid(
    Canvas canvas,
    double offsetX,
    double offsetY,
    double cell,
    int rows,
    int cols,
  ) {
    final fill = Paint()..color = const Color(0xFF34344E);
    final board = Rect.fromLTWH(offsetX, offsetY, cell * cols, cell * rows);
    // 整片格底
    canvas.drawRect(board, fill);
    // 内部网格线（相邻格共享一条线；宽 1 防半像素发虚）
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var r = 1; r < rows; r++) {
      final y = offsetY + r * cell;
      canvas.drawLine(
          Offset(offsetX, y), Offset(offsetX + cell * cols, y), line);
    }
    for (var c = 1; c < cols; c++) {
      final x = offsetX + c * cell;
      canvas.drawLine(
          Offset(x, offsetY), Offset(x, offsetY + cell * rows), line);
    }
    // 外框（稍亮稍粗，收束边界）
    canvas.drawRect(
      board,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// 特殊糖描边环（2026-09-10 定版方案 A「霓虹描边环」，画在糖果**上方**）：
  /// 环贴图标圆形底板外缘（r≈0.49 格），不被放大后的图标遮挡。
  /// - row/col：青色霓虹环（低透明宽环打底 + 细亮环）+ 横/竖白色方向箭头
  /// - bomb：彩虹六色分段环
  /// - wrap：金色环 + 四角星光点
  /// [alpha] 跟随糖果消除淡出，保证光效与糖果同生命周期。
  static void drawSpecialRing(
    Canvas canvas,
    double left,
    double top,
    double cell,
    String special,
    double alpha,
  ) {
    if (alpha <= 0.01) return;
    final center = Offset(left + cell / 2, top + cell / 2);
    switch (special) {
      case 'row':
      case 'col':
        final horizontal = special == 'row';
        final glow = Paint()
          ..color = const Color(0xFF4DE1FF).withValues(alpha: 0.25 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.09;
        final ring = Paint()
          ..color = const Color(0xFF4DE1FF).withValues(alpha: 0.95 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.04;
        canvas.drawCircle(center, cell * 0.49, glow);
        canvas.drawCircle(center, cell * 0.49, ring);
        final arrow = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.04
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        // 横条纹：左右外向箭头；竖条纹：上下外向箭头（指示消除方向）
        if (horizontal) {
          canvas.drawLine(
            Offset(left + cell * 0.22, top + cell * 0.42),
            Offset(left + cell * 0.12, top + cell * 0.50),
            arrow,
          );
          canvas.drawLine(
            Offset(left + cell * 0.12, top + cell * 0.50),
            Offset(left + cell * 0.22, top + cell * 0.58),
            arrow,
          );
          canvas.drawLine(
            Offset(left + cell * 0.78, top + cell * 0.42),
            Offset(left + cell * 0.88, top + cell * 0.50),
            arrow,
          );
          canvas.drawLine(
            Offset(left + cell * 0.88, top + cell * 0.50),
            Offset(left + cell * 0.78, top + cell * 0.58),
            arrow,
          );
        } else {
          canvas.drawLine(
            Offset(left + cell * 0.42, top + cell * 0.22),
            Offset(left + cell * 0.50, top + cell * 0.12),
            arrow,
          );
          canvas.drawLine(
            Offset(left + cell * 0.50, top + cell * 0.12),
            Offset(left + cell * 0.58, top + cell * 0.22),
            arrow,
          );
          canvas.drawLine(
            Offset(left + cell * 0.42, top + cell * 0.78),
            Offset(left + cell * 0.50, top + cell * 0.88),
            arrow,
          );
          canvas.drawLine(
            Offset(left + cell * 0.50, top + cell * 0.88),
            Offset(left + cell * 0.58, top + cell * 0.78),
            arrow,
          );
        }
        break;
      case 'bomb':
        const colors = <Color>[
          Color(0xFFEF5350),
          Color(0xFFFFA726),
          Color(0xFF66BB6A),
          Color(0xFF42A5F5),
          Color(0xFFAB47BC),
          Color(0xFFFFEE58),
        ];
        final radius = cell * 0.49;
        final sweep = 2 * pi / colors.length;
        for (var i = 0; i < colors.length; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -pi / 2 + i * sweep,
            sweep,
            false,
            Paint()
              ..color = colors[i].withValues(alpha: 0.9 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.045
              ..strokeCap = StrokeCap.round,
          );
        }
        break;
      case 'wrap':
        final glow = Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.30 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.09;
        final ring = Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.95 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.04;
        canvas.drawCircle(center, cell * 0.49, glow);
        canvas.drawCircle(center, cell * 0.49, ring);
        // 四角星光点（45° 方位，落在图标圆板外的四角空隙）
        const double d = 0.346; // 0.5 * cos45°，星点到格心距离系数
        const double s = 0.05; // 星点半对角
        final star = Paint()
          ..color = const Color(0xFFFFF9E1).withValues(alpha: alpha);
        for (final (dx, dy) in const <(double, double)>[
          (-d, -d),
          (d, -d),
          (-d, d),
          (d, d),
        ]) {
          final cx = left + cell * (0.5 + dx);
          final cy = top + cell * (0.5 + dy);
          canvas.drawPath(
            Path()
              ..moveTo(cx, cy - cell * s)
              ..lineTo(cx + cell * s, cy)
              ..lineTo(cx, cy + cell * s)
              ..lineTo(cx - cell * s, cy)
              ..close(),
            star,
          );
        }
        break;
    }
  }

  /// 选中高亮：白色描边方框，标出当前待交换的糖块。
  static void drawSelection(
    Canvas canvas,
    double offsetX,
    double offsetY,
    double cell,
    int row,
    int col,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(offsetX + col * cell, offsetY + row * cell, cell, cell),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06,
    );
  }

  /// 果冻底：带果冻的格子铺一层半透明粉色圆角块
  static void drawJelly(Canvas canvas, double left, double top, double cell) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + cell * 0.04, top + cell * 0.04, cell * 0.92,
          cell * 0.92),
      Radius.circular(cell * 0.18),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFFFF80AB).withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFFF50057).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05,
    );
  }

  /// 冰封盖：[level] = 2 完整冰块（厚），1 已裂开（薄 + 裂纹）
  static void drawIce(
    Canvas canvas,
    double left,
    double top,
    double cell,
    int level,
  ) {
    if (level <= 0) return;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + cell * 0.02, top + cell * 0.02, cell * 0.96,
          cell * 0.96),
      Radius.circular(cell * 0.14),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: level >= 2 ? 0.62 : 0.34),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF81D4FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * (level >= 2 ? 0.07 : 0.04),
    );
    // 裂纹：裂开状态画一道折线，给出「再消一次就碎」的视觉反馈
    if (level == 1) {
      final path = Path()
        ..moveTo(left + cell * 0.2, top + cell * 0.25)
        ..lineTo(left + cell * 0.5, top + cell * 0.5)
        ..lineTo(left + cell * 0.34, top + cell * 0.66)
        ..lineTo(left + cell * 0.74, top + cell * 0.82);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0288D1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.045,
      );
    }
  }
}
