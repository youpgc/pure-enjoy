part of 'journey_flame_game.dart';

/// 并行攻击单位：图鉴已解锁的常规法宝按 attack_kind 作为独立攻击单位
/// 挂载，与角色环绕底盘并行。单位不占维度槽、不经三选一，数值取分级表
/// [min(角色等级,8)] 级，缺行回落 journey_weapons 的 base 列。
///
/// 行为分派：projectile=穿透弹 / boomerang=回旋 / aura=领域 /
/// beam=扇形光束 / magnet=磁吸+近身伤害。命中统一走 _hitMonster，
/// 与环绕共用暴击/穿刺/特效/吸血口径，伤害基数按单位自身分级独立计算。

/// 并行单位命中冷却槽位总数：5 种已实现形态各占一槽，
/// 末槽留给未实现形态（如 melee_arc），避免其默认落点与其他形态串扰。
const int kAttackUnitSlotCount = 6;

/// 并行单位形态 → 命中冷却槽位：不同形态各用独立 0.3s 冷却，互不吞命中。
/// 弹体（projectile/boomerang）自带 hitSet 去重，仍占槽防同帧多弹叠伤。
int _attackUnitSlot(String kind) {
  switch (kind) {
    case 'boomerang':
      return 1;
    case 'aura':
      return 2;
    case 'beam':
      return 3;
    case 'magnet':
      return 4;
    case 'projectile':
      return 0;
    default:
      return 5;
  }
}

/// 单个并行单位的当前分级数值快照（升级时由 _refreshAttackUnits 重建）。
class JourneyAttackUnit {
  JourneyAttackUnit({
    required this.code,
    required this.kind,
    this.damage = 0,
    this.intervalMs = 0,
    this.projCount = 1,
    this.healAmount = 0,
    this.valueNum = 0,
    this.pierce = 0,
    this.speed = 0,
    this.aoeRadius = 0,
    this.rangePx = 0,
    this.starterEffect = '',
  });

  final String code;
  final String kind;
  final double damage;
  final double intervalMs;
  final int projCount;
  final double healAmount;
  final double valueNum;
  final int pierce;
  final double speed;
  final double aoeRadius;
  final double rangePx;

  /// 法宝初始特效槽（knockback/burn/lifesteal/pierce）：并行命中沿用该
  /// 特效，保证非出战法宝的初始特性不因脱离环绕维度槽而丢失。
  final String starterEffect;

  /// 发射/扫击计时器，归零触发并重置；无目标时回退到阈值前 1s 重试。
  double timer = 0;
}

/// 飞行弹体：projectile 穿透 / boomerang 去回程；world 坐标驱动。
class JourneyAttackShot {
  JourneyAttackShot({
    required this.unit,
    required this.pos,
    required this.dir,
    required this.speed,
    required this.range,
    required this.pierce,
    required this.boomerang,
  });

  /// 所属单位：升级刷新后按 code 重绑到新数值快照，保证飞行中弹体用新伤害。
  JourneyAttackUnit unit;
  Vector2 pos;
  final Vector2 dir;
  final double speed;
  final double range;
  final int pierce;
  final bool boomerang;

  double traveled = 0;
  bool returning = false;
  int hits = 0;
  final Set<JourneyMonsterComponent> hitSet = <JourneyMonsterComponent>{};
}

/// 并行攻击单位调度组件：每帧推进所有单位的攻击行为并渲染弹体/领域/光束。
class JourneyAttackUnits extends Component {
  JourneyAttackUnits({required this.game});

  final JourneyFlameGame game;

  final List<JourneyAttackUnit> units = <JourneyAttackUnit>[];
  final List<JourneyAttackShot> shots = <JourneyAttackShot>[];

  /// 领域脉冲计时（渲染用，不参与命中）。
  double _auraPulse = 0;

  /// 光束闪光视觉委托：分槽状态、逐帧衰减与扇形绘制由独立视觉组件承载。
  final JourneyAttackBeamFx beamFx = JourneyAttackBeamFx();

  /// 已计入 player.pickupRange 的磁吸范围：升级刷新时按差值调整，避免叠加残留。
  double _magnetApplied = 0;

  double get magnetRadius {
    var r = 0.0;
    for (final u in units) {
      if (u.kind == 'magnet' && u.aoeRadius > 0) r += u.aoeRadius;
    }
    return r;
  }

  void _syncMagnetRange() {
    final next = magnetRadius;
    game.player.pickupRange += next - _magnetApplied;
    _magnetApplied = next;
  }

  /// 按已解锁集重建单位列表；解锁进度来自服务端进度快照，与本地一致。
  void rebuild() {
    units
      ..clear()
      ..addAll(game._buildAttackUnits());
    shots.clear();
    beamFx.clear();
    _magnetApplied = 0;
    _syncMagnetRange();
  }

  /// 升级后按新等级刷新单位数值（保留计时器，避免升级瞬间重置周期）。
  void refresh() {
    // 计时器按 code 归档：解锁集顺序或构成变动时也不会错配到别的单位。
    final timers = <String, double>{for (final u in units) u.code: u.timer};
    final fresh = game._buildAttackUnits();
    units
      ..clear()
      ..addAll(fresh);
    for (final u in units) {
      final t = timers[u.code];
      if (t != null) u.timer = t;
    }
    // 飞行中弹体按 code 重绑到新单位，消除升级后仍用旧伤害的窗口。
    final byCode = <String, JourneyAttackUnit>{
      for (final u in units) u.code: u,
    };
    for (final s in shots) {
      final next = byCode[s.unit.code];
      if (next != null) s.unit = next;
    }
    _syncMagnetRange();
  }

  @override
  void update(double dt) {
    if (dt <= 0 || game._ended || game._pendingLevelUps > 0) return;
    _auraPulse += dt;
    beamFx.update(dt);

    for (final unit in units) {
      switch (unit.kind) {
        case 'projectile':
          _tickProjectile(unit, dt);
          break;
        case 'boomerang':
          _tickBoomerang(unit, dt);
          break;
        case 'aura':
          _tickAura(unit);
          break;
        case 'beam':
          _tickBeam(unit, dt);
          break;
        case 'magnet':
          _tickMagnet(unit, dt);
          break;
      }
    }
    _updateShots(dt);
  }

  /// 命中口径：单位自身伤害 + 等级/攻击卡 + 角色基础攻击，再乘通用增伤；
  /// 与环绕 hitDamageBase 同源，只是把环绕 damage 替换为该单位分级伤害。
  double damageOf(JourneyAttackUnit unit) =>
      (unit.damage + game.attackBonus + game.character.baseAttack) *
      (1 + game.damageAmpTotal);

  /// 传入 multiplier 后的未增伤基础值：火眼金睛条件增伤按「基础值×
  /// (1+通用增伤+条件增伤)」单次乘算，故基数须随形态倍率同步缩放，
  /// 否则 aura/magnet 放大伤害后条件增伤占比被稀释。
  double _conditionBase(JourneyAttackUnit unit, double multiplier) =>
      (unit.damage + game.attackBonus + game.character.baseAttack) * multiplier;

  /// 返回是否真正命中（被冷却/死亡拦截时返回 false），供弹体决定是否消耗穿透。
  ///
  /// 命中口径与环绕同源：破甲走 game.armorIgnoreRatio；击退/吸血取该法宝
  /// 初始特效与全局维度槽的较高等级；灼烧由初始特效驱动命中点燃（独立
  /// source，不覆盖环绕驻留来源）；火眼金睛条件增伤基数随形态倍率同步缩放。
  /// 全局装备效果（暴击雷引/幌金绳/混天绫/紫金铃等）随命中触发为既有增益，
  /// 同怪命中受形态冷却约束不会每帧叠加；角色专属爆发的伏魔重击不随并行
  /// 命中消耗。
  bool _hit(
    JourneyAttackUnit unit,
    JourneyMonsterComponent m, {
    double multiplier = 1,
  }) {
    final cdSlot = _attackUnitSlot(unit.kind);
    if (m.isDead || m.attackUnitCds[cdSlot] > 0) return false;
    m.attackUnitCds[cdSlot] = game.battleNum('weapon', 'hit_cd', 0.3);
    // 初始特效只在该法宝确有此特效时给 1 级；全局槽升级可叠加其上。
    final knockLv = math.max(
      game.slotLevel('knockback'),
      unit.starterEffect == 'knockback' ? 1 : 0,
    );
    final lifestealLv = math.max(
      game.slotLevel('lifesteal'),
      unit.starterEffect == 'lifesteal' ? 1 : 0,
    );
    game._hitMonster(
      game,
      m,
      damageOf(unit) * multiplier,
      pierceIgnore: game.armorIgnoreRatio,
      knockLv: knockLv,
      lifestealLv: lifestealLv,
      toM: m.position - game.player.position,
      allowSignature: false,
      conditionBase: _conditionBase(unit, multiplier),
    );
    // 初始特效灼烧：独立来源 key 不覆盖环绕驻留灼烧。伤害按攻击力比例
    // 结算，与炉火/二气瓶同属百分比型，走经甲分账；只有固定值型灼烧才
    // 绕甲，故 trueDamage 保持默认 false。
    if (unit.starterEffect == 'burn' && !m.isDead) {
      m.ignite(
        source: 'attack_${unit.code}',
        burnDps: math.max(1.0, damageOf(unit)) *
            game.battleNum('weapon', 'attack_burn_ratio', 0.25),
        seconds: game.battleNum('weapon', 'attack_burn_sec', 2.0),
      );
    }
    // magnet 命中固定回血：分级 heal_amount 列，缺行回落 base heal_fixed，
    // 经 addLifestealHeal 走秒窗上限与禁疗拦截。
    if (unit.kind == 'magnet' && unit.healAmount > 0) {
      game.addLifestealHeal(unit.healAmount);
    }
    return true;
  }

  /// 最近怪索敌：命中范围钳在分级 range/base/range_px 或臂长内，
  /// 复用空间哈希近邻，不遍历全量怪物。
  JourneyMonsterComponent? _nearest(double range) {
    final candidates = game.spatialGrid.queryRange(game.player.position, range);
    JourneyMonsterComponent? best;
    var bestD = double.maxFinite;
    for (final m in candidates) {
      if (m.isDead) continue;
      final d = (m.position - game.player.position).length;
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  void _tickProjectile(JourneyAttackUnit unit, double dt) {
    if (unit.timer > 0) {
      unit.timer -= dt;
      return;
    }
    final period = (unit.intervalMs > 0 ? unit.intervalMs : 320) / 1000;
    final range = unit.rangePx > 0
        ? unit.rangePx
        : (game.weaponArm?.outerRadius ?? 320) + 160;
    final target = _nearest(range);
    if (target == null) {
      unit.timer = math.max(0.2, period - 1);
      return;
    }
    unit.timer = period;
    final delta = target.position - game.player.position;
    // 目标恰与玩家重叠时零向量没有方向，兜底朝右，避免弹体原地打转。
    final base = delta.length > 0.001 ? delta.normalized() : Vector2(1, 0);
    // 三头六臂（nezha 特殊能力）：增益期多法宝并射，弹数 +1。
    final extra = game._nezhaWindow > 0 ? 1 : 0;
    final count = (unit.projCount + extra).clamp(1, 9);
    const spread = 0.12;
    for (var i = 0; i < count; i++) {
      final offset = (i - (count - 1) / 2) * spread;
      final a = math.atan2(base.y, base.x) + offset;
      shots.add(JourneyAttackShot(
        unit: unit,
        pos: game.player.position.clone(),
        dir: Vector2(math.cos(a), math.sin(a)),
        speed: unit.speed > 0 ? unit.speed : 420,
        range: range,
        pierce: unit.pierce,
        boomerang: false,
      ));
    }
  }

  void _tickBoomerang(JourneyAttackUnit unit, double dt) {
    if (unit.timer > 0) {
      unit.timer -= dt;
      return;
    }
    final period = (unit.intervalMs > 0 ? unit.intervalMs : 900) / 1000;
    final target = _nearest(unit.rangePx > 0 ? unit.rangePx : 320);
    if (target == null) {
      unit.timer = math.max(0.2, period - 1);
      return;
    }
    unit.timer = period;
    final delta = target.position - game.player.position;
    final dir = delta.length > 0.001 ? delta.normalized() : Vector2(1, 0);
    shots.add(JourneyAttackShot(
      unit: unit,
      pos: game.player.position.clone(),
      dir: dir,
      speed: unit.speed > 0 ? unit.speed : 360,
      range: unit.rangePx > 0 ? unit.rangePx : 300,
      // 回旋弹穿透数取分级/基础配置，保证后台可调；缺省兜底全穿透。
      pierce: unit.pierce > 0 ? unit.pierce : 99,
      boomerang: true,
    ));
  }

  void _updateShots(dt) {
    for (var i = shots.length - 1; i >= 0; i--) {
      final s = shots[i];
      final step = s.speed * dt;
      if (s.returning) {
        final toPlayer = game.player.position - s.pos;
        if (toPlayer.length <= step + 8) {
          shots.removeAt(i);
          continue;
        }
        s.pos.add(toPlayer.normalized() * step);
      } else {
        s.pos.add(s.dir * step);
        s.traveled += step;
        if (s.traveled >= s.range) {
          if (s.boomerang) {
            s.returning = true;
            // 回程视为第二次独立扫掠：清空去重集合，让去程命中过的怪在
            // 回程可再命中一次；同怪仍受形态命中冷却保护，不会同点双伤。
            s.hitSet.clear();
          } else {
            shots.removeAt(i);
            continue;
          }
        }
      }
      final candidates =
          game.spatialGrid.queryRange(s.pos, 64);
      for (final m in candidates) {
        if (m.isDead || s.hitSet.contains(m)) continue;
        if ((m.position - s.pos).length > m.radius + 12) continue;
        // 仅真正命中（未被冷却/死亡拦截）才登记去重与消耗穿透，
        // 避免弹体被同帧其他单位的命中冷却「吃掉」却白耗穿透次数。
        if (!_hit(s.unit, m)) {
          continue;
        }
        s.hitSet.add(m);
        // pierce=穿透数（主目标之外可再命中数），故第 pierce+1 次命中后销毁；
        // 回旋弹不按穿透销毁，靠射程到头返程 + hitSet 去重。
        if (!s.boomerang && s.hits >= s.pierce && s.pierce > 0) {
          shots.removeAt(i);
          break;
        }
        s.hits++;
      }
    }
  }
}
