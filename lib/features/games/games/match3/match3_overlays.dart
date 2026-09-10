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
