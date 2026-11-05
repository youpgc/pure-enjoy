part of 'journey_flame_game.dart';

/// 全局节拍伤害：0.5s 一结算，取接触中伤害最高怪；贴脸怪群不叠乘。
/// （口径详见概念文档 §7；节拍间隔后台可调，客户端先取常量。）
mixin JourneyDamageTickMixin {
  double _hurtTimer = 0;
  static const double hurtInterval = 0.5;

  /// 护甲减伤上限（百分比口径钳死值）：无论护甲多高，单次接触伤害
  /// 至少保留原值的 40%。
  static const double armorReductionCap = 0.60;

  /// 护甲值 → 减伤比例：递减曲线 armor/(armor+50)（50 甲=50%），
  /// 再钳到 [armorReductionCap] 以内。
  static double armorReductionRatio(double armor) {
    if (armor <= 0) return 0;
    return (armor / (armor + 50)).clamp(0.0, armorReductionCap);
  }

  void updateDamageTick(JourneyFlameGame game, double dt) {
    _hurtTimer += dt;
    if (_hurtTimer < hurtInterval) return;
    _hurtTimer = 0;

    final player = game.player;
    var strongest = 0.0;
    for (final m in game.monsters) {
      if (m.isDead) continue;
      final overlap = (m.position - player.position).length <=
          m.radius + JourneyPlayerComponent._radius;
      if (overlap && m._contactDamage > strongest) {
        strongest = m._contactDamage;
      }
    }
    if (strongest > 0) {
      final afterArmor =
          (strongest * (1 - armorReductionRatio(player.armor)))
              .clamp(1.0, double.maxFinite);
      player.takeDamage(afterArmor);
    }

    // 分离力：随机抽样两两推开（几何占位轻量做法，防完全叠点）
    final ms = game.monsters;
    if (ms.length >= 2) {
      final a = ms[game.rng.nextInt(ms.length)];
      final b = ms[game.rng.nextInt(ms.length)];
      if (!identical(a, b) && !a.isDead && !b.isDead) {
        final d = b.position - a.position;
        final minDist = a.radius + b.radius;
        final len = d.length;
        if (len > 0.01 && len < minDist) {
          final push = d.normalized() * (minDist - len) * 0.5;
          a.position -= push;
          b.position += push;
        }
      }
    }
  }
}
