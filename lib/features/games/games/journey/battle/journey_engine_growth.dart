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

  /// 增伤百分比合计（伤害公式固定：基础值 →(1+Σ%) 单次乘算，各百分比
  /// 来源加法合流，不做乘法叠乘）：
  /// - attackAmp：攻击力%（天赋锐金/离火本源+化形，局外注入）；
  /// - damageAmp：武器增伤%（1.0 基准，舍利子 +15%/级、红孩儿光环 +8%，
  ///   钳 ≤+200%）；
  /// - 紫金宝葫叠层 3%/层（jinjiao 特殊能力，击杀精英/妖王 +1 层）；
  /// - 三头六臂（nezha 特殊能力）增益窗口 +40%；
  /// - 背水一战维度槽：随缺失生命档位提升，满级低血 +300%。
  double get damageAmpTotal =>
      attackAmp +
      (damageAmp - 1.0).clamp(0.0, battleNum('damage', 'amp_cap', 2.0)) +
      battleNum('ability', 'jinjiao_per_stack', 0.03) * _jinjiaoStacks +
      (_nezhaWindow > 0 ? battleNum('ability', 'nezha_amp', 0.4) : 0) +
      desperationAmp;

  /// 单次命中基数 = 基础值 ×(1+增伤Σ%)。环绕命中、触发法宝、参照物
  /// 扫掠与属性面板共用此口径（火眼金睛对精英/妖王的条件增伤在
  /// _hitMonster 内按基础值加法叠加）。
  double get hitDamageBase =>
      damageBaseValue * (1 + damageAmpTotal) * bossSkillDamageFactor;

  /// 被动法宝伤害加成系数：只含舍利子（入槽即生效），钳上限与命中轨同源。
  /// 绕开命中链的对怪伤害（灼烧/中毒/领域/反震/荆棘）乘此系数，使被动法宝
  /// 增伤对所有伤害通用；命中轨的 damageAmpTotal 已含舍利子，不再叠加。
  /// 两轨均钳同一 amp_cap：命中轨钳武器增伤合计、绕开轨只钳被动法宝单源，
  /// 是「仅被动法宝增伤通用」的既定口径，不是两轨上限分叉。
  /// 系数在点燃/命中时固化，持续期内才入槽的被动法宝于下次续燃/命中生效，
  /// 与既有灼烧固化口径同源。
  double get passiveAmpFactor =>
      1 + passiveDamageAmp.clamp(0.0, battleNum('damage', 'amp_cap', 2.0));

  /// 属性面板展示口径：最终角速度（含嗜血低血加成与 5 圈/秒=10π 钳制，
  /// 与环绕推进同源；不含限时增益窗口的临时转速）。
  double get displayAngularSpeed =>
      ((weaponArm?.speedBase ?? 0) * (spinAmp + bloodlustAmp))
          .clamp(0.0, 10 * math.pi);

  /// 穿刺破甲比例：1 级初始值（未配回落 pierce_base）+ 每级增量
  /// （value_per_level 后台可配），钳 ≤ 上限。环绕命中与并行单位命中共用此口径。
  double get armorIgnoreRatio {
    final lv = slotLevel('pierce');
    if (lv <= 0) return 0.0;
    return slotValueAtLevel(
      'pierce',
      lv,
      kJourneyPierceIgnorePerLv,
      levelOneFallback:
          battleNum('weapon', 'pierce_base', kJourneyPierceBaseRatio),
    ).clamp(0.0, battleNum('weapon', 'pierce_cap', kJourneyPierceRatioCap));
  }
}
