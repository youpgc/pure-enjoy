import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 舞台特效种类（由 [PetAction] 映射触发，纯表现层，不参与任何数值判定）
enum PetFxKind {
  /// 被抚摸：爱心上飘
  hearts,

  /// 开心：星星迸发
  stars,

  /// 进食：碎屑下坠
  crumbs,

  /// 睡觉：Z 字缓升
  zzz,

  /// 进化：冲击波圆环
  ring,

  /// 进化：竖直光柱
  beam,
}

/// 宠物舞台粒子层控制器
///
/// 范式沿用消消乐特效层（`games/match3/match3_effects.dart`）：纯 Canvas 自绘、
/// 零外部素材、各类设存活上限限流；不引入粒子库、不加依赖。
///
/// 时钟只在有活跃特效时运行（emit 启动、清空即停），空闲零开销；
/// `CustomPaint(repaint: this)` 逐帧只走 paint 不重建 widget 树。
///
/// 坐标用 [Alignment] 表达（宿主不知道舞台像素尺寸），[attach] 由浮层在布局后
/// 回填尺寸；尺寸未就绪时 emit 直接丢弃（特效丢了不可感知，不排队补偿）。
class PetFxController extends ChangeNotifier {
  PetFxController({required TickerProvider vsync, math.Random? rng})
      : _rng = rng ?? math.Random() {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  final math.Random _rng;
  Size _size = Size.zero;
  Duration? _last;

  final List<_Pt> _pts = <_Pt>[];
  final List<_Ring> _rings = <_Ring>[];
  final List<_Beam> _beams = <_Beam>[];

  /// 各类上限：连点/深度演出时限流，避免帧率塌陷
  static const int _maxPts = 60;
  static const int _maxRings = 4;
  static const int _maxBeams = 1;

  bool get isEmpty => _pts.isEmpty && _rings.isEmpty && _beams.isEmpty;

  /// 浮层每帧回填绘制区尺寸（画笔在 paint 里调用）
  void attach(Size size) {
    _size = size;
  }

  /// 舞台内某处迸发特效；[align] 为相对绘制区的锚点（默认宠物胸口偏上）
  void emit(PetFxKind kind, Color color,
      {Alignment align = const Alignment(0, -0.25)}) {
    if (_size.isEmpty) return;
    final center = align.alongSize(_size);
    switch (kind) {
      case PetFxKind.hearts:
        _spawn(kind,
            count: 6,
            dur: 1.5,
            color: color,
            center: center,
            spreadX: 26,
            speed: 74,
            spin: 1.6,
            size: 13);
      case PetFxKind.stars:
        _spawn(kind,
            count: 9,
            dur: 0.9,
            color: color,
            center: center,
            spreadX: 150,
            speed: 150,
            gravity: 260,
            spin: 6,
            size: 9,
            radial: true);
      case PetFxKind.crumbs:
        _spawn(kind,
            count: 8,
            dur: 0.75,
            color: color,
            center: center,
            spreadX: 90,
            speed: 60,
            gravity: 620,
            size: 6,
            upward: false);
      case PetFxKind.zzz:
        _spawn(kind,
            count: 3,
            dur: 2.2,
            color: color,
            center: center,
            spreadX: 10,
            speed: 34,
            size: 17);
      case PetFxKind.ring:
        if (_rings.length >= _maxRings) return;
        _rings.add(_Ring(
            center: center, radius: _size.shortestSide * 0.42, color: color));
      case PetFxKind.beam:
        if (_beams.length >= _maxBeams) return;
        _beams.add(_Beam(center: center, color: color, height: _size.height));
    }
    _start();
    notifyListeners();
  }

  /// 立即清空（切宠/离场）
  void clear() {
    _pts.clear();
    _rings.clear();
    _beams.clear();
    _ticker.stop();
    _last = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _spawn(
    PetFxKind kind, {
    required int count,
    required double dur,
    required Color color,
    required Offset center,
    required double spreadX,
    required double speed,
    required double size,
    double gravity = 0,
    double spin = 0,
    bool upward = true,
    bool radial = false,
  }) {
    final budget = _maxPts - _pts.length;
    if (budget <= 0) return;
    final n = math.min(count, budget);
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * math.pi;
      final dir = _rng.nextDouble() * 2 - 1;
      final vy = speed * (0.75 + _rng.nextDouble() * 0.5);
      _pts.add(_Pt(
        kind: kind,
        color: color,
        fontSize: size,
        pos: Offset(center.dx + dir * spreadX * 0.35, center.dy),
        // radial：四散成球（星星）；否则先向上喷再由重力回落
        vel: radial
            ? Offset(math.cos(a) * spreadX, math.sin(a) * speed)
            : Offset(math.cos(a) * spreadX * 0.4, upward ? -vy : vy),
        gravity: gravity,
        spin: spin * dir,
        size: size * (0.75 + _rng.nextDouble() * 0.5),
        dur: dur * (0.85 + _rng.nextDouble() * 0.3),
        // 逐个错开 50ms 出场，避免整簇同时爆开
        delay: i * 0.05,
      ));
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == null
        ? 1 / 60
        : (elapsed - _last!).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;

    for (final p in _pts) {
      if (p.delay > 0) {
        p.delay -= dt;
        continue;
      }
      p.age += dt;
      p.vel = Offset(p.vel.dx, p.vel.dy + p.gravity * dt);
      p.pos = p.pos + p.vel * dt;
      p.rot += p.spin * dt;
    }
    _pts.removeWhere((p) => p.age >= p.dur);

    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age >= _Ring.dur);

    for (final b in _beams) {
      b.age += dt;
    }
    _beams.removeWhere((b) => b.age >= _Beam.dur);

    if (isEmpty) {
      _ticker.stop();
      _last = null;
    }
    notifyListeners();
  }
}

/// 粒子层画笔（`CustomPaint.repaint` 直接挂控制器，逐帧只走 paint）
class PetFxPainter extends CustomPainter {
  PetFxPainter(this.fx) : super(repaint: fx);

  final PetFxController fx;

  @override
  void paint(Canvas canvas, Size size) {
    fx.attach(size);
    if (fx.isEmpty) return;
    for (final b in fx._beams) {
      _drawBeam(canvas, b);
    }
    for (final r in fx._rings) {
      _drawRing(canvas, r);
    }
    for (final p in fx._pts) {
      _drawPoint(canvas, p);
    }
  }

  @override
  bool shouldRepaint(covariant PetFxPainter old) => old.fx != fx;
}

void _drawRing(Canvas canvas, _Ring r) {
  final t = (r.age / _Ring.dur).clamp(0.0, 1.0);
  canvas.drawCircle(
    r.center,
    r.radius * Curves.easeOut.transform(t),
    Paint()
      ..color = r.color.withValues(alpha: (1 - t) * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r.radius * 0.12 * (1 - t * 0.7).clamp(0.05, 1.0),
  );
}

void _drawBeam(Canvas canvas, _Beam b) {
  final t = (b.age / _Beam.dur).clamp(0.0, 1.0);
  final alpha = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
  final width = b.height * 0.16 * (0.5 + Curves.easeOut.transform(t));
  final rect = Rect.fromCenter(
      center: Offset(b.center.dx, b.center.dy - b.height * 0.18),
      width: width,
      height: b.height * 0.9);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          b.color.withValues(alpha: 0.55 * alpha),
          Colors.white.withValues(alpha: 0.75 * alpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect),
  );
}

void _drawPoint(Canvas canvas, _Pt p) {
  if (p.delay > 0) return;
  final t = (p.age / p.dur).clamp(0.0, 1.0);
  // 末段 40% 淡出
  final alpha = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
  final paint = Paint()..color = p.color.withValues(alpha: alpha);
  canvas.save();
  canvas.translate(p.pos.dx, p.pos.dy);
  canvas.rotate(p.rot);
  switch (p.kind) {
    case PetFxKind.hearts:
      canvas.drawPath(_heart(p.size), paint);
    case PetFxKind.stars:
      canvas.drawPath(_star(p.size), paint);
    case PetFxKind.crumbs:
      final s = p.size * (1 - t * 0.4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s, height: s),
            Radius.circular(s * 0.32)),
        paint,
      );
    case PetFxKind.zzz:
      _drawZzz(canvas, p, alpha);
    case PetFxKind.ring:
    case PetFxKind.beam:
      break;
  }
  canvas.restore();
}

/// Z 字走 TextPainter，颜色固定在 TextStyle 上，故套一层 saveLayer 做淡出
void _drawZzz(Canvas canvas, _Pt p, double alpha) {
  final tp = p.painter;
  canvas.scale(p.size / p.fontSize);
  canvas.saveLayer(
    Rect.fromCenter(
        center: Offset.zero, width: tp.width * 2, height: tp.height * 2),
    Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
  );
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  canvas.restore();
}

Path _heart(double s) {
  return Path()
    ..moveTo(0, s * 0.38)
    ..cubicTo(-s * 0.06, s * 0.22, -s * 0.55, s * 0.06, -s * 0.55, -s * 0.16)
    ..cubicTo(-s * 0.55, -s * 0.46, -s * 0.16, -s * 0.50, 0, -s * 0.22)
    ..cubicTo(s * 0.16, -s * 0.50, s * 0.55, -s * 0.46, s * 0.55, -s * 0.16)
    ..cubicTo(s * 0.55, s * 0.06, s * 0.06, s * 0.22, 0, s * 0.38)
    ..close();
}

Path _star(double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + i * math.pi / 5;
    if (i == 0) {
      p.moveTo(rad * math.cos(a), rad * math.sin(a));
    } else {
      p.lineTo(rad * math.cos(a), rad * math.sin(a));
    }
  }
  return p..close();
}

/// 粒子实体（pos/vel/age/rot 逐帧推进，故非 final）
class _Pt {
  _Pt({
    required this.kind,
    required this.color,
    required this.fontSize,
    required this.pos,
    required this.vel,
    required this.gravity,
    required this.spin,
    required this.size,
    required this.dur,
    required this.delay,
  });

  final PetFxKind kind;
  final Color color;

  /// Z 字走文字绘制，保留未随机的原始字号用于缩放比
  final double fontSize;

  Offset pos;
  Offset vel;
  final double gravity;
  final double spin;
  final double size;
  final double dur;
  double delay;
  double age = 0;
  double rot = 0;

  /// 只有 Z 字粒子会访问到，其余种类不构建 TextPainter（late 惰性初始化）
  late final TextPainter painter = TextPainter(
    text: TextSpan(
        text: 'z',
        style: TextStyle(
            color: color, fontSize: fontSize, fontWeight: FontWeight.w900)),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// 舞台特效浮层：铺满所在区域、`IgnorePointer` 不吃任何手势
///
/// 放进与宠物同一坐标系（舞台 Padding 内）而不是整屏 Stack，粒子的
/// [Alignment] 锚点才能直接对应宠物身体位置。
class PetFxLayer extends StatelessWidget {
  const PetFxLayer({super.key, required this.fx});

  final PetFxController fx;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: PetFxPainter(fx), size: Size.infinite),
    );
  }
}

class _Ring {
  _Ring({required this.center, required this.radius, required this.color});

  static const double dur = 0.7;
  final Offset center;
  final double radius;
  final Color color;
  double age = 0;
}

class _Beam {
  _Beam({required this.center, required this.color, required this.height});

  static const double dur = 1.6;
  final Offset center;
  final Color color;
  final double height;
  double age = 0;
}
