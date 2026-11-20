part of 'journey_flame_game.dart';

/// 能力/被动激活态的统一光效取色：渲染层只调这两个入口，避免状态判断散落。
/// 同时返回呼吸强度系数（以对局累计时间驱动，暂停时随引擎冻结）。
///
/// 武器环带/扇叶光效：正在激发的动态态优先于伏魔就绪的常亮提示；
/// 多重状态并存时按优先级取一色：
/// 三头六臂 > 兜率炉火 > 身外身法 > 大圣威压 > 伏魔就绪。
(Color, double)? journeyWeaponAura(JourneyFlameGame game) {
  final breath = 0.72 + 0.28 * math.sin(game._elapsed * 5.2);
  if (game._nezhaWindow > 0) return (const Color(0xFFFFB27A), breath);
  if (game._laojunWindow > 0) return (const Color(0xFFF08A5C), breath);
  if (game._shenfenTimer > 0) return (const Color(0xFFF6E3B4), breath);
  if (game._wukongBuffTimer > 0) return (const Color(0xFFF6D98A), breath);
  if (game._fumoCharged) return (const Color(0xFFFFE9A8), 1.0);
  return null;
}

/// 角色本体光效：无敌金身优先于禁疗/定身负面态，负面态优先于护盾，
/// 护盾优先于铜皮铁骨减伤窗口；同帧多态只取一色，避免叠色糊成一片。
(Color, double)? journeyPlayerAura(JourneyFlameGame game) {
  final breath = 0.72 + 0.28 * math.sin(game._elapsed * 6.0);
  if (game.player.invulnTimer > 0) {
    return (const Color(0xFFF6E3B4), breath);
  }
  if (game.player.rootTimer > 0) {
    return (const Color(0xFF9AD5C8), 0.8);
  }
  if (game.player.healBlockTimer > 0) {
    return (const Color(0xFFB07CD4), 0.8);
  }
  if (game.player.shield > 0) {
    return (const Color(0xFFE8C470), breath);
  }
  if (game._bajieGuard > 0) {
    return (const Color(0xFFC9A86A), 0.7);
  }
  return null;
}

/// 怪物状态环固定槽位：索引即圆周角度槽，追加新状态不影响既有弧段位置。
/// 前 7 位为施加给怪物的减益，末位为怪物自身增益（血怒）。
const List<(String, Color)> kJourneyMonsterStateSlots = <(String, Color)>[
  ('灼烧', Color(0xFFE8703A)),
  ('定身', Color(0xFF9AD5C8)),
  ('虚弱', Color(0xFFB07CD4)),
  ('减速', Color(0xFF7FA8D8)),
  ('寻猎', Color(0xFFD4593F)),
  ('铃印', Color(0xFFD98AD9)),
  ('火种', Color(0xFFF08A5C)),
  ('血怒', Color(0xFFE04545)),
];

const int kJourneyLingSlot = 5;
const int kJourneyFenghuoSlot = 6;
const int kJourneyFrenzySlot = 7;

/// 怪物减益位掩码：灼烧/定身/虚弱/减速/寻猎/紫金铃累计命中/风火轮传代。
/// 返回整数而非列表，避免逐帧为每只怪分配对象。
int journeyMonsterDebuffMask(JourneyMonsterComponent monster) {
  var mask = 0;
  if (monster.burnRemaining > 0) mask |= 1 << 0;
  if (monster.rootTimer > 0) mask |= 1 << 1;
  if (monster.weakenTimer > 0) mask |= 1 << 2;
  if (monster.slowTimer > 0) mask |= 1 << 3;
  if (monster.lureTimer > 0) mask |= 1 << 4;
  if (monster.lingHits > 0) mask |= 1 << kJourneyLingSlot;
  if (monster.fenghuoGen >= 0) mask |= 1 << kJourneyFenghuoSlot;
  return mask;
}

/// 怪物自身增益位掩码：血怒狂暴与减益分开归类，不混进减益入口。
int journeyMonsterBuffMask(JourneyMonsterComponent monster) =>
    monster._bloodFrenzy ? 1 << kJourneyFrenzySlot : 0;

/// 光效混合器：目标态切换时不直接换色/换透明度，按帧向目标插值，
/// [weight] 为整体显隐权重（0=完全隐去，1=完全显现）。新增态从透明
/// 淡入，消失态淡出，消除换色与出现/消失的突变。
class JourneyAuraBlend {
  Color _color = const Color(0xFFE8C470);
  double _strength = 0;

  double weight = 0;

  /// 第三层外环的连续权重：无敌金身切换时逐帧淡入淡出，
  /// 不再按 invuln 布尔值整圈跳变。
  double layer = 0;

  Color get color => _color;
  double get strength => _strength;

  void advance((Color, double)? target, double dt, {bool outerRing = false}) {
    if (dt <= 0) return;
    final k = 1 - math.exp(-dt * 12);
    layer += ((outerRing ? 1.0 : 0.0) - layer) * k;
    if (target == null) {
      weight = math.max(0, weight * (1 - k));
      return;
    }
    if (weight < 0.01) {
      // 从隐去态重新亮起：直接落位目标色，不残留上一种状态的余色
      _color = target.$1;
      _strength = target.$2;
    } else {
      _color = Color.lerp(_color, target.$1, k)!;
      _strength += (target.$2 - _strength) * k;
    }
    weight = math.min(1, weight + (1 - weight) * k);
  }
}

/// 特效层（世界坐标覆盖渲染，world 内最后加入=置顶）：
/// - 浮动文字：世界坐标上飘 + 前 0.12s 淡入、0.8s 渐隐，对象池复用（上限 40）；
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

  /// 扩散圆环（法宝触发/反伤/定身/增伤触发视觉）：0.35s 淡出。
  /// 颜色缺省为鎏金，可按反馈类型传入区分色。
  void spawnRing(
    Vector2 pos,
    double radius, {
    Color color = const Color(0xFFE8C470),
  }) {
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
      ..radius = radius
      ..color = color;
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
      final fadeOut = (t.life / _textLife).clamp(0.0, 1.0);
      final fadeIn = ((_textLife - t.life) / 0.12).clamp(0.0, 1.0);
      final alpha = fadeOut * fadeIn;
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
          ..color = r.color.withValues(alpha: k)
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
  Color color = const Color(0xFFE8C470);
}

/// 怪物身上的持续状态视觉：减益状态环、妖王冲撞预警/残影、受击血条。
/// 只读战斗状态与计时，不改写任何数值。
extension JourneyMonsterVisual on JourneyMonsterComponent {
  /// 减益弧环：固定槽位映射，一种状态一段弧，状态增减不重排既有弧段。
  /// 颜色取自统一入口，弧段随对局时间呼吸；紫金铃按累计命中进度补弧长，
  /// 风火轮按传代代数补刻点，瞬时进度也能在怪物身上读到。
  void drawStatusRings(Canvas canvas) {
    final mask = journeyMonsterDebuffMask(this) | journeyMonsterBuffMask(this);
    if (mask == 0) return;
    final r = radius + 8;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = const Color(0x33999999)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final slots = kJourneyMonsterStateSlots.length;
    final slot = math.pi * 2 / slots;
    final sweep = slot * 0.72;
    for (var i = 0; i < slots; i++) {
      if (mask & (1 << i) == 0) continue;
      final start = -math.pi / 2 + i * slot - sweep / 2;
      var arcSweep = sweep;
      if (i == kJourneyLingSlot) {
        final need = game.weaponParam('zijin_ling', 'hits', 3).round();
        if (need > 0) arcSweep *= (lingHits / need).clamp(0.0, 1.0);
      }
      final pulse = 0.5 + 0.5 * math.sin(game._elapsed * 7 + i * 1.3);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        start,
        arcSweep,
        false,
        Paint()
          ..color = kJourneyMonsterStateSlots[i].$2
              .withValues(alpha: 0.55 + 0.3 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      // 传代刻点：代数越高刻点越多，与灼烧弧段合并显示火种扩散层级。
      if (i == kJourneyFenghuoSlot) {
        final dots = math.min(fenghuoGen + 1, 4);
        for (var d = 0; d < dots; d++) {
          final a = start + arcSweep * (d + 1) / (dots + 1);
          canvas.drawCircle(
            Offset(math.cos(a) * (r - 5), math.sin(a) * (r - 5)),
            1.6,
            Paint()..color = const Color(0xFFFFF3D0),
          );
        }
      }
    }
  }

  /// 妖王冲撞视觉：蓄力红圈切入突进后淡出，突进残影淡入、收招淡出，
  /// 相位切换不再硬闪预警圈或瞬间生成残影。
  void drawChargeVisual(Canvas canvas) {
    if (!model.isBoss) return;
    if (_warningFade > 0) {
      final blink = 0.2 + 0.3 * _warningPhase;
      canvas.drawCircle(
        Offset.zero,
        radius + 18,
        Paint()
            ..color = const Color(0xFFD4593F)
                .withValues(alpha: blink * _warningFade),
      );
      canvas.drawCircle(
        Offset.zero,
        radius + 18,
        Paint()
          ..color = const Color(0xFFD4593F).withValues(
              alpha: (blink + 0.2).clamp(0.0, 1.0) * _warningFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
    if (_dashFade > 0) {
      for (var i = 1; i <= 2; i++) {
        canvas.drawCircle(
          Offset(-_chargeDir.x * 14 * i, -_chargeDir.y * 14 * i),
          radius * (1 - 0.18 * i),
          Paint()
            ..color = const Color(0xFF8E2F3C).withValues(alpha: 0.4 * _dashFade),
        );
      }
    }
  }

  /// 血条：妖王常显；普通怪受击后 0.1s 淡入，停击 0.6s 淡出。
  /// 死亡瞬间（含秒杀）整体隐藏：归零后仍绘制会闪现满宽暗底血条，
  /// 比正常受击的残血条视觉上宽很多，故以 hp>0 收口。
  void drawHpBar(Canvas canvas) {
    if (hp <= 0 || hp >= maxHp || (!model.isBoss && _hpBarTimer <= 0)) {
      return;
    }
    final alpha = model.isBoss
        ? 1.0
        : _hpBarFade * (_hpBarTimer / 0.6).clamp(0.0, 1.0);
    final w = radius * 2.2;
    // 血条置于状态环上方留出间隙（状态环半径 radius+8、描边外沿 radius+9.5），
    // 避免灼烧槽位的弧段与血条在怪物正上方叠色盖暗。
    final rect = Rect.fromCenter(
      center: Offset(0, -radius - 13),
      width: w,
      height: 4,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0x66000000));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, w * (hp / maxHp), 4),
      Paint()
        ..color = (model.isBoss
                ? const Color(0xFFE8C470)
                : const Color(0xFFD4593F))
            .withValues(alpha: alpha),
    );
  }
}

/// 角色本体光效绘制：内层两层柔环常驻，第三层随无敌金身连续权重淡入淡出；
/// 描边半径随第三层权重平滑外扩，不按 invuln 布尔值整圈跳变。
/// 描边落在立绘轮廓之外，立绘与几何两条路径都能看到。
extension JourneyPlayerVisual on JourneyPlayerComponent {
  void drawAura(Canvas canvas, Color color, double strength, double outer) {
    const center = Offset.zero;
    for (var i = 2; i >= 1; i--) {
      canvas.drawCircle(
        center,
        JourneyPlayerComponent._radius + 6.0 * i,
        Paint()..color = color.withValues(alpha: 0.10 * strength),
      );
    }
    if (outer > 0.01) {
      canvas.drawCircle(
        center,
        JourneyPlayerComponent._radius + 18.0,
        Paint()..color = color.withValues(alpha: 0.10 * strength * outer),
      );
    }
    canvas.drawCircle(
      center,
      JourneyPlayerComponent._radius + 12.0 + 6.0 * outer,
      Paint()
        ..color = color.withValues(alpha: 0.85 * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }
}
