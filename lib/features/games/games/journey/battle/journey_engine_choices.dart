part of 'journey_flame_game.dart';

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
        desc: def.effectPerLevel,
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
      desc: '基础攻击 +${(game.config?.upgradeAttack ?? kJourneyUpgradeAttack).round()}',
    ));
  }
  pool
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.moveSpeed,
      title: '筋斗云气',
      desc: '移动速度 +${((game.config?.upgradeMove ?? 0.09) * 100).round()}%',
    ))
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.maxHp,
      title: '蟠桃益气',
      desc: '生命上限 +${(game.config?.upgradeHp ?? 20).round()} 并回满同量',
    ))
    ..add(JourneyUpgradeChoice(
      JourneyUpgradeKind.regen,
      title: '木灵回春',
      desc: '自动回复 +${(game.config?.upgradeRegen ?? 1.0).toStringAsFixed(1)}/秒',
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
  'jindou_cloud': ('筋斗云', '移动速度 +12%'),
  'pantao': ('蟠桃', '生命上限 +25，回复 +0.5/秒'),
  'renshen_guo': ('人参果', '经验获取 +25%'),
  'bishui_pearl': ('避水珠', '环绕转速 +15%'),
  'dingfeng_pearl': ('定风丹', '武器臂长 +18'),
  'shelizi': ('舍利子', '武器伤害 +15%'),
  // 西游扩展批（功德解锁，图鉴直购）
  'sanheng_mao': ('三根毫毛', '致命伤免死一次，回 30% 生命'),
  'yujing_ping': ('玉净瓶甘露', '每 20 秒回复 20% 生命'),
  'huoyan_jingjing': ('火眼金睛', '精英与妖王受伤 +20%'),
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
  'kunxian_rope': ('幌金绳', '命中 12% 概率定身 1.5 秒'),
  'fanshang_thorns': ('反伤荆棘', '受击反弹 30% 伤害'),
  'baoji_thunder': ('暴击雷引', '暴击引发闪电链，波及最多 2 个妖物'),
  // 西游扩展批（功德解锁，图鉴直购）
  'zijin_ling': ('紫金铃', '同一目标命中 3 次引发妖火爆裂'),
  'jinggang_zhuo': ('金刚琢', '每 12 秒套取最近妖物并使其虚弱'),
  'yinyang_ping': ('阴阳二气瓶', '每 18 秒吸纳最近妖物定身灼烧'),
};

/// 功德解锁的扩展被动（图鉴直购；未解锁不进三选一免费池）。
const Set<String> kJourneyMeritPassives = <String>{
  'sanheng_mao',
  'yujing_ping',
  'huoyan_jingjing',
};
