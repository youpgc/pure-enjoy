part of 'journey_flame_game.dart';

/// 粒子渲染阶段统一走贴图：不再用描边路径或实心圆拼特效本体。
/// 贴图源矩形与画笔复用：Atlas 图像固定且绘制在同一帧内顺序执行，
/// 避免每个粒子每帧新建 Rect 与 Paint 造成的高频分配与 GC 抖动。
final Paint _particleTintPaint = Paint();
final Paint _particlePlainPaint = Paint();
final Map<ui.Image, Rect> _particleSrcRects = <ui.Image, Rect>{};

Rect _particleSrcRect(ui.Image image) => _particleSrcRects.putIfAbsent(
      image,
      () =>
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );

void _drawTinted(
  Canvas canvas,
  ui.Image image,
  Rect dst,
  Color tint,
  double alpha,
) {
  if (alpha <= 0) return;
  _particleTintPaint.colorFilter = ui.ColorFilter.mode(
    tint.withValues(alpha: alpha),
    ui.BlendMode.srcATop,
  );
  canvas.drawImageRect(image, _particleSrcRect(image), dst, _particleTintPaint);
}

void _drawPlain(
  Canvas canvas,
  ui.Image image,
  Rect dst,
  double alpha,
) {
  if (alpha <= 0) return;
  _particlePlainPaint.color = Color.fromRGBO(255, 255, 255, alpha);
  canvas.drawImageRect(
    image,
    _particleSrcRect(image),
    dst,
    _particlePlainPaint,
  );
}

/// 电弧贴图粒子：主弧、分叉与辉光已烘在贴图里，运行时只旋转拉伸。
class _ArcTextureParticle extends Particle {
  _ArcTextureParticle(
    this.from,
    this.to,
    this.flipY, {
    required this.thicknessRatio,
    required this.minThickness,
    super.lifespan,
  });

  final Vector2 from;
  final Vector2 to;
  final double flipY;
  final double thicknessRatio;
  final double minThickness;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final a = _particleFade(progress);
    if (a <= 0) return;
    final delta = to - from;
    final length = delta.length;
    if (length < 0.001) return;
    final thickness = math.min(
      160.0,
      math.max(minThickness, length * thicknessRatio),
    );
    canvas.save();
    canvas.rotate(math.atan2(delta.y, delta.x));
    canvas.scale(1, flipY);
    _drawPlain(
      canvas,
      tex.arc,
      Rect.fromLTWH(0, -thickness / 2, length, thickness),
      a,
    );
    canvas.restore();
  }
}

/// 光束贴图粒子：软边光幕 + 贴图光粒，替代整块扇形与实心圆点。
class _BeamParticle extends Particle {
  _BeamParticle({
    required Vector2 dir,
    required this.range,
    required math.Random rng,
    required int moteCount,
    super.lifespan,
  })  : _angle = math.atan2(dir.y, dir.x),
        _motes = <(double, double, double)>[
          for (var i = 0; i < moteCount; i++)
            (
              rng.nextDouble(),
              (rng.nextDouble() - 0.5) * 2 * kBeamHalfAngle,
              1.2 + rng.nextDouble() * 2.6
            ),
        ];

  final double _angle;
  final double range;
  final List<(double, double, double)> _motes;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final a = _particleFade(progress);
    if (a <= 0) return;
    canvas.save();
    canvas.rotate(_angle);
    final spread = math.tan(kBeamHalfAngle) * range;
    _drawPlain(
      canvas,
      tex.beam,
      Rect.fromLTWH(0, -spread * 1.35, range, spread * 2.7),
      a,
    );
    for (final mote in _motes) {
      final t = (mote.$1 + progress * 0.7) % 1;
      final x = range * t;
      final y = math.tan(mote.$2) * x;
      final r = mote.$3 * (0.6 + 0.7 * (1 - t));
      _drawTinted(
        canvas,
        tex.glow,
        Rect.fromCircle(center: Offset(x, y), radius: r),
        const Color(0xFFFFF4DC),
        a * (1 - t) * 0.9,
      );
    }
    canvas.restore();
  }
}

/// 写实火焰贴图粒子：噪声焰形自带亮核与卷曲外焰，
/// 多条不同尺寸/倾角的贴图叠加形成火舌，不再画丝带轮廓。
class _FlameTextureParticle extends Particle {
  _FlameTextureParticle({
    required this.height,
    required this.width,
    required this.phase,
    required this.tilt,
    super.lifespan,
  });

  final double height;
  final double width;
  final double phase;
  final double tilt;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final a = _particleFade(progress);
    if (a <= 0) return;
    final t = progress;
    final sway = math.sin(t * math.pi * 3 + phase) * width * 0.35;
    final w = width * 2 * (0.86 + 0.32 * t);
    final h = height * (1 - 0.12 * t);
    canvas.save();
    canvas.translate(sway, 0);
    canvas.rotate(tilt + math.sin(t * math.pi * 4 + phase) * 0.06);
    _drawPlain(
      canvas,
      tex.flame,
      Rect.fromLTWH(-w / 2, -h, w, h),
      a,
    );
    canvas.restore();
  }
}

/// 冲击环贴图粒子：带噪声断口与柔边，替代单色描边圆。
class _ShockTextureParticle extends Particle {
  _ShockTextureParticle({
    required this.radius,
    required this.color,
    super.lifespan,
  });

  final double radius;
  final Color color;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final a = _particleFade(progress);
    if (a <= 0) return;
    final r = radius * (0.52 + 0.72 * progress) / 0.7;
    _drawTinted(
      canvas,
      tex.shock,
      Rect.fromCircle(center: Offset.zero, radius: r),
      color,
      a,
    );
  }
}
