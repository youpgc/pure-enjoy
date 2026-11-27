part of 'journey_flame_game.dart';

double _particleFade(double progress) {
  final t = progress.clamp(0.0, 1.0);
  return (t < 0.12 ? t / 0.12 : 1 - t).clamp(0.0, 1.0).toDouble();
}

/// 贴图光粒：余烬、火星、尾迹与冲击环共用。
class _GlowParticle extends Particle {
  _GlowParticle({
    required this.radius,
    required this.color,
    required this.core,
    this.stretch = 1,
    super.lifespan,
  });

  final double radius;
  final Color color;
  final Color core;
  final double stretch;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final alpha = _particleFade(progress);
    if (alpha <= 0) return;
    final r = radius * (0.75 + 0.45 * progress);
    canvas.save();
    canvas.scale(1, stretch);
    _drawTinted(
      canvas,
      tex.glow,
      Rect.fromCircle(center: Offset.zero, radius: r),
      color,
      alpha,
    );
    _drawTinted(
      canvas,
      tex.glow,
      Rect.fromCircle(center: Offset.zero, radius: r * 0.44),
      core,
      alpha * 0.85,
    );
    canvas.restore();
  }
}

/// 上浮烟粒：噪声 alpha 贴图，时序上晚于焰粒出现。
class _SmokeParticle extends Particle {
  _SmokeParticle({
    required this.radius,
    required this.alpha,
    super.lifespan,
  });

  final double radius;
  final double alpha;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final a = _particleFade(progress) * alpha;
    if (a <= 0) return;
    final r = radius * (0.55 + 1.15 * progress);
    _drawPlain(
      canvas,
      tex.smoke,
      Rect.fromCircle(center: Offset.zero, radius: r),
      a,
    );
  }
}

/// 带旋转的碎块：随重力翻滚，寿命末段淡出。
class _DebrisParticle extends Particle {
  _DebrisParticle({
    required this.size,
    required this.spin,
    required this.color,
    super.lifespan,
  });

  final double size;
  final double spin;
  final Color color;

  @override
  void render(Canvas canvas) {
    final tex = JourneyFxTextures.active;
    if (tex == null) return;
    final a = _particleFade(progress);
    if (a <= 0) return;
    canvas.save();
    canvas.rotate(spin * progress);
    _drawTinted(
      canvas,
      tex.shard,
      Rect.fromCenter(center: Offset.zero, width: size * 1.4, height: size),
      color,
      a,
    );
    canvas.restore();
  }
}
