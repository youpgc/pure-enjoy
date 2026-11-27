part of 'journey_flame_game.dart';

/// 程序化生成的写实向特效贴图。
///
/// 贴图在开局加载阶段生成一次并复用；渲染阶段只做 drawImageRect，
/// 不再用圆点或描边线条拼特效本体。
class JourneyFxTextures {
  JourneyFxTextures._();

  static JourneyFxTextures? active;

  static Future<void> ensureInitialized() async {
    if (active != null) return;
    final textures = JourneyFxTextures._();
    await textures._load();
    active = textures;
  }

  late final ui.Image flame;
  late final ui.Image smoke;
  late final ui.Image glow;
  late final ui.Image shock;
  late final ui.Image beam;
  late final ui.Image arc;
  late final ui.Image shard;

  Future<void> _load() async {
    flame = await _fromPixels(96, 160, _flamePixels());
    smoke = await _fromPixels(96, 96, _smokePixels());
    glow = await _fromPixels(48, 48, _glowPixels());
    shock = await _fromPixels(128, 128, _shockPixels());
    beam = await _fromPixels(256, 64, _beamPixels());
    arc = await _arcImage();
    shard = await _shardImage();
  }

  Future<ui.Image> _fromPixels(
    int width,
    int height,
    Uint8List pixels,
  ) async {
    final completer = dart_async.Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// 哈希值噪声： Atlas 只在开局生成一次，这里的计算成本可接受。
  static double _hash(int x, int y) {
    var n = (x * 374761393 + y * 668265263) & 0x7fffffff;
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff;
    return (n & 0xffffff) / 0xffffff;
  }

  static double _noise(double x, double y) {
    final xi = x.floor();
    final yi = y.floor();
    final xf = x - xi;
    final yf = y - yi;
    final u = xf * xf * (3 - 2 * xf);
    final v = yf * yf * (3 - 2 * yf);
    final a = _hash(xi, yi);
    final b = _hash(xi + 1, yi);
    final c = _hash(xi, yi + 1);
    final d = _hash(xi + 1, yi + 1);
    return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v;
  }

  static double _fbm(double x, double y) {
    var value = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 4; i++) {
      value += _noise(x, y) * amp;
      x *= 2.03;
      y *= 2.01;
      amp *= 0.5;
    }
    return value / 0.9375;
  }

  static double _smoothstep(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static void _write(
    Uint8List out,
    int i,
    double r,
    double g,
    double b,
    double alpha,
  ) {
    final a = alpha.clamp(0.0, 1.0);
    out[i] = (r * a).round();
    out[i + 1] = (g * a).round();
    out[i + 2] = (b * a).round();
    out[i + 3] = (a * 255).round();
  }

  /// 火焰贴图：底部宽亮、顶部卷曲渐细，湍流噪声打散边缘，
  /// 内芯从暖白过渡到橙红，外焰保留半透明细丝。
  static Uint8List _flamePixels() {
    const w = 96;
    const h = 160;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final v = 1 - y / (h - 1);
      for (var x = 0; x < w; x++) {
        final u = x / (w - 1) * 2 - 1;
        final turbulence = _fbm(u * 4.7 + 11, v * 5.3 + 3) - 0.5;
        final center =
            math.sin(v * 6.4 + 1.2) * 0.17 * v + turbulence * 0.22 * v;
        final half = (0.78 * math.pow(1 - v, 0.62) + 0.035) *
            (0.82 + 0.34 * _fbm(u * 3.1 + 5, v * 4.2 + 19));
        final d = ((u - center) / half).abs();
        if (d >= 1) continue;
        final edge = _smoothstep(1, 0.68, d);
        final body = (1 - d) * math.pow(1 - v, 0.5);
        final filament = math.pow(
              (1 - ((d - math.sin(v * 17 + 2.4) * 0.28).abs() * 2.4))
                  .clamp(0.0, 1.0)
                  .toDouble(),
              3,
            ) *
            (1 - v);
        final grain = 0.52 + 0.78 * _fbm(u * 9.6 + 27, v * 12.4 + 7);
        final alpha = (body * grain + filament * 0.42) *
            edge *
            (0.45 + 0.55 * _smoothstep(1, 0.15, v));
        final heat = (1 - d) * math.pow(1 - v, 0.72);
        double r;
        double g;
        double b;
        if (heat > 0.72) {
          r = 255;
          g = _lerp(232, 254, _smoothstep(0.72, 1, heat));
          b = _lerp(150, 218, _smoothstep(0.72, 1, heat));
        } else if (heat > 0.38) {
          final t = _smoothstep(0.38, 0.72, heat);
          r = 255;
          g = _lerp(128, 232, t);
          b = _lerp(22, 150, t);
        } else {
          final t = _smoothstep(0.04, 0.38, heat);
          r = _lerp(128, 255, t);
          g = _lerp(24, 128, t);
          b = 14;
        }
        _write(out, (y * w + x) * 4, r, g, b, alpha);
      }
    }
    return out;
  }

  /// 烟贴图：径向衰减叠加低频噪声，避免规则圆形边界。
  static Uint8List _smokePixels() {
    const size = 96;
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      final v = y / (size - 1) * 2 - 1;
      for (var x = 0; x < size; x++) {
        final u = x / (size - 1) * 2 - 1;
        final dist = math.sqrt(u * u + v * v);
        if (dist >= 1) continue;
        final n = _fbm(u * 3.2 + 41, v * 3.2 + 17);
        final alpha = (1 - _smoothstep(0.32, 1, dist)) *
            (0.28 + 0.72 * n) *
            (1 - dist * 0.25);
        _write(out, (y * size + x) * 4, 132, 124, 114, alpha * 0.78);
      }
    }
    return out;
  }

  /// 通用光斑：带高斯衰减的白色 alpha 遮罩，按粒子色着色。
  static Uint8List _glowPixels() {
    const size = 48;
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      final v = y / (size - 1) * 2 - 1;
      for (var x = 0; x < size; x++) {
        final u = x / (size - 1) * 2 - 1;
        final dist = math.sqrt(u * u + v * v);
        if (dist >= 1) continue;
        final alpha =
            math.exp(-dist * dist * 7.5) * (1 - _smoothstep(0.72, 1, dist));
        _write(out, (y * size + x) * 4, 255, 255, 255, alpha);
      }
    }
    return out;
  }

  /// 冲击环贴图：带噪声断口的暖色环带，替代纯色描边圆。
  static Uint8List _shockPixels() {
    const size = 128;
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      final v = y / (size - 1) * 2 - 1;
      for (var x = 0; x < size; x++) {
        final u = x / (size - 1) * 2 - 1;
        final dist = math.sqrt(u * u + v * v);
        if (dist >= 1) continue;
        final n = _fbm(u * 6 + 31, v * 6 + 13);
        final ring = math.exp(-math.pow((dist - 0.7) / 0.13, 2));
        final alpha =
            ring * (0.45 + 0.75 * n) * (1 - _smoothstep(0.9, 1, dist));
        _write(out, (y * size + x) * 4, 255, 229, 168, alpha);
      }
    }
    return out;
  }

  /// 光束贴图：横向流的软边光幕，中心亮核 + 纵向渐隐。
  static Uint8List _beamPixels() {
    const w = 256;
    const h = 64;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final v = y / (h - 1) * 2 - 1;
      for (var x = 0; x < w; x++) {
        final u = x / (w - 1);
        final falloff = math.exp(-v * v * 11);
        final core = math.exp(-v * v * 78);
        final n = _fbm(u * 8.4 + 9, v * 5.2 + 23);
        final alpha =
            (falloff * 0.38 + core * 0.72) * (0.62 + 0.56 * n) * (1 - u * 0.32);
        _write(out, (y * w + x) * 4, 255, 242, 202, alpha);
      }
    }
    return out;
  }

  /// 电弧贴图离屏栅格化：主弧、分叉与辉光都烘进贴图，
  /// 运行时只按起止点旋转拉伸，不再画线。
  static Future<ui.Image> _arcImage() async {
    const w = 256;
    const h = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rng = math.Random(431);
    final main = <Offset>[
      for (var x = 4; x <= 252; x += 18)
        Offset(x.toDouble(), 48 + (rng.nextDouble() - 0.5) * 26),
    ];
    final branches = <List<Offset>>[
      for (final t in <int>[3, 6, 9])
        <Offset>[
          main[t],
          main[t] +
              Offset(14 + rng.nextDouble() * 16, -22 - rng.nextDouble() * 12),
          main[t] +
              Offset(28 + rng.nextDouble() * 18, -34 - rng.nextDouble() * 14),
        ],
    ];

    void stroke(List<Offset> points, Color color, double width, double blur) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
      );
    }

    for (final branch in branches) {
      stroke(branch, const Color(0x6688B9EE), 12, 9);
      stroke(branch, const Color(0xCCE8F4FF), 2.2, 0);
    }
    stroke(main, const Color(0x774F9BE8), 20, 14);
    stroke(main, const Color(0xAA9CCDFA), 8, 7);
    stroke(main, const Color(0xFFFFFFFF), 2.4, 1.2);
    for (final p in main) {
      canvas.drawCircle(
        p,
        2.4,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
      );
    }
    return recorder.endRecording().toImage(w, h);
  }

  /// 碎块贴图：轻微柔边的不规则形，替代纯色矩形。
  static Future<ui.Image> _shardImage() async {
    const size = 32;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path()
      ..moveTo(8, 3)
      ..lineTo(24, 8)
      ..lineTo(28, 21)
      ..lineTo(16, 29)
      ..lineTo(4, 22)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD9B98C)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.1),
    );
    return recorder.endRecording().toImage(size, size);
  }
}
