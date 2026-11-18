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
    default:
      return (brief: '', unit: _SlotUnit.intValue, base: 0, fallback: 0, cap: double.infinity);
  }
}

/// 按引擎口径算某维度在 [level] 级的展示数值：基准类（穿刺/吸血）1 级
/// 即基准值、此后每级加增量；其余按等级×每级值；暴伤仅展示槽位增量。
double _slotDisplayValue(
  String code,
  int level,
  double perLevel, ({
  String brief,
  _SlotUnit unit,
  double base,
  double fallback,
  double cap,
}) rule,
) {
  final step = perLevel > 0 ? perLevel : rule.fallback;
  final raw = (code == 'pierce' || code == 'lifesteal')
      ? rule.base + step * (level - 1)
      : rule.base + step * level;
  return raw.clamp(0.0, rule.cap);
}

/// 数值转文案：倍率类乘 100 取整，整数/分身取整，每秒数值保留 1 位小数。
String _formatSlotValue(double value, _SlotUnit unit) {
  switch (unit) {
    case _SlotUnit.percent:
      return '${(value * 100).round()}%';
    case _SlotUnit.perSecond:
      return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}/秒';
    case _SlotUnit.intValue:
    case _SlotUnit.count:
      return '${value.round()}';
  }
}

/// 维度槽当前等级的实际贡献值文案（属性详情面板与选卡对比共用同一口径）。
/// 无匹配规则时返回空串，由调用方回落原介绍文案。
String journeySlotValueText(String code, int level, double perLevel) {
  final rule = _slotDisplayRule(code);
  if (rule.brief.isEmpty) return '';
  return '${rule.brief} ${_formatSlotValue(
    _slotDisplayValue(code, level, perLevel, rule),
    rule.unit,
  )}';
}

/// 顿悟卡描述：简介 + 当前值→下一级值；无匹配规则时回落原介绍文案。
String _upgradeDesc(JourneySlotDefModel def, int currentLevel) {
  final rule = _slotDisplayRule(def.code);
  if (rule.brief.isEmpty) return def.effectPerLevel;
  final before = _formatSlotValue(
      _slotDisplayValue(def.code, currentLevel, def.valuePerLevel, rule), rule.unit);
  final after = _formatSlotValue(
      _slotDisplayValue(def.code, currentLevel + 1, def.valuePerLevel, rule), rule.unit);
  return '${rule.brief} $before → $after';
}

/// 三选一候选池（维度槽口径）：
/// - 空槽且维度未入槽 → 「习得·X」（占 1 槽，Lv1）；
/// - 已入槽且未达上限 → 「X · 顿悟」（等级 +1，展示下一级效果）；
/// - 槽满：只出已有槽升级 + 通用成长项（不出现新维度）；
/// - 通用成长项常驻（攻击卡累计达上限后不再入池，候选永不为空）；
/// - 特效触发法宝卡：入池=图鉴已解锁且未持有。
List<JourneyUpgradeChoice> drawChoices(JourneyFlameGame game) {
  final pool = <JourneyUpgradeChoice>[];
  final defs = game.config?.slotDefMap() ?? _fallbackSlotDefs();
  final hasEmptySlot = game.weaponSlots.length < 6;

  // 维度卡：习得（空槽）或升级（未满级）；描述只保留效果本身，
  // 不追加括号补充（局内卡牌空间小，冗余文案会溢出且干扰决策）
  for (final def in defs.values) {
    final held = game.weaponSlots.where((s) => s.code == def.code).toList();
    if (held.isEmpty) {
      if (hasEmptySlot) {
        pool.add(JourneyUpgradeChoice(
          JourneyUpgradeKind.slotLearn,
          code: def.code,
          title: '习得·${def.name}',
          desc: def.effectPerLevel,
        ));
      }
    } else if (held.first.level < def.maxLevel) {
      pool.add(JourneyUpgradeChoice(
        JourneyUpgradeKind.slotUpgrade,
        code: def.code,
        title: '${def.name} · 顿悟',
        desc: _upgradeDesc(def, held.first.level),
      ));
    }
  }

  // 被动加持卡：扩展批功德解锁的三件仅在图鉴解锁后入池（不免费掉落）
  if (game.passiveSlotCodes.length < 6) {
    final unlocked = JourneyProgressService.instance.state.unlockedWeapons;
    for (final p in kJourneyPassiveEffects.entries) {
      if (game.passiveSlotCodes.contains(p.key)) continue;
      if (kJourneyMeritPassives.contains(p.key) &&
          !unlocked.contains(p.key)) {
        continue;
      }
      pool.add(_passiveGrantChoice(p.key, p.value.$1, p.value.$2));
    }
  }

  // 特效触发法宝卡（§6）：入池=已解锁且未持有（持有后不重复出现）
  for (final e in kJourneyEffectWeapons.entries) {
    final unlocked = JourneyProgressService.instance.state.unlockedWeapons;
    if (game.effectWeapons.contains(e.key) || !unlocked.contains(e.key)) {
      continue;
    }
    pool.add(JourneyUpgradeChoice(
      JourneyUpgradeKind.effectGrant,
      code: e.key,
      title: '触发·${e.value.$1}',
      desc: e.value.$2,
    ));
  }

  // 通用成长项（槽满后仍可选的基础属性增长；数值走 globals 后台配置）
  final attackCap =
      game.config?.attackUpgradeCap ?? kJourneyAttackUpgradeCap;
  if (game.cardAttackTotal < attackCap) {
    pool.add(JourneyUpgradeChoice(
      JourneyUpgradeKind.attack,
      title: '伏魔真力',
      desc: '攻击 +${(game.config?.upgradeAttack ?? kJourneyUpgradeAttack).round()}',
    ));
  }
  pool
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.moveSpeed,
      title: '筋斗云气',
      desc: '移速 +${((game.config?.upgradeMove ?? 0.09) * 100).round()}%',
    ))
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.maxHp,
      title: '蟠桃益气',
      desc: '生命 +${(game.config?.upgradeHp ?? 20).round()}',
    ))
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.regen,
      title: '木灵回春',
      desc: '回复 +${(game.config?.upgradeRegen ?? 1.0).toStringAsFixed(1)}/秒',
    ))
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.pickupRange,
      title: '紫金磁引',
      desc: '拾取范围 +${(game.config?.upgradePickup ?? 18).round()}',
    ));

  pool.shuffle();
  return pool.take(3).toList();
}

/// 内置维度定义兜底（远端 journey_weapon_slots 未就绪时）。
Map<String, JourneySlotDefModel> _fallbackSlotDefs() {
  return <String, JourneySlotDefModel>{
    for (final d in kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson))
      d.code: d,
  };
}

/// 被动加持效果文案（入槽即生效，效果实现见 _grantPassiveWeapon）；
/// 描述一句话说清当前效果，不写括号补充/实现细节。
const Map<String, (String, String)> kJourneyPassiveEffects =
    <String, (String, String)>{
  'jindou_cloud': ('筋斗云', '移速 +12%'),
  'pantao': ('蟠桃', '生命上限 +20%，回复 +0.5/秒'),
  'renshen_guo': ('人参果', '经验 +25%'),
  'bishui_pearl': ('避水珠', '转速 +15%'),
  'dingfeng_pearl': ('定风丹', '臂长 +18'),
  'shelizi': ('舍利子', '伤害 +15%'),
  // 西游扩展批（功德解锁，图鉴直购）
  'sanheng_mao': ('三根毫毛', '免死一次，回 30% 生命'),
  'yujing_ping': ('玉净瓶', '每 20 秒回 20% 生命'),
  'huoyan_jingjing': ('火眼金睛', '精英/妖王受伤 +20%'),
};

JourneyUpgradeChoice _passiveGrantChoice(
  String code,
  String name,
  String desc,
) {
  return JourneyUpgradeChoice(
    JourneyUpgradeKind.passiveGrant,
    code: code,
    title: '加持·$name',
    desc: desc,
  );
}

/// 特效触发法宝文案（§6）：入池=图鉴已解锁，触发结算见 _hitMonster /
/// updateDamageTick；激活即入 game.effectWeapons。
const Map<String, (String, String)> kJourneyEffectWeapons =
    <String, (String, String)>{
  'kunxian_rope': ('幌金绳', '12% 概率定身 1.5 秒'),
  'fanshang_thorns': ('反伤荆棘', '受击反弹 30% 伤害'),
  'baoji_thunder': ('暴击雷引', '暴击引闪电链，波及 2 妖'),
  // 西游扩展批（功德解锁，图鉴直购）
  'zijin_ling': ('紫金铃', '同目标命中 3 次引爆'),
  'jinggang_zhuo': ('金刚琢', '每 12 秒套取并虚弱最近妖物'),
  'yinyang_ping': ('阴阳二气瓶', '每 18 秒定身灼烧最近妖物'),
};

/// 功德解锁的扩展被动（图鉴直购；未解锁不进三选一免费池）。
const Set<String> kJourneyMeritPassives = <String>{
  'sanheng_mao',
  'yujing_ping',
  'huoyan_jingjing',
};
