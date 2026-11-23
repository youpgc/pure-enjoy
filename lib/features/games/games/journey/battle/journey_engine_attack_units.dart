part of 'journey_flame_game.dart';

/// 并行攻击单位：图鉴已解锁的常规法宝按 attack_kind 作为独立攻击单位
/// 挂载，与角色环绕底盘并行。单位不占维度槽、不经三选一，数值取分级表
/// [min(角色等级,8)] 级，缺行回落 journey_weapons 的 base 列。
///
/// 行为分派：projectile=穿透弹 / boomerang=回旋 / beam=扇形光束与环绕武器
/// 共用同一伤害公式乘区；aura=领域 / magnet=磁吸走独立真实伤害乘区，范围取
/// 武器臂展，驻留按秒与周期脉冲两条线各按 value_num（领域每秒伤害）结算，
/// 不限目标数，不叠加角色攻击/增伤，不受护甲，不触发环绕专属暴击与特效。

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
    required this.lifeSec,
  });

  /// 所属单位：升级刷新后按 code 重绑到新数值快照，保证飞行中弹体用新伤害。
  JourneyAttackUnit unit;
  Vector2 pos;
  final Vector2 dir;
  final double speed;
  final double range;
  final int pierce;
  final bool boomerang;

  /// 剩余存在时间（秒）：逐帧扣减，归零即销毁，防止异常射程/速度配置下
  /// 弹体滞留。初值取后台 attack_shot_life_sec，缺省 8 秒。
  double lifeSec;

  double traveled = 0;
  bool returning = false;
  int hits = 0;
  final Set<JourneyMonsterComponent> hitSet = <JourneyMonsterComponent>{};
}

/// 并行攻击单位调度组件：推进所有单位的攻击行为。
/// 逐帧步进由宿主在环绕结算之后显式调用 [step]，不挂 Flame 自动 update，
/// 保证环绕武器优先命中、并行单位只补刀已存活目标。
class JourneyAttackUnits extends Component {
  JourneyAttackUnits({required this.game});

  final JourneyFlameGame game;

  final List<JourneyAttackUnit> units = <JourneyAttackUnit>[];
  final List<JourneyAttackShot> shots = <JourneyAttackShot>[];

  /// 光束闪光视觉委托：分槽状态、逐帧衰减与扇形绘制由独立视觉组件承载。
  final JourneyAttackBeamFx beamFx = JourneyAttackBeamFx();

  /// 领域驻留计时：每只怪在每个领域单位内的连续驻留秒数（离场清零），
  /// 用于计算驻留伤害倍率——驻留越久伤害越高。
  /// 按单位 code + 怪物实例双键，避免两件领域互相串。
  final Map<String, Map<JourneyMonsterComponent, double>> _fieldDwell =
      <String, Map<JourneyMonsterComponent, double>>{};

  /// 领域驻留结算节拍：距上次按秒结算的累计时长，每满 1 秒触发一次伤害。
  final Map<String, Map<JourneyMonsterComponent, double>> _fieldTick =
      <String, Map<JourneyMonsterComponent, double>>{};

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
    _fieldDwell.clear();
    _fieldTick.clear();
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
      if (t == null) continue;
      // 新周期更短时旧计时可能超过新周期，钳住避免升级后空等。
      u.timer = math.min(t, unitPeriodOf(u));
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

  /// 由宿主在 updateWeapons 之后显式调用：环绕先结算命中，本步进只作用于
  /// 仍存活的怪，避免并行单位先手击杀导致环绕判定被旁路。
  void step(double dt) {
    if (dt <= 0 || game._ended || game._pendingLevelUps > 0) return;
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
          _tickAura(unit, dt);
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

  /// 领域脉冲周期（秒）：两件领域统一，默认 1.5 秒，后台可配。
  double get _fieldPulsePeriod =>
      game.battleNum('weapon', 'field_pulse_period_sec', 1.5).clamp(0.1, 60.0);

  /// 领域驻留结算周期（秒）：每满该时长结算一次驻留伤害。
  static const double fieldDwellSec = 1.0;

  /// 领域驻留封顶倍率：驻留越久伤害越高，倍率由 1 线性升到该值后封顶。
  double get _fieldDwellCapMult =>
      game.battleNum('weapon', 'field_dwell_cap_mult', 6.0).clamp(1.0, 20.0);

  /// 驻留达到封顶倍率所需秒数：期间倍率按驻留时长线性增长。
  double get _fieldDwellCapSec =>
      game.battleNum('weapon', 'field_dwell_cap_sec', 6.0).clamp(0.5, 60.0);

  /// 单怪当前驻留倍率：1 + 驻留秒数/达上限秒数 ×(封顶倍率−1)，封顶后恒定。
  double _fieldDwellMult(double dwellSec) {
    final ratio = (dwellSec / _fieldDwellCapSec).clamp(0.0, 1.0);
    return 1 + ratio * (_fieldDwellCapMult - 1);
  }

  /// 脉冲扩散半径相对武器臂长的比例（默认 0.3），后台可配。
  double get _fieldPulseRadiusRatio =>
      game.battleNum('weapon', 'field_pulse_radius_ratio', 0.3).clamp(0.01, 5.0);

  /// 领域范围 = 武器臂展长度；臂展缺失时用内置兜底。
  double get _fieldRadius => game.weaponArm?.outerRadius ?? 120.0;

  /// 弹道单次可命中的目标数上限，防止一颗弹体穿整屏。
  int get _attackTargetCap => game
      .battleNum('weapon', 'attack_target_cap', 3)
      .round()
      .clamp(1, 20)
      .toInt();

  /// 弹体存在时间上限（秒）：超时强制销毁，兜底异常射程/速度配置。
  double get _shotLifeSec =>
      game.battleNum('weapon', 'attack_shot_life_sec', 8.0).clamp(0.5, 60.0);

  /// 单位实际发射/脉冲周期（秒）：升级计时钳位与各形态发射节拍共用此口径，
  /// 兜底值按形态区分（领域走脉冲周期、穿透弹/回旋/光束各有缺省），
  /// 避免钳位上限与实际周期漂移导致升级后空等或抢发。
  double unitPeriodOf(JourneyAttackUnit unit) {
    switch (unit.kind) {
      case 'aura':
      case 'magnet':
        return _fieldPulsePeriod;
      case 'projectile':
        return (unit.intervalMs > 0 ? unit.intervalMs : 320) / 1000;
      case 'boomerang':
        return (unit.intervalMs > 0 ? unit.intervalMs : 900) / 1000;
      case 'beam':
        return (unit.intervalMs > 0 ? unit.intervalMs : 1200) / 1000;
      default:
        return (unit.intervalMs > 0 ? unit.intervalMs : 900) / 1000;
    }
  }

  /// 命中口径：单位自身伤害 + 等级/攻击卡 + 角色基础攻击，再乘通用增伤；
  /// 与环绕 hitDamageBase 同源，只是把环绕 damage 替换为该单位分级伤害。
  double damageOf(JourneyAttackUnit unit) =>
      (unit.damage + game.attackBonus + game.character.baseAttack) *
      (1 + game.damageAmpTotal);

  /// 返回是否真正命中（被冷却/死亡拦截时返回 false），供弹体决定是否消耗穿透。
  ///
  /// 弹道轨：与环绕武器同一伤害公式乘区（damageOf），走完整命中链——破甲、
  /// 暴击、击退/吸血（初始特效与全局维度槽取较高等级）、雷引/幌金绳/紫金铃
  /// 等特效；火眼金睛条件增伤并入增伤百分比合计后随命中生效。同怪命中受
  /// 形态冷却约束不会每帧叠加；角色专属伏魔重击不随并行命中消耗。
  bool _hit(JourneyAttackUnit unit, JourneyMonsterComponent m) {
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
      damageOf(unit),
      pierceIgnore: game.armorIgnoreRatio,
      knockLv: knockLv,
      lifestealLv: lifestealLv,
      toM: m.position - game.player.position,
      allowSignature: false,
      // 火眼金睛按增伤Σ%的一项结算，基数取该弹道自身未增伤基础值。
      conditionBase: unit.damage + game.attackBonus + game.character.baseAttack,
    );
    // 弹道轨命中点燃：按伤害比例的百分比型灼烧，经护甲；独立 source key
    // 不覆盖环绕驻留灼烧来源。
    _igniteProjectileBurn(unit, m);
    return true;
  }

  /// 弹道轨初始特效灼烧：按该单位分级伤害的固定比例，经护甲结算。
  /// 独立 source key 不覆盖环绕驻留灼烧来源。
  void _igniteProjectileBurn(JourneyAttackUnit unit, JourneyMonsterComponent m) {
    if (unit.starterEffect != 'burn' || m.isDead) return;
    m.ignite(
      source: 'attack_${unit.code}',
      burnDps: math.max(1.0, damageOf(unit)) *
          game.battleNum('weapon', 'attack_burn_ratio', 0.25),
      seconds: game.battleNum('weapon', 'attack_burn_sec', 2.0),
    );
  }

  /// 领域轨真实伤害：只按自身 value_num（领域每秒伤害）×驻留倍率结算，
  /// 不叠加角色基础攻击/等级攻击/增伤百分比，不受护甲减免。
  /// 不进入 _hitMonster，暴击/雷引/紫金铃/伏魔/火眼等环绕专属效果不触发，
  /// 领域伤害不触发任何吸血或回血——吸血只发生在武器与弹道命中链。
  ///
  /// [mult] 为该怪当前驻留倍率（驻留越久越高）；[fromPulse] 标识这次结算
  /// 来自周期脉冲（true）还是驻留按秒（false），仅用于受击圈反馈。
  void _hitField(
    JourneyAttackUnit unit,
    JourneyMonsterComponent m, {
    double mult = 1,
    bool fromPulse = false,
  }) {
    if (m.isDead) return;
    final dmg = math.max(0.0, unit.valueNum) * mult;
    if (dmg <= 0) return;
    m.takeDamage(dmg, armorIgnore: 1);
    // 领域灼烧：灼烧是固定伤害、只随升级提升，按领域自身每秒伤害基准
    // value_num 点燃真实伤害灼烧，不乘驻留倍率（驻留递增只作用于领域直伤）。
    // 独立 source key（field_<code>）与弹道灼烧（attack_<code>）、武器槽灼烧
    // （weapon_burn）分属不同链路，切换攻击形态不覆盖旧来源的伤害口径。
    if (unit.starterEffect == 'burn' && !m.isDead) {
      m.ignite(
        source: 'field_${unit.code}',
        burnDps: math.max(0.0, unit.valueNum) *
            game.battleNum('weapon', 'attack_burn_ratio', 0.25),
        seconds: game.battleNum('weapon', 'attack_burn_sec', 2.0),
        trueDamage: true,
      );
    }
    // 受击圈提示伤害来源：按脉冲节拍出现，驻留结算不画避免刷屏。
    if (fromPulse && !m.isDead) {
      game.fxLayer.spawnRing(
        m.position,
        m.radius + 4,
        color: unit.kind == 'magnet'
            ? const Color(0xFF7FA8D8)
            : const Color(0xFFE8703A),
      );
    }
  }

  /// 查询半径内的全部存活怪（含边缘重叠），不截断、不排序：领域伤害不限目标数。
  List<JourneyMonsterComponent> _monstersInRadius(
    Vector2 center,
    double radius,
  ) {
    final result = <JourneyMonsterComponent>[];
    for (final m in game.spatialGrid.queryRange(center, radius)) {
      if (m.isDead) continue;
      if ((m.position - center).length > radius + m.radius) continue;
      result.add(m);
    }
    return result;
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
    final period = unitPeriodOf(unit);
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
        lifeSec: _shotLifeSec,
      ));
    }
  }

  void _tickBoomerang(JourneyAttackUnit unit, double dt) {
    if (unit.timer > 0) {
      unit.timer -= dt;
      return;
    }
    final period = unitPeriodOf(unit);
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
      lifeSec: _shotLifeSec,
    ));
  }

  void _updateShots(dt) {
    final targetCap = _attackTargetCap;
    for (var i = shots.length - 1; i >= 0; i--) {
      final s = shots[i];
      // 存在时间兜底：超时即销毁，不依赖射程/返程判定能正常到头。
      s.lifeSec -= dt;
      if (s.lifeSec <= 0) {
        shots.removeAt(i);
        continue;
      }
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
            // 回程视为第二次独立扫掠：清空去重集合与目标计数，让去程
            // 命中过的怪在回程可再命中一次；同怪仍受形态命中冷却保护。
            s.hitSet.clear();
            s.hits = 0;
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
        // 单颗弹体的命中目标数受后台上限约束，回旋弹达上限后继续飞行返程。
        if (s.hits >= targetCap) break;
        // 仅真正命中（未被冷却/死亡拦截）才登记去重与消耗穿透，
        // 避免弹体被同帧其他单位的命中冷却「吃掉」却白耗穿透次数。
        if (!_hit(s.unit, m)) {
          continue;
        }
        s.hitSet.add(m);
        s.hits++;
        // pierce=穿透数（主目标之外可再命中数），故第 pierce+1 次命中后销毁；
        // 回旋弹不按穿透销毁，靠射程到头返程 + hitSet 去重。
        if (!s.boomerang && s.pierce > 0 && s.hits > s.pierce) {
          shots.removeAt(i);
          break;
        }
      }
    }
  }
}
