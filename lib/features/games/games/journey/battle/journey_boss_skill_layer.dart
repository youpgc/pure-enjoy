part of 'journey_flame_game.dart';

/// 妖王技能弹道：直线/追踪两类，命中玩家后把效果键与强度交给宿主统一结算。
/// [homing] 时每帧修正方向指向玩家；[pierce] 为穿透次数，命中后递减。
class JourneyBossProjectile {
  JourneyBossProjectile({
    required this.pos,
    required this.vel,
    required this.radius,
    required this.life,
    required this.damage,
    required this.effect,
    required this.power,
    required this.color,
    this.homing = false,
    this.pierce = 0,
    this.owner,
    this.abilityKey,
  });

  Vector2 pos;
  final Vector2 vel;
  final double radius;
  double life;
  final double damage;
  final String effect;
  final double power;
  final Color color;
  final bool homing;
  int pierce;
  final JourneyMonsterComponent? owner;
  /// 施法时的能力键：弹道延迟命中时仍能读到该能力的专属参数。
  final String? abilityKey;

  /// 命中去重：穿透弹可穿多个目标，但同一目标只结算一次，
  /// 避免停留在玩家碰撞圈内逐帧重复扣血。
  final Set<Object> hitTargets = <Object>{};
}

/// 预警落地技：先在地面画预警圈，[delay] 到点后判定圈内玩家并结算一次。
class JourneyBossTelegraph {
  JourneyBossTelegraph({
    required this.pos,
    required this.radius,
    required this.delay,
    required this.totalDelay,
    required this.damage,
    required this.effect,
    required this.power,
    required this.color,
    this.owner,
    this.abilityKey,
  });

  final Vector2 pos;
  final double radius;
  double delay;
  final double totalDelay;
  final double damage;
  final String effect;
  final double power;
  final Color color;
  final JourneyMonsterComponent? owner;
  /// 施法时的能力键：预警延迟落地时仍能读到该能力的专属参数。
  final String? abilityKey;
}

/// 持续领域：跟随施法妖王或固定落点，按 [tick] 周期对圈内玩家施加效果。
class JourneyBossField {
  JourneyBossField({
    required this.pos,
    required this.radius,
    required this.life,
    required this.tick,
    required this.effect,
    required this.power,
    required this.rawDamage,
    required this.color,
    this.owner,
    this.followOwner,
    this.abilityKey,
  });

  final Vector2 pos;
  final double radius;
  double life;
  final double tick;
  final String effect;
  final double power;
  final double rawDamage;
  final Color color;
  /// 施法者：用于死亡时清除在途技能；与位置跟随解耦。
  final JourneyMonsterComponent? owner;
  final JourneyMonsterComponent? followOwner;
  /// 施法时的能力键：领域按 tick 延迟结算时仍能读到该能力的专属参数。
  final String? abilityKey;

  double _tickLeft = 0;
}

/// 妖王技能特效层：world 内置顶（低于飘字层），统一推进弹道/预警/领域
/// 的生命周期与命中判定。展示与结算分离——结算调用宿主的效果入口，
/// 本层只负责视觉与计时，暂停时随引擎冻结。
class JourneyBossSkillLayer extends Component {
  JourneyBossSkillLayer(this.game);

  final JourneyFlameGame game;

  final List<JourneyBossProjectile> _projectiles = <JourneyBossProjectile>[];
  final List<JourneyBossTelegraph> _telegraphs = <JourneyBossTelegraph>[];
  final List<JourneyBossField> _fields = <JourneyBossField>[];

  /// 施法入口：弹道。[,dir] 为归一化初速方向，[,speed] 世界单位/秒。
  void castProjectile(
    Vector2 origin,
    Vector2 dir, {
    required double speed,
    required double radius,
    required double life,
    required double damage,
    required String effect,
    required double power,
    required Color color,
    bool homing = false,
    int pierce = 0,
    JourneyMonsterComponent? owner,
    String? abilityKey,
  }) {
    if (_projectiles.length >= 48) return;
    _projectiles.add(JourneyBossProjectile(
      pos: origin.clone(),
      vel: (dir.length > 0.001 ? dir.normalized() : Vector2(1, 0)) * speed,
      radius: radius,
      life: life,
      damage: damage,
      effect: effect,
      power: power,
      color: color,
      homing: homing,
      pierce: pierce,
      owner: owner,
      abilityKey: abilityKey ?? game._abilityParamContext?.abilityKey,
    ));
  }

  /// 施法入口：预警落地（[,delay] 秒后判定圈内玩家）。
  void castTelegraph(
    Vector2 pos, {
    required double radius,
    required double delay,
    required double damage,
    required String effect,
    required double power,
    required Color color,
    JourneyMonsterComponent? owner,
    String? abilityKey,
  }) {
    if (_telegraphs.length >= 24) return;
    _telegraphs.add(JourneyBossTelegraph(
      pos: pos.clone(),
      radius: radius,
      delay: delay,
      totalDelay: delay,
      damage: damage,
      effect: effect,
      power: power,
      color: color,
      owner: owner,
      abilityKey: abilityKey ?? game._abilityParamContext?.abilityKey,
    ));
  }

  /// 施法入口：持续领域（[,life] 秒内每 [,tick] 秒判定一次圈内玩家）。
  void castField(
    Vector2 pos, {
    required double radius,
    required double life,
    required double tick,
    required String effect,
    required double power,
    double rawDamage = 0,
    required Color color,
    JourneyMonsterComponent? owner,
    bool followOwner = false,
    String? abilityKey,
  }) {
    if (_fields.length >= 16) return;
    // tick 由后台逐怪配置，钳到下限避免 0/负值造成逐帧高频结算。
    final safeTick = tick.clamp(0.1, 60.0);
    _fields.add(JourneyBossField(
      pos: pos.clone(),
      radius: radius,
      life: life,
      tick: safeTick,
      effect: effect,
      power: power,
      rawDamage: rawDamage,
      color: color,
      owner: owner,
      followOwner: followOwner ? owner : null,
      abilityKey: abilityKey ?? game._abilityParamContext?.abilityKey,
    ));
  }

  /// 清空全部在途技能实体（结算/还魂时避免残留特效继续判定）。
  void clearAll() {
    _projectiles.clear();
    _telegraphs.clear();
    _fields.clear();
  }

  /// 施法者死亡时清掉它在途的弹道/预警/领域：
  /// 否则妖王被击杀后，死亡前放出的落雷/毒雾仍会命中玩家。
  void clearByOwner(JourneyMonsterComponent owner) {
    _projectiles.removeWhere((p) => identical(p.owner, owner));
    _telegraphs.removeWhere((t) => identical(t.owner, owner));
    _fields.removeWhere((f) =>
        identical(f.followOwner, owner) || identical(f.owner, owner));
  }

  @override
  void update(double dt) {
    if (dt <= 0) return;
    final player = game.player;
    const pr = JourneyPlayerComponent._radius;

    // 快照遍历：结算可能触发护盾反震/震荡击杀施法者，进而由 clearByOwner
    // 在遍历途中删改这三个列表。用快照迭代并按对象引用定位移除，避免索引错位。
    for (final p in _projectiles.toList()) {
      if (!_projectiles.any((e) => identical(e, p))) continue;
      if (p.homing) {
        final to = player.position - p.pos;
        if (to.length > 1) {
          final desired = to.normalized() * p.vel.length;
          final k = (dt * 2.4).clamp(0.0, 1.0);
          p.vel
            ..x += (desired.x - p.vel.x) * k
            ..y += (desired.y - p.vel.y) * k;
        }
      }
      p.pos += p.vel * dt;
      p.life -= dt;
      var consumed = p.life <= 0 ||
          p.pos.x < 0 ||
          p.pos.y < 0 ||
          p.pos.x > game.worldSize ||
          p.pos.y > game.worldSize;
      if (!consumed &&
          !p.hitTargets.contains(player) &&
          (p.pos - player.position).length <= p.radius + pr) {
        p.hitTargets.add(player);
        game.applyBossSkillEffect(
          p.effect,
          power: p.power,
          rawDamage: p.damage,
          owner: p.owner,
          abilityKey: p.abilityKey,
        );
        if (p.pierce > 0) {
          p.pierce--;
        } else {
          consumed = true;
        }
      }
      if (consumed) {
        final idx = _projectiles.indexWhere((e) => identical(e, p));
        if (idx >= 0) _projectiles.removeAt(idx);
      }
    }

    for (final t in _telegraphs.toList()) {
      if (!_telegraphs.any((e) => identical(e, t))) continue;
      t.delay -= dt;
      if (t.delay > 0) continue;
      if ((t.pos - player.position).length <= t.radius + pr) {
        game.applyBossSkillEffect(
          t.effect,
          power: t.power,
          rawDamage: t.damage,
          owner: t.owner,
          abilityKey: t.abilityKey,
        );
      }
      game.fxLayer.spawnRing(t.pos, t.radius, color: t.color);
      final idx = _telegraphs.indexWhere((e) => identical(e, t));
      if (idx >= 0) _telegraphs.removeAt(idx);
    }

    for (final f in _fields.toList()) {
      if (!_fields.any((e) => identical(e, f))) continue;
      f.life -= dt;
      if (f.followOwner != null) {
        f.pos
          ..x = f.followOwner!.position.x
          ..y = f.followOwner!.position.y;
      }
      f._tickLeft -= dt;
      if (f._tickLeft <= 0 && f.life > 0) {
        f._tickLeft += f.tick;
        if ((f.pos - player.position).length <= f.radius + pr) {
          game.applyBossSkillEffect(
            f.effect,
            power: f.power,
            rawDamage: f.rawDamage,
            owner: f.owner,
            abilityKey: f.abilityKey,
          );
        }
      }
      if (f.life <= 0) {
        final idx = _fields.indexWhere((e) => identical(e, f));
        if (idx >= 0) _fields.removeAt(idx);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // 领域：半透明填充 + 呼吸描边，一眼区分控制/伤害/增益场。
    for (final f in _fields) {
      final pulse = 0.35 + 0.15 * math.sin(game._elapsed * 4);
      canvas.drawCircle(
        f.pos.toOffset(),
        f.radius,
        Paint()..color = f.color.withValues(alpha: 0.10),
      );
      canvas.drawCircle(
        f.pos.toOffset(),
        f.radius,
        Paint()
          ..color = f.color.withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
    // 预警圈：剩余时间越少描边越亮、内圈收缩，提示落地时机。
    for (final t in _telegraphs) {
      final k = (t.delay / math.max(0.01, t.totalDelay)).clamp(0.0, 1.0);
      canvas.drawCircle(
        t.pos.toOffset(),
        t.radius,
        Paint()..color = t.color.withValues(alpha: 0.10 + 0.16 * (1 - k)),
      );
      canvas.drawCircle(
        t.pos.toOffset(),
        t.radius * (0.35 + 0.65 * k),
        Paint()
          ..color = t.color.withValues(alpha: 0.5 + 0.5 * (1 - k))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 2.5 * (1 - k),
      );
    }
    // 弹道：外晕 + 实心核心，颜色按能力区分。
    for (final p in _projectiles) {
      canvas.drawCircle(
        p.pos.toOffset(),
        p.radius + 4,
        Paint()..color = p.color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(p.pos.toOffset(), p.radius, Paint()..color = p.color);
    }
  }
}
