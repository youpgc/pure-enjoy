import 'package:flutter/material.dart';

/// 关卡目标叠加层与盘面底衬绘制（网格底 / 果冻底 / 冰封盖 / 选中框）。
///
/// 与糖果绘制分离，绘制顺序由引擎控制：
/// 网格底 → 果冻（糖果**下方**，底层装饰）→ 糖果 → 冰封（糖果**上方**，
/// 遮罩感）→ 选中框。
class Match3Overlays {
  /// 网格底：深色圆角格底 + 浅色细描边（2026-09-10 定版动物头像接入后，
  /// 白底与彩色头像对比过强刺眼）。格底比底板略亮形成分区，浅色描边
  /// （白 @10%）勾勒格界突显方块间距；低饱和深底久看不疲劳。
  static void drawGrid(
    Canvas canvas,
    double offsetX,
    double offsetY,
    double cell,
    int rows,
    int cols,
  ) {
    final fill = Paint()..color = const Color(0xFF34344E);
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offsetX + c * cell + cell * 0.03,
            offsetY + r * cell + cell * 0.03,
            cell * 0.94,
            cell * 0.94,
          ),
          Radius.circular(cell * 0.18),
        );
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, border);
      }
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
