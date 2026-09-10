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

  /// 特殊糖格底光效（2026-09-10 定版样式 B，画在糖果**下方**的格底层）：
  /// - row/col：半透明白色光带贯穿整格（圆角 + 细描边）
  /// - bomb：彩虹六色光环环绕
  /// - wrap：金色礼盒缎带框（外框 + 十字缎带）
  /// [alpha] 跟随糖果消除淡出，保证光效与糖果同生命周期。
  static void drawSpecialBase(
    Canvas canvas,
    double left,
    double top,
    double cell,
    String special,
    double alpha,
  ) {
    if (alpha <= 0.01) return;
    switch (special) {
      case 'row':
      case 'col':
        final horizontal = special == 'row';
        final band = RRect.fromRectAndRadius(
          horizontal
              ? Rect.fromLTWH(left + 2, top + cell * 0.30, cell - 4, cell * 0.40)
              : Rect.fromLTWH(left + cell * 0.30, top + 2, cell * 0.40, cell - 4),
          const Radius.circular(13),
        );
        canvas.drawRRect(
          band,
          Paint()..color = Colors.white.withValues(alpha: 0.14 * alpha),
        );
        canvas.drawRRect(
          band,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
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
        final radius = cell * 0.46;
        final center = Offset(left + cell / 2, top + cell / 2);
        final sweep = 2 * pi / colors.length;
        for (var i = 0; i < colors.length; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -pi / 2 + i * sweep,
            sweep,
            false,
            Paint()
              ..color = colors[i].withValues(alpha: 0.8 * alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.055
              ..strokeCap = StrokeCap.round,
          );
        }
        break;
      case 'wrap':
        final frame = RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 3, top + 3, cell - 6, cell - 6),
          Radius.circular(cell * 0.10),
        );
        canvas.drawRRect(
          frame,
          Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.45 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        final ribbon = Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.25 * alpha)
          ..strokeWidth = 3;
        canvas.drawLine(
          Offset(left + cell / 2, top + 3),
          Offset(left + cell / 2, top + cell - 3),
          ribbon,
        );
        canvas.drawLine(
          Offset(left + 3, top + cell / 2),
          Offset(left + cell - 3, top + cell / 2),
          ribbon,
        );
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
