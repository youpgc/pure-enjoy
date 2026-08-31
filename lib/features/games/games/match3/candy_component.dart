import 'dart:math';

import 'package:flutter/material.dart';

/// 消消乐方块数据模型（纯数据，由 FlameGame 统一绘制与驱动动画）。
///
/// [px]/[py] 为当前像素左上角，[update] 中向目标格 (row,col) 缓动；[scale]
/// 用于消除时的缩放弹出；[special] 标记特殊糖（'row'/'col' 条纹、'bomb' 彩爆、'wrap' 包装）。
class Candy {
  int type;
  String special;
  int row;
  int col;
  double px;
  double py;
  double scale;
  bool dying;

  Candy(
    this.type,
    this.row,
    this.col,
    this.px,
    this.py, {
    this.special = '',
    this.scale = 1,
    this.dying = false,
  });

  double get cx => px;
  double get cy => py;
}

/// 在指定格绘制一个卡通糖块（矢量自绘，无位图）。
///
/// [cell] 为格子边长；方块中心位于 (px+cell/2, py+cell/2)。
void drawCandy(Canvas canvas, Candy candy, double cell, Color color) {
  final r = cell * 0.42 * candy.scale;
  final cx = candy.px + cell / 2;
  final cy = candy.py + cell / 2;
  if (r <= 0) return;

  final Path path = _shapePath(candy.type, cx, cy, r);

  // 投影：让糖块从深色底板浮起，避免与背景糊在一起（缓解久看眼累）
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  // 主体
  canvas.drawPath(path, Paint()..color = color);
  // 加粗描边：清晰界定形状、提升辨识度（对比深色底板）
  canvas.drawPath(
    path,
    Paint()
      ..color = color.darken(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.08,
  );

  // 高光：更亮、更聚焦的椭圆，增强立体与清晰感
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(cx - r * 0.3, cy - r * 0.35),
      width: r * 0.5,
      height: r * 0.7,
    ),
    Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.55),
  );

  // 特殊糖标识
  switch (candy.special) {
    case 'row':
      _drawStripes(canvas, cx, cy, r, true);
      break;
    case 'col':
      _drawStripes(canvas, cx, cy, r, false);
      break;
    case 'bomb':
      _drawBomb(canvas, cx, cy, r);
      break;
    case 'wrap':
      canvas.drawCircle(
        Offset(cx, cy),
        r * 0.9,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06,
      );
      break;
  }
}

Path _shapePath(int type, double cx, double cy, double r) {
  final p = Path();
  switch (type % 6) {
    case 0: // 圆
      p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      break;
    case 1: // 圆角方块
      p.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 1.9, height: r * 1.9),
          Radius.circular(r * 0.4),
        ),
      );
      break;
    case 2: // 三角
      p.moveTo(cx, cy - r);
      p.lineTo(cx + r * 0.92, cy + r * 0.7);
      p.lineTo(cx - r * 0.92, cy + r * 0.7);
      p.close();
      break;
    case 3: // 六边形
      for (var i = 0; i < 6; i++) {
        final a = pi / 6 + i * pi / 3;
        final x = cx + r * cos(a);
        final y = cy + r * sin(a);
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      p.close();
      break;
    case 4: // 星形
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? r : r * 0.45;
        final a = -pi / 2 + i * pi / 5;
        final x = cx + rr * cos(a);
        final y = cy + rr * sin(a);
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      p.close();
      break;
    default: // 菱形
      p.moveTo(cx, cy - r);
      p.lineTo(cx + r, cy);
      p.lineTo(cx, cy + r);
      p.lineTo(cx - r, cy);
      p.close();
      break;
  }
  return p;
}

void _drawStripes(Canvas canvas, double cx, double cy, double r, bool horizontal) {
  final paint = Paint()
    ..color = Colors.white.withOpacity(0.8)
    ..strokeWidth = r * 0.18
    ..strokeCap = StrokeCap.round;
  for (var i = -1; i <= 1; i++) {
    if (horizontal) {
      canvas.drawLine(
        Offset(cx - r * 0.7, cy + i * r * 0.4),
        Offset(cx + r * 0.7, cy + i * r * 0.4),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(cx + i * r * 0.4, cy - r * 0.7),
        Offset(cx + i * r * 0.4, cy + r * 0.7),
        paint,
      );
    }
  }
}

void _drawBomb(Canvas canvas, double cx, double cy, double r) {
  final colors = <Color>[
    const Color(0xFFEF5350),
    const Color(0xFF42A5F5),
    const Color(0xFF66BB6A),
    const Color(0xFFFFEE58),
    const Color(0xFFAB47BC),
    const Color(0xFFFFA726),
  ];
  for (var i = 0; i < colors.length; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.7),
      i * 2 * pi / colors.length,
      2 * pi / colors.length,
      true,
      Paint()..color = colors[i],
    );
  }
  canvas.drawCircle(
    Offset(cx, cy),
    r * 0.32,
    Paint()..color = Colors.white,
  );
}

extension _ColorDarken on Color {
  Color darken(double amount) {
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round().clamp(0, 255),
      (green * f).round().clamp(0, 255),
      (blue * f).round().clamp(0, 255),
    );
  }
}
