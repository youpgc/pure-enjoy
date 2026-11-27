part of 'journey_flame_game.dart';

/// 瞬时特效调度器：按预设参数发射贴图粒子，槽位数量由参数决定并复用。
/// 池满时按游标轮询覆盖槽位，保证高频命中不会无上限创建组件。
class JourneyParticleFx {
  JourneyParticleFx(this.layer)
      : presets = JourneyFxPresets(layer.game.battleNum) {
    _slots = List<_JourneyParticleSlot>.generate(
      presets.poolSlots,
      (_) => _JourneyParticleSlot(),
    );
  }

  final JourneyFxLayer layer;
  JourneyFlameGame get game => layer.game;

  /// 本局特效参数快照（后台可配，进关读取一次）。
  final JourneyFxPresets presets;

  late final List<_JourneyParticleSlot> _slots;
  int _cursor = 0;

  /// 发射节流表：键为持续实体（怪物/弹体/领域），值为下次可发射时刻。
  final Map<Object, double> _nextEmit = <Object, double>{};
  double _lastSweep = 0;

  void update(double dt) {
    for (final slot in _slots) {
      slot.tick(dt);
    }
    final now = game._elapsed;
    if (now - _lastSweep > 2) {
      _nextEmit.removeWhere((_, next) => next < now - 1);
      _lastSweep = now;
    }
  }

  void render(Canvas canvas) {
    for (final slot in _slots) {
      slot.paint(canvas);
    }
  }

  bool _ready(Object key, double interval) {
    final now = game._elapsed;
    final next = _nextEmit[key] ?? 0;
    if (now < next) return false;
    _nextEmit[key] = now + interval;
    return true;
  }

  void clearEmitState() => _nextEmit.clear();

  void _emit(Vector2 pos, Particle particle, {Vector2? anchor}) {
    final slot = _claim();
    slot.emit(pos, particle, anchor: anchor);
  }

  _JourneyParticleSlot _claim() {
    for (var i = 0; i < _slots.length; i++) {
      final idx = (_cursor + i) % _slots.length;
      if (!_slots[idx].busy) {
        _cursor = (idx + 1) % _slots.length;
        return _slots[idx];
      }
    }
    final slot = _slots[_cursor];
    _cursor = (_cursor + 1) % _slots.length;
    return slot;
  }

  /// 环形冲击：外扩火星环 + 中心烟尘，替代单色描边圆。
  void spawnShockwave(
    Vector2 pos,
    double radius, {
    Color color = const Color(0xFFE8C470),
  }) {
    final rng = game.rng;
    final life = presets.shockLife;
    final sparks = presets.shockSparks;
    final children = <Particle>[
      _ShockTextureParticle(radius: radius, color: color, lifespan: life),
      for (var i = 0; i < sparks; i++)
        AcceleratedParticle(
          speed: Vector2(
            math.cos(i * math.pi * 2 / sparks) * radius / life,
            math.sin(i * math.pi * 2 / sparks) * radius / life,
          ),
          acceleration: Vector2(
            -math.cos(i * math.pi * 2 / sparks) * radius * 1.6,
            -math.sin(i * math.pi * 2 / sparks) * radius * 1.6,
          ),
          lifespan: life,
          child: _GlowParticle(
            radius: 2.6 + rng.nextDouble() * 2.4,
            color: color,
            core: const Color(0xFFFFF7E4),
            lifespan: life,
          ),
        ),
      AcceleratedParticle(
        speed: Vector2(0, -12),
        lifespan: life,
        child: _SmokeParticle(
          radius: math.max(7, radius * presets.shockSmokeRatio),
          alpha: presets.shockSmoke,
          lifespan: life,
        ),
      ),
    ];
    _emit(pos, ComposedParticle(children: children, lifespan: life));
  }

  /// 写实闪电：主弧与分叉已烘进贴图，只按起止点旋转拉伸。
  void spawnLightning(Vector2 from, Vector2 to) {
    _emit(
      from,
      _ArcTextureParticle(
        from,
        to,
        game.rng.nextBool() ? 1 : -1,
        thicknessRatio: presets.arcThickness,
        minThickness: presets.arcMinThickness,
        lifespan: presets.arcLife,
      ),
    );
  }

  /// 参照物破坏：带重力旋转的碎块 + 落地尘烟。
  void spawnDebris(Vector2 pos, double radius) {
    final rng = game.rng;
    final life = presets.debrisLife;
    final children = <Particle>[
      for (var i = 0; i < presets.debrisCount; i++)
        AcceleratedParticle(
          speed: Vector2(
            (rng.nextDouble() - 0.5) * 160,
            -50 - rng.nextDouble() * 120,
          ),
          acceleration: Vector2(0, 320),
          lifespan: life,
          child: _DebrisParticle(
            size: 3 + rng.nextDouble() * 3.5,
            spin: (rng.nextDouble() - 0.5) * 12,
            color: i.isEven ? const Color(0xFF8A6A4A) : const Color(0xFFB08A5C),
            lifespan: life,
          ),
        ),
      _SmokeParticle(
        radius: radius * 0.5,
        alpha: presets.debrisSmoke,
        lifespan: life,
      ),
    ];
    _emit(pos, ComposedParticle(children: children, lifespan: life));
  }

  /// 灼烧火舌：贴身短焰，贴图自带亮核与摆动。
  /// 只做状态氛围，灼烧的可读性靠怪物身上的橙色状态弧段。
  void spawnFlame(Vector2 pos, double radius, {Vector2? anchor}) {
    final rng = game.rng;
    final life = presets.flameLife;
    final rise = presets.flameRise;
    final children = <Particle>[
      for (var i = 0; i < presets.flameCount; i++)
        AcceleratedParticle(
          position: Vector2(
            (rng.nextDouble() - 0.5) * radius * 0.5,
            -radius * 0.1,
          ),
          speed: Vector2(
            (rng.nextDouble() - 0.5) * presets.flameSpread,
            -rise,
          ),
          acceleration: Vector2((rng.nextDouble() - 0.5) * 6, 0),
          lifespan: life,
          child: _FlameTextureParticle(
            height:
                radius * presets.flameHeight * (0.85 + rng.nextDouble() * 0.3),
            width: radius * presets.flameWidth * (0.9 + rng.nextDouble() * 0.2),
            phase: rng.nextDouble() * math.pi * 2,
            tilt: (rng.nextDouble() - 0.5) * 0.35,
            lifespan: life,
          ),
        ),
      for (var i = 0; i < presets.flameCoreCount; i++)
        _GlowParticle(
          radius: radius * (0.3 + rng.nextDouble() * 0.18),
          color: const Color(0xFFEF9F27),
          core: const Color(0xFFFFF3D0),
          stretch: 1.25,
          lifespan: life,
        ),
      for (var i = 0; i < presets.flameEmbers; i++)
        AcceleratedParticle(
          speed: Vector2(
            (rng.nextDouble() - 0.5) * 40,
            -22 - rng.nextDouble() * 34,
          ),
          acceleration: Vector2(0, 24),
          lifespan: life,
          child: _GlowParticle(
            radius: 1.4 + rng.nextDouble() * 1.4,
            color: const Color(0xFFBA7517),
            core: const Color(0xFFFFF3D0),
            lifespan: life,
          ),
        ),
      AcceleratedParticle(
        speed: Vector2(0, -presets.flameSmokeRise),
        lifespan: life,
        child: _SmokeParticle(
          radius: radius * 0.44,
          alpha: presets.flameSmoke,
          lifespan: life,
        ),
      ),
    ];
    _emit(
      pos,
      ComposedParticle(children: children, lifespan: life),
      anchor: anchor,
    );
  }

  /// 灼烧怪物逐个节流发射；离屏怪不发射，避免池被屏外目标占满。
  /// 基准落在怪物脚边，锚点指向怪物本体：移动时火舌贴身跟随，不拖尾。
  void emitBurn(JourneyMonsterComponent monster) {
    if (monster.burnRemaining <= 0 || monster.isDead) return;
    if (!monster.isVisibleToCamera(0)) return;
    if (!_ready(monster, presets.flameInterval)) return;
    spawnFlame(
      monster.position + Vector2(0, monster.radius * 0.5),
      monster.radius,
      anchor: monster.position,
    );
  }

  /// 光束：锥形光流 + 顺向游离光粒，闪光时长与命中节拍同源。
  void spawnBeam(Vector2 origin, Vector2 dir, double range) {
    _emit(
      origin,
      _BeamParticle(
        dir: dir,
        range: range,
        rng: game.rng,
        moteCount: presets.beamMotes,
        lifespan: kBeamFlashSec,
      ),
    );
  }

  /// 飞行弹体尾迹：金红弹道/青金回旋各自取色，按实体节流。
  void spawnTrail(Object key, Vector2 pos, Color color, double radius) {
    if (!_ready(key, presets.trailInterval)) return;
    final rng = game.rng;
    final life = presets.trailLife;
    _emit(
      pos,
      _GlowParticle(
        radius: math.max(2, radius * 0.55) * (0.8 + rng.nextDouble() * 0.4),
        color: color,
        core: const Color(0xFFFFF4DC),
        lifespan: life,
      ),
    );
  }

  /// 妖王领域环境粒子：灼烧/毒雾场呈悬浮火星或雾粒，随领域寿命持续发射。
  void emitField(JourneyBossField field) {
    if (!_ready(field, presets.fieldInterval)) return;
    final rng = game.rng;
    final a = rng.nextDouble() * math.pi * 2;
    final d = math.sqrt(rng.nextDouble()) * field.radius;
    final pos = field.pos + Vector2(math.cos(a) * d, math.sin(a) * d);
    final fog = field.effect == 'dot' || field.effect == 'sting';
    final life = presets.fieldLife;
    final children = <Particle>[
      AcceleratedParticle(
        speed:
            Vector2((rng.nextDouble() - 0.5) * 18, -14 - rng.nextDouble() * 20),
        lifespan: life,
        child: fog
            ? _SmokeParticle(
                radius: 8 + rng.nextDouble() * 8,
                alpha: presets.fieldSmoke,
                lifespan: life)
            : _GlowParticle(
                radius: 2 + rng.nextDouble() * 3,
                color: field.color,
                core: const Color(0xFFFFF3D0),
                lifespan: life,
              ),
      ),
    ];
    _emit(
      pos,
      ComposedParticle(children: children, lifespan: life),
      anchor: field.pos,
    );
  }

  /// 预警圈边缘火星：随圈体收缩同步内收，保留预警可读性。
  void emitTelegraph(JourneyBossTelegraph telegraph) {
    if (!_ready(telegraph, presets.telegraphInterval)) return;
    final k = (telegraph.delay / math.max(0.01, telegraph.totalDelay))
        .clamp(0.0, 1.0);
    final radius = telegraph.radius * (0.35 + 0.65 * k);
    final a = game.rng.nextDouble() * math.pi * 2;
    final pos =
        telegraph.pos + Vector2(math.cos(a) * radius, math.sin(a) * radius);
    _emit(
      pos,
      _GlowParticle(
        radius: 2.4 + game.rng.nextDouble() * 2,
        color: telegraph.color,
        core: const Color(0xFFFFF3D0),
        lifespan: presets.telegraphLife,
      ),
      anchor: telegraph.pos,
    );
  }
}

/// 粒子发射器槽位：由粒子层手动推进与绘制，不进 Flame 组件树，
/// 避免每发一次特效就 add/remove 一个组件。
///
/// 锚点用于持续态特效（灼烧/领域/预警）：发射时记下锚点坐标，之后每帧
/// 把锚点位移平移到槽位基准，粒子自身的摆动仍在局部坐标，怪物移动时
/// 火焰贴身跟随，不再拖成一串。瞬时特效不传锚点，落在发射点不动。
class _JourneyParticleSlot extends PositionComponent {
  Particle? particle;
  Vector2? _anchor;
  final Vector2 _anchorLast = Vector2.zero();

  bool get busy => particle != null;

  void emit(Vector2 pos, Particle next, {Vector2? anchor}) {
    position.setFrom(pos);
    _anchor = anchor;
    if (anchor != null) _anchorLast.setFrom(anchor);
    particle = next;
  }

  void tick(double dt) {
    final p = particle;
    if (p == null) return;
    final anchor = _anchor;
    if (anchor != null) {
      position.x += anchor.x - _anchorLast.x;
      position.y += anchor.y - _anchorLast.y;
      _anchorLast.setFrom(anchor);
    }
    p.update(dt);
    if (p.shouldRemove) {
      particle = null;
      _anchor = null;
    }
  }

  void paint(Canvas canvas) {
    final p = particle;
    if (p == null) return;
    canvas.save();
    canvas.translate(position.x, position.y);
    p.render(canvas);
    canvas.restore();
  }
}
