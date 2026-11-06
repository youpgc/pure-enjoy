part of 'journey_flame_game.dart';

/// 特效层（世界坐标覆盖渲染，world 内最后加入=置顶）：
/// - 浮动文字：世界坐标上飘 + 0.8s 渐隐，对象池复用（上限 40）；
/// - 闪电连线：暴击雷引链式命中视觉，0.15s 白色线段（池 8）；
/// - 破坏残屑：参照物击碎迸散的褐色小圆 0.5s（池 48）。
class JourneyFxLayer extends Component {
  JourneyFxLayer(this.game);

  final JourneyFlameGame game;

  static const int _maxTexts = 40;
  static const double _textLife = 0.8;
  static const double _lineLife = 0.15;
  static const double _dustLife = 0.5;
  static const double _ringLife = 0.35;

  final List<_FxText> _texts = <_FxText>[
    for (var i = 0; i < _maxTexts; i++) _FxText(),
  ];
  final List<_FxLine> _lines = <_FxLine>[
    for (var i = 0; i < 8; i++) _FxLine(),
  ];
  final List<_FxDust> _dusts = <_FxDust>[
    for (var i = 0; i < 48; i++) _FxDust(),
  ];
  final List<_FxRing> _rings = <_FxRing>[
    for (var i = 0; i < 8; i++) _FxRing(),
  ];

  /// 扩散圆环（紫金铃爆裂/金刚琢/阴阳二气瓶触发视觉）：0.35s 淡出。
  void spawnRing(Vector2 pos, double radius) {
    _FxRing? pick;
    for (final r in _rings) {
      if (!r.alive) {
        pick = r;
        break;
      }
    }
    pick ??= _rings.first;
    pick
      ..alive = true
      ..life = _ringLife
      ..pos = pos.clone()
      ..radius = radius;
  }

  /// 浮动文字：池满时复用剩余寿命最短的一条（防刷屏口径只弹关键事件）。
  void spawnFloatText(Vector2 pos, String text, Color color) {
    _FxText? pick;
    for (final t in _texts) {
      if (!t.alive) {
        pick = t;
        break;
      }
    }
    pick ??= _texts.reduce((a, b) => a.life <= b.life ? a : b);
    pick
      ..alive = true
      ..life = _textLife
      ..pos = pos.clone()
      ..text = text
      ..color = color;
  }

  /// 闪电连线（暴击雷引）。
  void spawnLightning(Vector2 from, Vector2 to) {
    _FxLine? pick;
    for (final l in _lines) {
      if (!l.alive) {
        pick = l;
        break;
      }
    }
    pick ??= _lines.first;
    pick
      ..alive = true
      ..life = _lineLife
      ..from = from.clone()
      ..to = to.clone();
  }

  /// 破坏残屑：4~6 个褐色小圆从参照物中心迸散。
  void spawnDebris(Vector2 pos, double radius) {
    final count = 4 + game.rng.nextInt(3);
    var spawned = 0;
    for (final d in _dusts) {
      if (d.alive) continue;
      final a = game.rng.nextDouble() * math.pi * 2;
      final dir = Vector2(math.cos(a), math.sin(a));
      d
        ..alive = true
        ..life = _dustLife
        ..pos = pos + dir * radius * 0.5
        ..vel = dir * (60 + game.rng.nextDouble() * 90);
      spawned++;
      if (spawned >= count) break;
    }
  }

  @override
  void update(double dt) {
    // dt=0 的布局期空刷不推进（与主类 update 短路口径一致）
    if (dt <= 0) return;
    for (final t in _texts) {
      if (!t.alive) continue;
      t.life -= dt;
      t.pos.y -= 34 * dt; // 上飘
      if (t.life <= 0) t.alive = false;
    }
    for (final l in _lines) {
      if (!l.alive) continue;
      l.life -= dt;
      if (l.life <= 0) l.alive = false;
    }
    for (final d in _dusts) {
      if (!d.alive) continue;
      d.life -= dt;
      d.pos += d.vel * dt;
      d.vel *= 0.92; // 迸散阻尼
      if (d.life <= 0) d.alive = false;
    }
    for (final r in _rings) {
      if (!r.alive) continue;
      r.life -= dt;
      if (r.life <= 0) r.alive = false;
    }
  }

  @override
  void render(Canvas canvas) {
    for (final t in _texts) {
      if (!t.alive) continue;
      final alpha = (t.life / _textLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color.withValues(alpha: alpha),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            shadows: const <Shadow>[
              Shadow(color: Color(0x99000000), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        t.pos.toOffset() - Offset(tp.width / 2, tp.height),
      );
    }
    for (final l in _lines) {
      if (!l.alive) continue;
      canvas.drawLine(
        l.from.toOffset(),
        l.to.toOffset(),
        Paint()
          ..color = const Color(0xFFF6F2E6)
              .withValues(alpha: (l.life / _lineLife).clamp(0.0, 1.0))
          ..strokeWidth = 2.6,
      );
    }
    for (final d in _dusts) {
      if (!d.alive) continue;
      final k = d.life / _dustLife;
      canvas.drawCircle(
        d.pos.toOffset(),
        3 + 2 * k,
        Paint()..color = const Color(0xFF8A6A4A).withValues(alpha: k.clamp(0.0, 1.0)),
      );
    }
    // 扩散圆环：半径随寿命收缩 + 淡出（鎏金勾线）
    for (final r in _rings) {
      if (!r.alive) continue;
      final k = (r.life / _ringLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        r.pos.toOffset(),
        r.radius * (1.15 - 0.15 * k),
        Paint()
          ..color = const Color(0xFFE8C470).withValues(alpha: k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }
}

class _FxText {
  bool alive = false;
  double life = 0;
  Vector2 pos = Vector2.zero();
  String text = '';
  Color color = const Color(0xFFFFFFFF);
}

class _FxLine {
  bool alive = false;
  double life = 0;
  Vector2 from = Vector2.zero();
  Vector2 to = Vector2.zero();
}

class _FxDust {
  bool alive = false;
  double life = 0;
  Vector2 pos = Vector2.zero();
  Vector2 vel = Vector2.zero();
}

class _FxRing {
  bool alive = false;
  double life = 0;
  Vector2 pos = Vector2.zero();
  double radius = 60;
}
