part of 'journey_flame_game.dart';

/// 并行攻击单位的领域/光束/磁吸行为、分级数值构建与渲染。
/// 与主调度文件同 library，共享 JourneyAttackUnit/JourneyAttackShot。

extension JourneyAttackForms on JourneyFlameGame {
  /// 内置种子按 code 查表（远端配置未就绪时并行单位取兜底参数）。
  JourneyWeaponModel? _seedWeaponOf(String code) {
    for (final row in kJourneyWeaponSeed) {
      if (row['code'] == code) return JourneyWeaponModel.fromJson(row);
    }
    return null;
  }

  /// 按已解锁集构建本局的并行攻击单位。已解锁集取服务端进度快照
  /// （与本地镜像一致），只挂载 category=active 且 attack_kind 非 orbit 的
  /// 常规法宝；角色专属环绕法宝不重复挂载。
  ///
  /// 常规 5 件与角色 weaponCode 一一绑定（角色解锁即得），当前出战角色
  /// 的那件法宝已作为环绕主武器生效，必须从并行单位排除，否则同一件
  /// 法宝双份攻击。切换角色出战时排除项随之变化。
  List<JourneyAttackUnit> _buildAttackUnits() {
    final unlocked = JourneyProgressService.instance.state.unlockedWeapons;
    final mainWeapon = weaponCode;
    final result = <JourneyAttackUnit>[];
    for (final code in unlocked) {
      if (code == mainWeapon) continue;
      final w = config?.weaponOf(code) ?? _seedWeaponOf(code);
      if (w == null || w.category != 'active') continue;
      if (w.attackKind.isEmpty || w.attackKind == 'orbit') continue;
      result.add(_attackUnitOf(w));
    }
    return result;
  }

  /// 单件法宝的分级数值快照：L1~L8 查分级表，L9+ 按 weapon_grade_per_lv
  /// 复利延展（与环绕 _gradeDamage 同口径）；各列缺行/为 0 时按列回落
  /// journey_weapons base 列或语义兜底。
  JourneyAttackUnit _attackUnitOf(JourneyWeaponModel w) {
    final levels = config?.weaponLevels[w.code] ??
        const <JourneyWeaponLevelModel>[];
    JourneyWeaponLevelModel? gradeAt(int lv) {
      for (final l in levels) {
        if (l.lv == lv) return l;
      }
      return null;
    }

    final lv = math.min(_charLv, 8);
    final grade = gradeAt(lv);
    final per = config?.weaponGradePerLv ?? kJourneyWeaponGradePerLv;
    double extend(double anchor) => _charLv <= 8
        ? anchor
        : anchor * math.pow(1 + per, _charLv - 8).toDouble();

    final baseDamage = w.baseDamage > 0 ? w.baseDamage : 14.0;
    double damage = grade?.damage.toDouble() ?? 0;
    if (damage <= 0) damage = baseDamage;
    damage = extend(damage);

    double interval = grade?.intervalMs.toDouble() ?? 0;
    if (interval <= 0) interval = w.baseIntervalMs;
    var projCount = grade?.projCount ?? 0;
    if (projCount <= 0) projCount = 1;
    var heal = grade?.healAmount.toDouble() ?? 0;
    if (heal <= 0) heal = w.healFixed;
    var value = grade?.valueNum ?? 0;
    if (value <= 0) value = damage;

    return JourneyAttackUnit(
      code: w.code,
      kind: w.attackKind,
      damage: damage,
      intervalMs: interval,
      projCount: projCount,
      healAmount: heal,
      valueNum: value,
      pierce: w.pierce,
      speed: w.projectileSpeed,
      aoeRadius: w.aoeRadius,
      rangePx: w.rangePx,
      starterEffect: w.starterEffect,
    );
  }

  /// 升级后刷新所有并行单位数值（保留计时器，不重置周期）。
  void _refreshAttackUnits() => attackUnits?.refresh();
}

/// 领域/光束/磁吸的逐帧行为（挂在调度组件上，同 library 访问宿主字段）。
extension JourneyAttackUnitTick on JourneyAttackUnits {
  void _tickAura(JourneyAttackUnit unit) {
    final radius = unit.aoeRadius > 0
        ? unit.aoeRadius
        : (game.weaponArm?.outerRadius ?? 120);
    final candidates = game.spatialGrid.queryRange(game.player.position, radius);
    for (final m in candidates) {
      if (m.isDead || (m.position - game.player.position).length > radius + m.radius) {
        continue;
      }
      _hit(unit, m, multiplier: unit.valueNum / math.max(1.0, unit.damage));
    }
  }

  void _tickBeam(JourneyAttackUnit unit, double dt) {
    if (unit.timer > 0) {
      unit.timer -= dt;
      return;
    }
    final period = (unit.intervalMs > 0 ? unit.intervalMs : 1200) / 1000;
    final range = unit.rangePx > 0
        ? unit.rangePx
        : (game.weaponArm?.outerRadius ?? 320) + 80;
    final target = _nearest(range);
    if (target == null) {
      unit.timer = math.max(0.2, period - 1);
      return;
    }
    unit.timer = period;
    // 目标恰与玩家重叠时零向量没有方向，兜底朝右，避免扇形判定全落空。
    final delta = target.position - game.player.position;
    final dir = delta.length > 0.001 ? delta.normalized() : Vector2(1, 0);
    beamFx.trigger(unit.code, dir, range);

    final beamSlot = _attackUnitSlot('beam');
    final candidates = game.spatialGrid.queryRange(game.player.position, range);
    for (final m in candidates) {
      if (m.isDead || m.attackUnitCds[beamSlot] > 0) continue;
      final toM = m.position - game.player.position;
      if (toM.length > range + m.radius) continue;
      if (math.acos((toM.normalized().dot(dir)).clamp(-1.0, 1.0)) >
          kBeamHalfAngle) {
        continue;
      }
      _hit(unit, m);
    }
  }

  void _tickMagnet(JourneyAttackUnit unit, double dt) {
    // 拾取范围增益在单位构建/升级时按差值同步到 player.pickupRange；
    // 这里只负责紫金葫芦的近身周期伤害与命中固定回血。
    final radius = unit.aoeRadius > 0 ? unit.aoeRadius : 120.0;
    final candidates = game.spatialGrid.queryRange(game.player.position, radius);
    for (final m in candidates) {
      if (m.isDead || (m.position - game.player.position).length > radius + m.radius) {
        continue;
      }
      _hit(unit, m, multiplier: unit.valueNum / math.max(1.0, unit.damage));
    }
  }
}

/// 并行攻击单位渲染：弹体（穿透弹金红/回旋环青金）、领域柔光圈、
/// 光束扇形闪光。渲染只读状态，不写回任何数值。
class JourneyAttackUnitRenderer extends Component {
  JourneyAttackUnitRenderer({required this.units});

  final JourneyAttackUnits units;

  @override
  void render(Canvas canvas) {
    final game = units.game;
    final center = game.player.position.toOffset();

    for (final unit in units.units) {
      if (unit.kind == 'aura' || unit.kind == 'magnet') {
        final radius = unit.aoeRadius > 0
            ? unit.aoeRadius
            : (game.weaponArm?.outerRadius ?? 120);
        final pulse = 0.5 + 0.5 * math.sin(units._auraPulse * 4);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = (unit.kind == 'aura'
                    ? const Color(0xFFE8703A)
                    : const Color(0xFF7FA8D8))
                .withValues(alpha: 0.05 + 0.04 * pulse),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = (unit.kind == 'aura'
                    ? const Color(0xFFE8703A)
                    : const Color(0xFF7FA8D8))
                .withValues(alpha: 0.22 + 0.12 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }

    units.beamFx.render(canvas, center);

    for (final s in units.shots) {
      final isBoom = s.boomerang;
      canvas.drawCircle(
        s.pos.toOffset(),
        isBoom ? 9 : 5,
        Paint()
          ..color = (isBoom
                  ? const Color(0xFF9AD5C8)
                  : const Color(0xFFFFB27A))
              .withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        s.pos.toOffset(),
        isBoom ? 13 : 8,
        Paint()
          ..color = (isBoom
                  ? const Color(0xFF9AD5C8)
                  : const Color(0xFFFFB27A))
              .withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}
