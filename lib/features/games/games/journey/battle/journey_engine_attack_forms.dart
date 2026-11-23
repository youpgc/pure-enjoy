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

  /// 按当前出战角色构建并行攻击单位。常规 5 件法宝与角色 weaponCode
  /// 一一绑定，只有出战角色自己的那件法宝挂载为并行单位，其他角色的
  /// 法宝一律不挂——法宝归属角色，换人出战即换一件。
  ///
  /// 该法宝同时保留环绕底盘：取经四角色的法宝是 orbit 环绕型，只走
  /// 专属环绕参数、不产生并行单位；扩展五角色的法宝是非 orbit 形态，
  /// 在环绕底盘之外再叠加一份对应形态的并行攻击（环绕加领域）。
  List<JourneyAttackUnit> _buildAttackUnits() {
    final w = config?.weaponOf(weaponCode) ?? _seedWeaponOf(weaponCode);
    if (w == null || w.category != 'active') return const <JourneyAttackUnit>[];
    if (w.attackKind.isEmpty || w.attackKind == 'orbit') {
      return const <JourneyAttackUnit>[];
    }
    return <JourneyAttackUnit>[_attackUnitOf(w)];
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
    var value = grade?.valueNum ?? 0;
    if (value <= 0) value = damage;

    return JourneyAttackUnit(
      code: w.code,
      kind: w.attackKind,
      damage: damage,
      intervalMs: interval,
      projCount: projCount,
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
  void _tickAura(JourneyAttackUnit unit, double dt) {
    _tickField(unit, dt);
  }

  void _tickBeam(JourneyAttackUnit unit, double dt) {
    if (unit.timer > 0) {
      unit.timer -= dt;
      return;
    }
    final period = unitPeriodOf(unit);
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
    final targets = <JourneyMonsterComponent>[];
    for (final m in candidates) {
      if (m.isDead || m.attackUnitCds[beamSlot] > 0) continue;
      final toM = m.position - game.player.position;
      if (toM.length > range + m.radius) continue;
      if (math.acos((toM.normalized().dot(dir)).clamp(-1.0, 1.0)) >
          kBeamHalfAngle) {
        continue;
      }
      targets.add(m);
    }
    targets.sort((a, b) => (a.position - game.player.position).length2
        .compareTo((b.position - game.player.position).length2));
    for (final m in targets.take(_attackTargetCap)) {
      _hit(unit, m);
    }
  }

  void _tickMagnet(JourneyAttackUnit unit, double dt) {
    // 拾取范围增益在单位构建/升级时按差值同步到 player.pickupRange；
    // 领域伤害与 aura 同口径（驻留按秒 + 1.5 秒脉冲），见 _tickField。
    _tickField(unit, dt);
  }

  /// 领域轨逐帧推进：驻留按秒结算 + 周期脉冲两条独立线，范围=武器臂展。
  ///
  /// 驻留线：臂展内每只怪按各自连续驻留时长计伤——驻留越久倍率越高，
  /// 每满 1 秒结算一次真实伤害，不限制目标数；离开范围清零倍率。
  /// 脉冲线：每 [fieldPulsePeriod] 秒，以领域内每只怪为起点向外扩散
  /// `臂长×fieldPulseRadiusRatio` 的圆，波及圆内全部怪（含臂展外）各一次
  /// 真实伤害，同怪每次脉冲至多中一次（起点去重集）；臂展外的怪无驻留
  /// 倍率，按基础倍率结算，范围内则叠加各自驻留倍率。
  void _tickField(JourneyAttackUnit unit, double dt) {
    final radius = _fieldRadius;
    final inField = _monstersInRadius(game.player.position, radius);
    final present = inField.toSet();

    // — 驻留计时：连续驻留秒数（计倍率）+ 按秒结算节拍 —
    final dwell = _fieldDwell.putIfAbsent(
        unit.code, () => <JourneyMonsterComponent, double>{});
    final tick = _fieldTick.putIfAbsent(
        unit.code, () => <JourneyMonsterComponent, double>{});
    // 离场或死亡的怪清除两份计时：倍率归 1、结算节拍重来。
    dwell.removeWhere((m, _) => !present.contains(m) || m.isDead);
    tick.removeWhere((m, _) => !present.contains(m) || m.isDead);
    for (final m in inField) {
      dwell[m] = (dwell[m] ?? 0) + dt;
      final t = (tick[m] ?? 0) + dt;
      if (t >= JourneyAttackUnits.fieldDwellSec) {
        tick[m] = t % JourneyAttackUnits.fieldDwellSec;
        _hitField(unit, m, mult: _fieldDwellMult(dwell[m] ?? 0));
      } else {
        tick[m] = t;
      }
    }

    // — 周期脉冲线 —
    if (unit.timer > 0) {
      unit.timer -= dt;
      return;
    }
    unit.timer = _fieldPulsePeriod;
    if (inField.isEmpty) return;
    final pulseRadius = radius * _fieldPulseRadiusRatio;
    final hitSet = <JourneyMonsterComponent>{};
    for (final origin in inField) {
      for (final m in _monstersInRadius(origin.position, pulseRadius)) {
        if (!hitSet.add(m)) continue;
        _hitField(
          unit,
          m,
          mult: _fieldDwellMult(dwell[m] ?? 0),
          fromPulse: true,
        );
      }
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
        // 领域范围与伤害一致，取武器臂展长度。
        final radius = units._fieldRadius;
        final period = units._fieldPulsePeriod;
        // 伤害在 timer 归零时触发：越接近归零越亮，脉冲峰值与伤害同相。
        final pulse = unit.timer > 0
            ? (1 - unit.timer / period).clamp(0.0, 1.0)
            : 1.0;
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
