part of 'journey_flame_game.dart';

/// 角色基础攻击成长：等级逐级的线性加成与三选一攻击卡累计加成合流，
/// 独立于法宝分级表（Lv9 起仍随等级增长），并在单次命中基数上统一结算。
extension JourneyGrowth on JourneyFlameGame {
  /// 基础攻击加成合计。
  double get attackBonus => levelAttackTotal + cardAttackTotal;

  /// 单次命中基数：法宝品阶伤害 + 基础攻击加成；紫金宝葫（jinjiao
  /// 特殊能力）每层叠层 ×1.03（击杀精英/妖王 +1 层）。
  /// 环绕命中、触发法宝、参照物扫掠与属性面板共用此口径。
  double get hitDamageBase =>
      ((weaponArm?.damage ?? weaponBaseDamage) + attackBonus) *
      (1 + 0.03 * _jinjiaoStacks);
}
