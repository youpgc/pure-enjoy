part of 'journey_flame_game.dart';

/// 按引擎口径算某维度在 [level] 级的展示数值：配了 1 级初始值则按
/// 初始值 + 每级增量×(等级−1)；未配时基准类（穿刺/吸血/处决/乾坤/淬毒）
/// 1 级即基准值、其余按等级×每级值，保持原口径零回归。
double _slotDisplayValue(
  String code,
  int level,
  double perLevel, ({
  String brief,
  _SlotUnit unit,
  double base,
  double fallback,
  double cap,
}) rule, {
  double baseValue = 0,
}) {
  final cached = JourneyConfigService.instance.cached;
  // 基准与上限均与结算同源：基准读各槽基数，上限读后台可配的
  // 对应 cap，避免调参后卡面数值与实际不符
  final base = switch (code) {
    'pierce' =>
      cached?.battleNum(
            'weapon',
            'pierce_base',
            kJourneyPierceBaseRatio,
          ) ??
          kJourneyPierceBaseRatio,
    'lifesteal' =>
      cached?.battleNum(
            'weapon',
            'lifesteal_base',
            kJourneyLifestealBaseRatio,
          ) ??
          kJourneyLifestealBaseRatio,
    'execute' => (cached?.battleNum(
              'execute',
              'normal_floor',
              kJourneyExecuteNormalFloorRatio,
            ) ??
            kJourneyExecuteNormalFloorRatio)
        .clamp(0.0, 1.0),
    'qiankun' =>
      cached?.battleNum(
            'weapon',
            'qiankun_base',
            kJourneyQiankunShieldBase,
          ) ??
          kJourneyQiankunShieldBase,
    'poison' =>
      cached?.battleNum(
            'weapon',
            'poison_base',
            kJourneyPoisonRatioBase,
          ) ??
          kJourneyPoisonRatioBase,
    _ => rule.base,
  };
  final step = perLevel > 0 ? perLevel : rule.fallback;
  final isBaseType = code == 'pierce' ||
      code == 'lifesteal' ||
      code == 'execute' ||
      code == 'qiankun' ||
      code == 'poison';
  final raw = baseValue > 0
      ? baseValue + step * (level - 1)
      : isBaseType
          ? base + step * (level - 1)
          : base + step * level;
  final cap = switch (code) {
    'pierce' =>
      cached?.battleNum(
            'weapon', 'pierce_cap', kJourneyPierceRatioCap) ??
          kJourneyPierceRatioCap,
    'lifesteal' =>
      cached?.battleNum(
            'weapon', 'lifesteal_cap', kJourneyLifestealRatioCap) ??
          kJourneyLifestealRatioCap,
    'crit_rate' =>
      cached?.battleNum('damage', 'crit_rate_cap', 0.60) ?? 0.60,
    'crit_damage' =>
      cached?.battleNum('damage', 'crit_dmg_cap', 2.0) ?? 2.0,
    'vitality' =>
      cached?.battleNum('weapon', 'vitality_cap', 0.6) ?? 0.6,
    'ward' => cached?.battleNum('weapon', 'ward_cap', 0.5) ?? 0.5,
    'recovery' =>
      cached?.battleNum('weapon', 'recovery_cap', 0.5) ?? 0.5,
    'slow' => cached?.battleNum('weapon', 'slow_cap', 0.7) ?? 0.7,
    'reflect' => math.max(
        0.0,
        cached?.weaponParam('zhaoyao_jing', 'reflect_cap', 3.0) ?? 3.0),
    'execute' => math.max(
        base,
        (cached?.battleNum(
                'execute', 'normal_cap', kJourneyExecuteNormalCapRatio) ??
            kJourneyExecuteNormalCapRatio)
            .clamp(0.0, 1.0)),
    _ => rule.cap,
  };
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
String journeySlotValueText(
  String code,
  int level,
  double perLevel, {
  double baseValue = 0,
}) {
  final rule = _slotDisplayRule(code);
  if (rule.brief.isEmpty) return '';
  return '${rule.brief} ${_formatSlotValue(
    _slotDisplayValue(code, level, perLevel, rule, baseValue: baseValue),
    rule.unit,
  )}';
}

/// 顿悟卡描述：简介 + 当前值→下一级值动态对比，让升级收益一目了然；
/// 无匹配规则时回落后台每级效果文案。后台每级效果文案用于习得卡，
/// 不覆盖升级卡的数值提升展示。
String _upgradeDesc(JourneySlotDefModel def, int currentLevel) {
  final rule = _slotDisplayRule(def.code);
  if (rule.brief.isEmpty) return def.effectPerLevel;
  final before = _formatSlotValue(
      _slotDisplayValue(def.code, currentLevel, def.valuePerLevel, rule,
          baseValue: def.baseValue), rule.unit);
  final after = _formatSlotValue(
      _slotDisplayValue(def.code, currentLevel + 1, def.valuePerLevel, rule,
          baseValue: def.baseValue), rule.unit);
  return '${rule.brief} $before → $after';
}

/// 三选一法宝卡描述：后台法宝描述优先，空时回落内置数值模板。
/// 数值模板仍从法宝参数读取，保证后台未写描述时展示与结算同源。
String _weaponChoiceDesc(
  JourneyFlameGame game,
  String code,
  String fallback,
) {
  final remote = game.config?.weaponOf(code)?.desc.trim() ?? '';
  return remote.isNotEmpty ? remote : fallback;
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
      // 统一解锁规则：有规则且未解锁的后期维度不进习得池；无规则不设门控。
      if (hasEmptySlot &&
          !JourneyProgressService.instance.needsUnlock('slot', def.code)) {
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
      // 统一规则优先；规则未配置时保留原「功德被动」硬编码门控。
      if (JourneyProgressService.instance.needsWeaponUnlock(p.key) ||
          (kJourneyMeritPassives.contains(p.key) &&
              !unlocked.contains(p.key))) {
        continue;
      }
      pool.add(_passiveGrantChoice(
        p.key,
        p.value,
        _weaponChoiceDesc(
          game,
          p.key,
          journeyPassiveEffectDesc(p.key, game.weaponParam),
        ),
      ));
    }
  }

  // 特效触发法宝卡（§6）：入池=已解锁且未持有（持有后不重复出现）
  for (final e in kJourneyEffectWeaponNames.entries) {
    final unlocked = JourneyProgressService.instance.state.unlockedWeapons;
    if (game.effectWeapons.contains(e.key) ||
        !unlocked.contains(e.key) ||
        JourneyProgressService.instance.needsWeaponUnlock(e.key)) {
      continue;
    }
    pool.add(JourneyUpgradeChoice(
      JourneyUpgradeKind.effectGrant,
      code: e.key,
      title: '触发·${e.value}',
      desc: _weaponChoiceDesc(
        game,
        e.key,
        journeyEffectWeaponDesc(e.key, game.weaponParam),
      ),
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
