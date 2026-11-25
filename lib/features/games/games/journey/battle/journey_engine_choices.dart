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
  final cached = JourneyConfigService.instance.cached;
  // 处决展示与结算同源：下限读 normal_floor、上限读 normal_cap，
  // 反震展示上限共用 reflect_cap，避免后台调参后卡牌显示与实际不符
  final base = code == 'execute'
      ? (cached?.battleNum(
                  'execute', 'normal_floor', kJourneyExecuteNormalFloorRatio) ??
              kJourneyExecuteNormalFloorRatio)
          .clamp(0.0, 1.0)
      : rule.base;
  final step = perLevel > 0 ? perLevel : rule.fallback;
  final raw = (code == 'pierce' || code == 'lifesteal' || code == 'execute')
      ? base + step * (level - 1)
      : base + step * level;
  final cap = code == 'reflect'
      ? math.max(
          0.0,
          cached?.weaponParam('zhaoyao_jing', 'reflect_cap', 3.0) ?? 3.0,
        )
      : code == 'execute'
          ? math.max(
              base,
              (cached?.battleNum(
                      'execute', 'normal_cap', kJourneyExecuteNormalCapRatio) ??
                  kJourneyExecuteNormalCapRatio)
                  .clamp(0.0, 1.0),
            )
          : rule.cap;
  return raw.clamp(0.0, cap);
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

/// 三选一卡的唯一键（类别+编码）：基础属性卡 code 为空但同属 base 类，
/// 不参与轮空；维度槽/被动/触发按各自 code 识别。
String _choiceKey(JourneyUpgradeChoice c) => '${c.category.name}:${c.code}';

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
          category: JourneyChoiceCategory.slot,
        ));
      }
    } else if (held.first.level < def.maxLevel) {
      pool.add(JourneyUpgradeChoice(
        JourneyUpgradeKind.slotUpgrade,
        code: def.code,
        title: '${def.name} · 顿悟',
        desc: _upgradeDesc(def, held.first.level),
        category: JourneyChoiceCategory.slot,
      ));
    }
  }

  // 被动加持卡：扩展批功德解锁的三件仅在图鉴解锁后入池（不免费掉落）
  if (game.passiveSlotCodes.length < 6) {
    final unlocked = JourneyProgressService.instance.state.unlockedWeapons;
    for (final p in kJourneyPassiveNames.entries) {
      if (game.passiveSlotCodes.contains(p.key)) continue;
      if (kJourneyMeritPassives.contains(p.key) &&
          !unlocked.contains(p.key)) {
        continue;
      }
      pool.add(_passiveGrantChoice(
        p.key,
        p.value,
        journeyPassiveEffectDesc(p.key, game.weaponParam),
      ));
    }
  }

  // 特效触发法宝卡（§6）：入池=已解锁且未持有（持有后不重复出现）
  for (final e in kJourneyEffectWeaponNames.entries) {
    final unlocked = JourneyProgressService.instance.state.unlockedWeapons;
    if (game.effectWeapons.contains(e.key) || !unlocked.contains(e.key)) {
      continue;
    }
    pool.add(JourneyUpgradeChoice(
      JourneyUpgradeKind.effectGrant,
      code: e.key,
      title: '触发·${e.value}',
      desc: journeyEffectWeaponDesc(e.key, game.weaponParam),
      category: JourneyChoiceCategory.effect,
    ));
  }

  // 基础值成长卡（journey_upgrade_cards）：名称/每级数值/入池后台可配；
  // 文案由 code + 数值生成，避免文案与数值两处脱节；enabled=false 不入池。
  final cardMap = game.config?.upgradeCardMap() ??
      const <String, JourneyUpgradeCardModel>{};
  JourneyUpgradeCardModel cardOf(String code, String name, double fallback) =>
      cardMap[code] ??
      JourneyUpgradeCardModel(code: code, name: name, value: fallback);
  final attackCap =
      game.config?.attackUpgradeCap ?? kJourneyAttackUpgradeCap;
  void addBaseCard(
    String code,
    String name,
    double fallback,
    JourneyUpgradeKind kind,
    String Function(double value) descOf, {
    bool available = true,
  }) {
    if (!available) return;
    final card = cardOf(code, name, fallback);
    if (!card.enabled) return;
    pool.add(JourneyUpgradeChoice(
      kind,
      title: card.name,
      // 文案数值与结算共用同一取值口径：表值>0 优先，否则回落兜底。
      // 避免表内 value<=0 或行缺失时"显示 +0、实加兜底值"脱节。
      desc: descOf(game.upgradeCardValue(code, fallback)),
      category: JourneyChoiceCategory.base,
    ));
  }

  // 兜底值与结算侧逐项同口径（config globals 优先、内置常量兜底）：
  // 表缺行时文案与结算回落到同一个值，不因两处 fallback 不同再度脱节。
  addBaseCard('attack', '伏魔真力',
      game.config?.upgradeAttack ?? kJourneyUpgradeAttack,
      JourneyUpgradeKind.attack,
      (v) => '攻击 +${v.round()}',
      available: game.cardAttackTotal < attackCap);
  addBaseCard('move_speed', '筋斗云气', game.config?.upgradeMove ?? 0.09,
      JourneyUpgradeKind.moveSpeed,
      (v) => '移速 +${(v * 100).round()}%');
  addBaseCard('max_hp', '蟠桃益气', game.config?.upgradeHp ?? 20,
      JourneyUpgradeKind.maxHp,
      (v) => '生命 +${v.round()}');
  addBaseCard('regen', '木灵回春', game.config?.upgradeRegen ?? 1.0,
      JourneyUpgradeKind.regen,
      (v) => '回复 +${v.toStringAsFixed(1)}/秒');
  addBaseCard('pickup_range', '紫金磁引', game.config?.upgradePickup ?? 18,
      JourneyUpgradeKind.pickupRange,
      (v) => '拾取范围 +${v.round()}');

  // 候选池保底：极端情况下（所有基础卡被后台关闭、维度全满级、攻击封顶、
  // 被动/特效全持有）候选可能为空。空列表会让选卡弹窗无卡可选，而引擎仍处
  // 升级暂停态，关闭后延迟重弹形成死循环。此处注入一张保底成长卡兜底。
  if (pool.isEmpty) {
    final hpStep =
        game.upgradeCardValue('max_hp', game.config?.upgradeHp ?? 20);
    pool.add(JourneyUpgradeChoice(
      JourneyUpgradeKind.maxHp,
      title: '蟠桃益气',
      desc: '生命 +${hpStep.round()}',
      category: JourneyChoiceCategory.base,
    ));
  }

  // 上一轮展示却没被选中的非基础卡：本轮轮空一次（基础卡不参与）。
  // 仅剩轮空卡时放宽限制，避免候选为空导致选卡弹窗死循环。
  if (game._lastShownUnpicked.isNotEmpty) {
    final filtered = pool
        .where((c) => !game._lastShownUnpicked.contains(_choiceKey(c)))
        .toList();
    if (filtered.isNotEmpty) {
      pool
        ..clear()
        ..addAll(filtered);
    }
  }

  // 四类权重轮盘 + 槽满剔除：先按类权重选类别，再在类内均匀随机抽卡。
  final drawn = _drawWeightedByCategory(pool, 3, game);
  // 记录本轮展示的非基础卡；选卡后据此把未选中的转入下一轮轮空集合。
  game._currentShownNonBase = {
    for (final c in drawn)
      if (c.category != JourneyChoiceCategory.base) _choiceKey(c),
  };
  return drawn;
}

/// 按类权重轮盘抽 [count] 张：每轮先按「有剩余候选的类」的类权重选类别，
/// 再在该类内均匀随机抽一张。候选被抽空（含槽满后该类无新卡）的类
/// 权重剔除，不再参与后续轮盘——即「槽满不占权重」。类权重取后台 economy
/// 组 choice_weight_*，缺省 1；全部退化为均匀随机。
/// 武器维度槽类一次最多取 2 张，避免三选一被单一类别占满；仅剩该类时
/// 为抽满仍保留。
List<JourneyUpgradeChoice> _drawWeightedByCategory(
  List<JourneyUpgradeChoice> pool,
  int count,
  JourneyFlameGame game,
) {
  final rng = game.rng;
  final remaining = List<JourneyUpgradeChoice>.from(pool);
  final picked = <JourneyUpgradeChoice>[];

  const categories = <JourneyChoiceCategory>[
    JourneyChoiceCategory.slot,
    JourneyChoiceCategory.passive,
    JourneyChoiceCategory.effect,
    JourneyChoiceCategory.base,
  ];
  double categoryWeight(JourneyChoiceCategory c) {
    final key = switch (c) {
      JourneyChoiceCategory.slot => 'choice_weight_slot',
      JourneyChoiceCategory.passive => 'choice_weight_passive',
      JourneyChoiceCategory.effect => 'choice_weight_effect',
      JourneyChoiceCategory.base => 'choice_weight_base',
    };
    return game.battleNum('economy', key, 1);
  }

  // 武器维度槽类一次三选一最多取 2 张，避免单一类别占满选项。
  const maxSlotPerDraw = 2;

  while (picked.length < count && remaining.isNotEmpty) {
    // 候选被抽空的类不参与本轮（槽满/耗尽即权重剔除）。
    var available = categories
        .where((c) => remaining.any((x) => x.category == c))
        .toList();
    if (available.isEmpty) break;

    // 维度槽已达上限且有其它类候选时剔除该类；若仅剩维度槽则保留，
    // 保证仍能抽满（例如图鉴未解锁导致其它类无候选）。
    final slotPicked =
        picked.where((x) => x.category == JourneyChoiceCategory.slot).length;
    if (slotPicked >= maxSlotPerDraw) {
      final others = available
          .where((c) => c != JourneyChoiceCategory.slot)
          .toList();
      if (others.isNotEmpty) available = others;
    }

    var total = 0.0;
    for (final c in available) {
      final w = categoryWeight(c);
      if (w > 0) total += w;
    }
    JourneyChoiceCategory chosen;
    if (total <= 0) {
      // 类权重全部<=0：退化为在有候选的类之间均匀选类，保证仍出满。
      chosen = available[rng.nextInt(available.length)];
    } else {
      var ticket = rng.nextDouble() * total;
      chosen = available.last;
      for (final c in available) {
        final w = categoryWeight(c);
        if (w <= 0) continue;
        ticket -= w;
        if (ticket <= 0) {
          chosen = c;
          break;
        }
      }
    }

    // 类内均匀随机抽一张（权重只在类别层配置，类内不设单项权重）。
    final inClass = remaining.where((x) => x.category == chosen).toList();
    final take = inClass[rng.nextInt(inClass.length)];
    picked.add(take);
    remaining.remove(take);
  }
  return picked;
}

/// 内置维度定义兜底（远端 journey_weapon_slots 未就绪时）。
Map<String, JourneySlotDefModel> _fallbackSlotDefs() {
  return <String, JourneySlotDefModel>{
    for (final d in kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson))
      d.code: d,
  };
}

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
    category: JourneyChoiceCategory.passive,
  );
}
