part of 'journey_flame_game.dart';

/// 维度卡升级对比的数值口径：把「等级 → 展示数值」按引擎结算规则还原，
/// 供顿悟卡展示「当前→下一级」。[brief] 为简介，[value] 取后台每级数值
/// （缺失时回落引擎内置），[unit] 决定展示格式。
///
/// 倍率类（speed/damage）引擎以小数累加（+0.10=+10%），展示乘 100；
/// 暴伤按槽位增量展示（玩家已有 150% 基础暴伤且受角色/法宝加成，槽位
/// 不决定最终倍率）；穿刺/吸血有起始基准且从 2 级起按增量累加（见引擎
/// updateWeapons / _hitMonster），其余为整数或每秒数值直接按等级线性。
enum _SlotUnit { percent, intValue, perSecond, count }

({String brief, _SlotUnit unit, double base, double fallback, double cap})
    _slotDisplayRule(String code) {
  switch (code) {
    case 'radius':
      return (brief: '武器臂长', unit: _SlotUnit.intValue, base: 0, fallback: 14, cap: double.infinity);
    case 'speed':
      return (brief: '环绕转速', unit: _SlotUnit.percent, base: 0, fallback: 0.10, cap: double.infinity);
    case 'damage':
      return (brief: '武器伤害', unit: _SlotUnit.percent, base: 0, fallback: 0.20, cap: double.infinity);
    case 'knockback':
      return (brief: '击退距离', unit: _SlotUnit.intValue, base: 0, fallback: 16, cap: double.infinity);
    case 'magnet':
      return (brief: '拾取范围', unit: _SlotUnit.intValue, base: 0, fallback: 40, cap: double.infinity);
    case 'armor':
      return (brief: '护甲', unit: _SlotUnit.intValue, base: 0, fallback: 3, cap: double.infinity);
    case 'burn':
      return (brief: '灼烧伤害', unit: _SlotUnit.perSecond, base: 0, fallback: 8, cap: double.infinity);
    case 'clone':
      return (brief: '武器分身', unit: _SlotUnit.count, base: 0, fallback: 1, cap: double.infinity);
    case 'crit_rate':
      return (brief: '暴击率', unit: _SlotUnit.percent, base: 0, fallback: 0.025, cap: 0.60);
    case 'crit_damage':
      return (brief: '暴击伤害', unit: _SlotUnit.percent, base: 0, fallback: 0.06, cap: double.infinity);
    case 'pierce':
      return (
        brief: '无视护甲',
        unit: _SlotUnit.percent,
        base: kJourneyPierceBaseRatio,
        fallback: kJourneyPierceIgnorePerLv,
        cap: kJourneyPierceRatioCap,
      );
    case 'lifesteal':
      return (
        brief: '命中回血',
        unit: _SlotUnit.percent,
        base: kJourneyLifestealBaseRatio,
        fallback: kJourneyLifestealRatioPerLv,
        cap: kJourneyLifestealRatioCap,
      );
    case 'vitality':
      return (brief: '生命上限', unit: _SlotUnit.percent, base: 0, fallback: 0.05, cap: 0.60);
    case 'cloud':
      return (brief: '移动速度', unit: _SlotUnit.percent, base: 0, fallback: 0.05, cap: double.infinity);
    case 'ward':
      return (brief: '受击减伤', unit: _SlotUnit.percent, base: 0, fallback: 0.04, cap: 0.50);
    case 'reflect':
      return (brief: '盾抵反震', unit: _SlotUnit.percent, base: 0, fallback: 0.15, cap: 3.0);
    case 'execute':
      // 普通怪处决血线：下限 1% + 每级增量×等级，钳到上限；妖王血线按绝对值另算
      return (
        brief: '残血处决',
        unit: _SlotUnit.percent,
        base: kJourneyExecuteNormalFloorRatio,
        fallback: 0.0175,
        cap: kJourneyExecuteNormalCapRatio,
      );
    case 'recovery':
      return (brief: '回元回血', unit: _SlotUnit.percent, base: 0, fallback: 0.05, cap: 0.50);
    case 'shield':
      return (brief: '护盾点数', unit: _SlotUnit.intValue, base: 0, fallback: 20, cap: double.infinity);
    case 'slow':
      return (brief: '范围减速', unit: _SlotUnit.percent, base: 0, fallback: 0.06, cap: 0.70);
    case 'bloodlust':
      return (brief: '满血攻速', unit: _SlotUnit.percent, base: 0, fallback: kJourneyBloodlustAmpPerLv, cap: double.infinity);
    case 'desperation':
      return (brief: '满血增伤', unit: _SlotUnit.percent, base: 0, fallback: kJourneyDesperationAmpPerLv, cap: double.infinity);
    case 'qiankun':
      return (
        brief: '命中护盾',
        unit: _SlotUnit.intValue,
        base: kJourneyQiankunShieldBase,
        fallback: kJourneyQiankunShieldPerLv,
        cap: double.infinity,
      );
    case 'poison':
      return (
        brief: '中毒伤害',
        unit: _SlotUnit.percent,
        base: kJourneyPoisonRatioBase,
        fallback: kJourneyPoisonRatioPerLv,
        cap: double.infinity,
      );
    default:
      return (brief: '', unit: _SlotUnit.intValue, base: 0, fallback: 0, cap: double.infinity);
  }
}
