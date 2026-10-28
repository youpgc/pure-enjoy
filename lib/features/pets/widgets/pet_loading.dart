// ignore_for_file: prefer_const_constructors —— 爪印字号随画布尺寸运行时定，
// TextSpan/TextStyle 无法 const 构造；本文件为自包含动画绘制器，关闭该 lint。
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 宠物模块专属 loading：爪印漫步（20261028）
///
/// 设计映射：
/// - 四枚爪印 = 四系宠物（猫/犬/兔/鼠），也暗合四维陪伴维度；
/// - 爪印全 90°、上下两行奇偶错位——左右脚印交替前行的行进感；
/// - 加载推进 = 宠物一步步走过：爪印依次点亮回弹、点亮瞬间脉冲圈、先前的渐隐，
///   循环重启即「旅程继续」。
/// - 爪印字形与提示弹窗同源（Material Icons.pets，20261028 按用户反馈重绘）。
///
/// 实现：单 AnimationController 循环 + CustomPaint 确定性绘制（无外部资源），
/// 纯装饰组件（不含交互）。颜色取主题 primary。
class PetPawLoading extends StatefulWidget {
  const PetPawLoading({super.key, this.width = 84, this.color});

  /// 整体宽度；高度 = 宽度 × 0.62
  final double width;

  /// 爪印主色（缺省取主题 primary）
  final Color? color;

  @override
  State<PetPawLoading> createState() => _PetPawLoadingState();
}

class _PetPawLoadingState extends State<PetPawLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (_, __) => CustomPaint(
          // 爪印字形 g=(宽-20)/4，同行中心距 g+4（相邻爪印间隙恒 ≥4px）；
          // 高度容纳上下两行错位（奇上偶下，交替如左右脚印前行）
          size: Size(widget.width, (widget.width - 20) / 2 + 16),
          painter: _PawWalkPainter(_clock.value, color),
        ),
      ),
    );
  }
}

class _PawWalkPainter extends CustomPainter {
  _PawWalkPainter(this.progress, this.color);

  final double progress;
  final Color color;

  static const _steps = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress % 1;
    final g = (size.width - 20) / 4; // 爪印字形尺寸（= 中心距 - 4px 间隙）

    for (var i = 0; i < _steps; i++) {
      // 爪 i 的相位：加载推进时依次点亮，一个循环内渐隐至下次轮到
      final ph = (p * _steps - i) % _steps;
      final lit = ph < 1;

      final intensity = lit ? 0.95 : 0.28;
      final scale = lit ? 1 + 0.14 * _bounce(ph) : 1.0;

      // 全部正 90°；奇数爪在上行、偶数爪在下行，上下错位如左右脚印交替前行；
      // 同行中心距 g+4（间隙 4px）
      final cx = g / 2 + 2 + i * (g + 4);
      final cy = i.isOdd ? g * 0.5 + 6 : g * 1.5 + 10;
      // 正 90° 朝向行进方向 + 两行各向外张开 ±12°（步态外八，迈步更生动）
      final rot = math.pi / 2 + (i.isOdd ? -12 : 12) * math.pi / 180;

      // 点亮瞬间：脉冲圈（渐扩渐隐）
      if (lit && ph < 0.7) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = g * 0.04
          ..color = color.withValues(alpha: (1 - ph / 0.7) * 0.35);
        canvas.drawCircle(Offset(cx, cy), g * (0.18 + ph * 0.40), ring);
      }

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.scale(scale);

      // 爪印字形（与提示弹窗同源）
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.pets.codePoint),
          style: TextStyle(
            fontSize: g,
            fontFamily: Icons.pets.fontFamily,
            package: Icons.pets.fontPackage,
            color: color.withValues(alpha: intensity),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }

  /// 点亮回弹曲线（0→1：快速弹出后小幅回落）
  double _bounce(double t) => t < 0.4 ? t / 0.4 : 1 - (t - 0.4) / 0.6 * 0.35;


  @override
  bool shouldRepaint(covariant _PawWalkPainter old) =>
      old.progress != progress || old.color != color;
}
