import 'dart:math';

import 'package:flutter/material.dart';

/// 消消乐特效层（纯自绘，无外部图片/音频资源）。
///
/// 对齐主流三消（Candy Crush 系）观感，补齐此前只有「缩放淡出」的单调表现：
/// - [burst] 消除迸发：糖块破碎时四散碎片粒子，带轻微重力与缩小淡出；
/// - [beam]  条纹糖光束：沿整行/整列横扫的光带；
/// - [shock] 冲击波：圆环向外扩散（包装糖爆炸 / 特殊糖生成闪光）；
/// - [float] 连锁飘字：连击提示上浮放大后淡出。
///
/// 生命周期由宿主在 update/render 中驱动；无活跃特效时 render 直接短路。
/// 各类特效均设存活上限，连锁极深时自动限流，避免帧率塌陷。
class Match3Effects {
  Match3Effects({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  final List<_Burst> _bursts = <_Burst>[];
  final List<_Beam> _beams = <_Beam>[];
  final List<_Shock> _shocks = <_Shock>[];
  final List<_Float> _floats = <_Float>[];

  /// 各类特效存活上限，防止长时间连锁时无界增长
  static const int _maxBursts = 48;
  static const int _maxBeams = 8;
  static const int _maxShocks = 12;
  static const int _maxFloats = 6;

  bool get isEmpty =>
      _bursts.isEmpty &&
      _beams.isEmpty &&
      _shocks.isEmpty &&
      _floats.isEmpty;

  /// 消除迸发：以 [center] 为中心迸发碎片粒子。
  ///
  /// [power] 同时放大初速与数量（特殊糖爆炸传 1.6~2.0，普通糖 1.0）。
  void burst({
    required Offset center,
    required Color color,
    required double cell,
    int count = 7,
    double power = 1.0,
  }) {
    if (_bursts.length >= _maxBursts) return;
    final n = (count * power).round().clamp(4, 16);
    final parts = <_Particle>[];
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = (0.55 + _rng.nextDouble() * 0.75) * cell * 3.2 * power;
      parts.add(_Particle(
        pos: center,
        vel: Offset(cos(a) * sp, sin(a) * sp - cell * 1.1 * power),
        color: color,
        size: cell * (0.11 + _rng.nextDouble() * 0.10) * power,
      ));
    }
    _bursts.add(_Burst(parts));
  }

  /// 条纹糖光束。
  ///
  /// [horizontal] 为 true 时沿 x 轴横扫（行），否则沿 y 轴竖扫（列）。
  /// [centerAlong] 是扫描方向的中心坐标，[centerCross] 是垂直方向的中心坐标，
  /// [length] 为扫描总长度（像素）。
  void beam({
    required bool horizontal,
    required double centerAlong,
    required double centerCross,
    required double length,
    required double thickness,
    required Color color,
  }) {
    if (_beams.length >= _maxBeams) return;
    _beams.add(_Beam(
      horizontal: horizontal,
      centerAlong: centerAlong,
      centerCross: centerCross,
      length: length,
      thickness: thickness,
      color: color,
    ));
  }

  /// 冲击波圆环：由 [center] 向外扩散到 [radius]。
  void shock({
    required Offset center,
    required double radius,
    required Color color,
    double strokeRatio = 0.12,
  }) {
    if (_shocks.length >= _maxShocks) return;
    _shocks.add(_Shock(
      center: center,
      radius: radius,
      color: color,
      stroke: radius * strokeRatio,
    ));
  }

  /// 连锁飘字：如「连击 ×3」，上浮并放大后淡出。
  void float({
    required Offset center,
    required String text,
    required Color color,
    required double fontSize,
  }) {
    if (_floats.length >= _maxFloats) return;
    _floats.add(_Float(
      center: center,
      text: text,
      color: color,
      fontSize: fontSize,
    ));
  }

  /// 推进所有特效（[dt] 单位秒）。宿主需在 update 中调用。
  void update(double dt) {
    for (final b in _bursts) {
      b.t += dt;
      for (final p in b.parts) {
        // 重力：碎片抛物线下坠，比直线飞散更自然
        p.vel = Offset(p.vel.dx, p.vel.dy + 1250 * dt);
        p.pos = p.pos + p.vel * dt;
      }
    }
    _bursts.removeWhere((b) => b.t >= _Burst.dur);

    for (final e in _beams) {
      e.t += dt;
    }
    _beams.removeWhere((e) => e.t >= _Beam.dur);

    for (final s in _shocks) {
      s.t += dt;
    }
    _shocks.removeWhere((s) => s.t >= _Shock.dur);

    for (final f in _floats) {
      f.t += dt;
    }
    _floats.removeWhere((f) => f.t >= _Float.dur);
  }

  /// 绘制所有特效（叠在糖块之上）。宿主需在 render 末尾调用。
  void render(Canvas canvas) {
    if (isEmpty) return;

    // 冲击波：半径 easeOut 扩散 + 线宽递减 + 淡出
    for (final s in _shocks) {
      final p = (s.t / _Shock.dur).clamp(0.0, 1.0);
      final e = 1 - pow(1 - p, 3).toDouble();
      canvas.drawCircle(
        s.center,
        s.radius * e,
        Paint()
          ..color = s.color.withValues(alpha: (1 - p).clamp(0.0, 1.0) * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.stroke * (1 - p * 0.7).clamp(0.05, 1.0),
      );
    }

    // 光束：由中心向两端展开 + 收细 + 淡出
    for (final e in _beams) {
      final p = (e.t / _Beam.dur).clamp(0.0, 1.0);
      final grow = 1 - pow(1 - p, 3).toDouble();
      final half = (e.length * grow) / 2;
      final thick = e.thickness * (1 - p * 0.55).clamp(0.08, 1.0);
      final r = e.horizontal
          ? Rect.fromLTWH(e.centerAlong - half, e.centerCross - thick / 2,
              half * 2, thick)
          : Rect.fromLTWH(e.centerCross - thick / 2, e.centerAlong - half,
              thick, half * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(thick / 2)),
        Paint()
          ..color = e.color.withValues(alpha: (1 - p).clamp(0.0, 1.0) * 0.9),
      );
    }

    // 碎片：抛物线飞散 + 缩小淡出
    for (final b in _bursts) {
      final p = (b.t / _Burst.dur).clamp(0.0, 1.0);
      final alpha = (1 - p).clamp(0.0, 1.0);
      final shrink = 1 - p * 0.45;
      for (final q in b.parts) {
        final s = q.size * shrink;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: q.pos, width: s, height: s),
            Radius.circular(s * 0.32),
          ),
          Paint()..color = q.color.withValues(alpha: alpha),
        );
      }
    }

    // 飘字：上浮 + 先放大后微缩 + 末段淡出
    for (final f in _floats) {
      final p = (f.t / _Float.dur).clamp(0.0, 1.0);
      final alpha = p < 0.65 ? 1.0 : (1 - (p - 0.65) / 0.35).clamp(0.0, 1.0);
      final rise = f.fontSize * 1.9 * (1 - pow(1 - p, 2).toDouble());
      final scale = p < 0.25 ? 0.6 + (p / 0.25) * 0.5 : 1.1 - (p - 0.25) * 0.12;
      final w = f.painter.width;
      final h = f.painter.height;
      canvas.save();
      canvas.translate(f.center.dx, f.center.dy - rise);
      canvas.scale(scale);
      // TextPainter 的文字颜色固定在 TextStyle 上，无法逐帧改 alpha；
      // 用 saveLayer 给整层套 alpha 实现淡出（区域仅限文字包围盒）。
      canvas.saveLayer(
        Rect.fromLTWH(-w * 0.6, -h * 0.6, w * 1.2, h * 1.2),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      f.painter.paint(canvas, Offset(-w / 2, -h / 2));
      canvas.restore(); // 图层
      canvas.restore(); // 变换
    }
  }

  /// 清空全部特效（重开一局时调用）。
  void clear() {
    _bursts.clear();
    _beams.clear();
    _shocks.clear();
    _floats.clear();
  }
}

class _Particle {
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  _Particle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
  });
}

class _Burst {
  static const double dur = 0.42;
  final List<_Particle> parts;
  double t = 0;
  _Burst(this.parts);
}

class _Beam {
  static const double dur = 0.34;
  final bool horizontal;

  /// 扫描方向的中心坐标
  final double centerAlong;

  /// 垂直于扫描方向的中心坐标
  final double centerCross;
  final double length;
  final double thickness;
  final Color color;
  double t = 0;

  _Beam({
    required this.horizontal,
    required this.centerAlong,
    required this.centerCross,
    required this.length,
    required this.thickness,
    required this.color,
  });
}

class _Shock {
  static const double dur = 0.36;
  final Offset center;
  final double radius;
  final Color color;
  final double stroke;
  double t = 0;

  _Shock({
    required this.center,
    required this.radius,
    required this.color,
    required this.stroke,
  });
}

class _Float {
  static const double dur = 0.85;
  final Offset center;
  final Color color;
  final double fontSize;
  final TextPainter painter;
  double t = 0;

  _Float({
    required this.center,
    required String text,
    required this.color,
    required this.fontSize,
  }) : painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              shadows: <Shadow>[
                Shadow(color: color, blurRadius: fontSize * 0.45),
                const Shadow(
                  color: Color(0x99000000),
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
}
