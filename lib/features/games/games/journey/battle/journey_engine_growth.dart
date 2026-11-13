part of 'journey_flame_game.dart';

/// 伤害公式（固定，全引擎同源）：
/// 基础值 = 角色基础攻击（journey_characters.base_attack）+ 等级攻击
/// + 攻击卡 + 法宝品阶伤害；
/// 增伤% = 攻击力%（天赋）+ 武器增伤%（伤害槽/舍利子/红孩儿光环）
/// + 紫金宝葫叠层 + 特殊能力窗口，各来源加法合流；
/// 单次命中 = 基础值 ×(1+Σ%)，一次乘算不做乘法叠乘；暴击命中再 ×暴伤
/// （独立判定机制）。特效伤害按基础数值百分比或固定真实数值结算。
extension JourneyGrowth on JourneyFlameGame {
  /// 基础攻击加成合计（等级逐级 + 三选一攻击卡）。
  double get attackBonus => levelAttackTotal + cardAttackTotal;

  /// 基础值合计（不含任何百分比加成）。
  double get damageBaseValue =>
      (weaponArm?.damage ?? weaponBaseDamage) +
      attackBonus +
      character.baseAttack;

  /// 单次命中基数 = 基础值 ×(1+增伤Σ%)。环绕命中、触发法宝、参照物
  /// 扫掠与属性面板共用此口径（火眼金睛对精英/妖王的条件增伤在
  /// _hitMonster 内按基础值加法叠加）。
  double get hitDamageBase => damageBaseValue * (1 + damageAmpTotal);
}
