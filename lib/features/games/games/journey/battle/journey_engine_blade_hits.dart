part of 'journey_flame_game.dart';

/// 环绕扇叶数量上限：本尊 1 + 分身槽最多 5（临时增益并入分身上限）。
const int kJourneyMaxBlades = 6;

/// 命中豁免上限（秒）：防止后台误配超长窗口导致武器长期失效。
const double kJourneyBladeHitCdMaxSec = 5.0;

/// 单个扇叶对单个目标的命中豁免序列：索引即扇叶序号，各扇叶独立计时。
/// 后续新增的命中型维度槽统一经此判定与登记，保证伤害和由命中触发的
/// 效果在同一豁免窗口内只结算一次，且扇叶之间互不共享豁免。
extension JourneyBladeHitCooldowns on List<double> {
  bool canBladeHit(int index) =>
      index >= 0 && index < length && this[index] <= 0;

  void markBladeHit(int index, double cooldown) {
    if (index < 0 || index >= length) return;
    this[index] = cooldown.clamp(0.0, kJourneyBladeHitCdMaxSec);
  }

  void tickBladeHits(double dt) {
    for (var i = 0; i < length; i++) {
      if (this[i] > 0) this[i] = math.max(0.0, this[i] - dt);
    }
  }
}

/// 扇形半角：由臂宽与目标半径按距离反算，目标越近张角越大。
double bladeAngularHalf(
        JourneyWeaponArm arm, double targetRadius, double dist) =>
    math.atan2(arm.halfWidth + targetRadius, dist);

/// 首个命中扇叶序号：角度差归一到 [-π, π] 后落在扇形半角内即命中。
/// canHit 由调用方给出该扇叶是否处于豁免期，伤害与命中触发效果共用此判定。
int? bladeAngleHit({
  required JourneyFlameGame game,
  required JourneyWeaponArm arm,
  required double targetAngle,
  required double angularHalf,
  required bool Function(int blade) canHit,
}) {
  for (var b = 0; b < game.bladeCount; b++) {
    if (!canHit(b)) continue;
    final a = arm.angle + b * math.pi * 2 / game.bladeCount;
    var diff = (targetAngle - a) % (math.pi * 2);
    if (diff > math.pi) diff -= math.pi * 2;
    if (diff.abs() <= angularHalf) return b;
  }
  return null;
}

/// 命中豁免时长：后台 weapon.hit_cd 可配，缺省 0.3 秒。
extension JourneyBladeHitConfig on JourneyFlameGame {
  double get bladeHitCd =>
      battleNum('weapon', 'hit_cd', 0.3).clamp(0.0, kJourneyBladeHitCdMaxSec);

  /// 击退按目标冷却：后台 weapon.knockback_cd 可配，缺省 0.3 秒。
  /// 独立于逐扇叶命中豁免，保证同一目标在窗口内只被击退一次。
  double get knockbackHitCd =>
      battleNum('weapon', 'knockback_cd', 0.3)
          .clamp(0.0, kJourneyBladeHitCdMaxSec);
}

/// 可击破参照物同样按扇叶持有独立豁免，避免同一扇叶在窗口内重复扣血。
extension JourneyBladeMapSweep on JourneyWeaponMixin {
  void sweepMapObjects(
    JourneyFlameGame game,
    JourneyWeaponArm arm,
    double dt,
  ) {
    final cd = game.bladeHitCd;
    final allCds = game._mapObjHitCd;
    final expired = <int>[];
    allCds.forEach((key, value) {
      value.tickBladeHits(dt);
      if (value.every((t) => t <= 0)) expired.add(key);
    });
    for (final key in expired) {
      allCds.remove(key);
    }

    final center = game.player.position;
    final objs = game.runtime.mapObjects;
    for (var i = 0; i < objs.length; i++) {
      if (!game.isMapObjectBreakableAlive(i)) continue;
      final o = objs[i];
      final toO = Vector2(o.x, o.y) - center;
      final dist = toO.length;
      if (dist > arm.outerRadius + o.radius || dist < 1) continue;
      final cds = allCds.putIfAbsent(
        i,
        () => List<double>.filled(kJourneyMaxBlades, 0),
      );
      final hitBlade = bladeAngleHit(
        game: game,
        arm: arm,
        targetAngle: math.atan2(toO.y, toO.x),
        angularHalf: bladeAngularHalf(arm, o.radius, dist),
        canHit: (b) => cds.canBladeHit(b),
      );
      if (hitBlade == null) continue;
      game.damageMapObject(i, game.hitDamageBase);
      cds.markBladeHit(hitBlade, cd);
    }
  }
}
