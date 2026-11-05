import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'journey_theme.dart';

/// 西行·专用 Loading（独立画风，仅游戏内使用）。
///
/// 结构：旋转紧箍双环（金）+ 中心「行」字呼吸 + 走向西方的脚印轨 +
/// 可选文案。替代通用 CircularProgressIndicator，保证画风一致。
class JourneyLoading extends StatefulWidget {
  final String? label;
  final double size;

  const JourneyLoading({super.key, this.label, this.size = 64});

  @override
  State<JourneyLoading> createState() => _JourneyLoadingState();
}

class _JourneyLoadingState extends State<JourneyLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _JourneyLoadingPainter(
                progress: _controller.value,
              ),
            ),
          ),
        ),
        if (widget.label != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(widget.label!, style: JourneyTheme.caption),
        ],
      ],
    );
  }
}

class _JourneyLoadingPainter extends CustomPainter {
  final double progress;

  _JourneyLoadingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 外环（粗，正向旋转的金箍弧段×3）
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.10
      ..strokeCap = StrokeCap.round
      ..color = JourneyTheme.gold;
    for (var i = 0; i < 3; i++) {
      final start = progress * 2 * math.pi + i * 2 * math.pi / 3;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.82),
        start,
        1.05,
        false,
        outerPaint,
      );
    }

    // 内环（细，反向旋转的细弧×2，鎏金浅色）
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055
      ..strokeCap = StrokeCap.round
      ..color = JourneyTheme.goldSoft;
    for (var i = 0; i < 2; i++) {
      final start = -progress * 2 * math.pi * 1.4 + i * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.58),
        start,
        1.4,
        false,
        innerPaint,
      );
    }

    // 中心「行」字（呼吸透明度）
    final breath = 0.62 + 0.38 * (0.5 + 0.5 * (progress * 2 % 1.0));
    final textPainter = TextPainter(
      text: TextSpan(
        text: '行',
        style: TextStyle(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          color: JourneyTheme.goldSoft.withValues(alpha: breath),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    // 环外四向脚印点（顺时针流转，示意西行不止）
    final dotPaint = Paint()..color = JourneyTheme.gold.withValues(alpha: 0.75);
    for (var i = 0; i < 4; i++) {
      final angle = -progress * 2 * math.pi + i * math.pi / 2 + 0.4;
      final pos = center +
          Offset(
            (radius * 1.02) * math.cos(angle),
            (radius * 1.02) * math.sin(angle),
          );
      canvas.drawCircle(pos, radius * 0.05, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_JourneyLoadingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
