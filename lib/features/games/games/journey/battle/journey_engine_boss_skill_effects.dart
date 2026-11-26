part of 'journey_flame_game.dart';

/// 妖王技能效果统一结算：技能层只传效果键与强度，数值与口径全部在此
/// 收敛，逐怪参数经 monsterParam 覆盖、缺省回落内置常量。
///
/// 效果键（effect）：
/// - hit：技能伤害，走护甲+减伤+护盾；
/// - fire_hit：火系技能伤害，额外吃辟火罩减免后再走常规结算；
/// - root / blind / slow / heal_block / armor_break：玩家负面态；
/// - pull / push：渐进位移（技能牵引通道，可被摇杆反向挣脱）；
/// - dot：持续伤害（领域灼烧/毒雾）；
/// - sting：毒刺叠层，满层真伤爆发；
/// - drain：套取增益（增伤削减）；
/// - seal：封印一个已选槽；
/// - shield_break：按比例撕开玩家护盾，盾破时走范围震荡钩子；
/// - imprison：金铙困形，限移 + 视野收窄（power=秒数）；
/// - silk_stack：情丝叠层，满层定身（power=本次叠层增量）；
/// - dispel：杨柳甘露，驱散玩家负面态（power=驱散种类数上限）；
/// - ghost_fog：玄阴黑雾，同帧施加致盲/减速/毒伤三负面（power=毒层数）。
/// 无敌帧（免死窗口）只免疫伤害类效果，控制与负面态照常施加。
const Set<String> _invulnImmuneEffects = <String>{
  'hit',
  'fire_hit',
  'true_hit',
  'dot',
  'sting',
  'shield_break',
};

extension JourneyBossSkillEffects on JourneyFlameGame {
  void applyBossSkillEffect(
    String effect, {
    required double power,
    double rawDamage = 0,
    JourneyMonsterComponent? owner,
    String? abilityKey,
    double? effectDuration,
  }) {
    final p = player;
    if (p.invulnTimer > 0 && _invulnImmuneEffects.contains(effect)) return;
    final code = owner?.model.code ?? '';
    // 效果常由弹道/预警/领域延迟命中，此时派发窗口已结束；能力键随技能实体
    // 携带过来，使能力专属参数在延迟结算时同样生效，无能力键则回落逐怪参数。
    double param(String key, double fallback) =>
        (abilityKey?.isNotEmpty ?? false)
            ? abilityParam(code, abilityKey!, key, fallback)
            : monsterParam(code, key, fallback);
    switch (effect) {
      case 'hit':
      case 'fire_hit':
        final dmg = rawDamage > 0
            ? rawDamage
            : (owner?.contactDamage ?? 0) *
                param('skill_hit_ratio', 0.6);
        if (dmg <= 0) return;
        // 火系技能先过辟火罩减免，再与常规技能共用护甲减伤与最终减伤区。
        final afterFire = effect == 'fire_hit' ? dmg * (1 - p.fireResist) : dmg;
        p.takeDamage(
          afterFire *
              (1 -
                  JourneyDamageTickMixin.armorReductionRatio(
                    p.effectiveArmor,
                    curveK: armorCurveK,
                    cap: battleNum('damage', 'player_armor_cap',
                        kJourneyPlayerArmorCap),
                  )),
          attacker: owner,
          rawAmount: dmg,
        );
        break;
      case 'true_hit':
        // 吞天巨口：唯技能真伤命中窗口触发斩杀，接触伤害不会误斩低血玩家。
        // 判定在扣血之前，清血条后 takeDamage 因 hp<=0 自然跳过。
        if (abilityKey == 'swallow_sky' &&
            tryExecutePlayer(attacker: owner, swallowHit: true)) {
          break;
        }
        // 真伤爆发：绕甲、跳过最终减伤区，仅护盾在 takeDamage 内抵扣
        if (rawDamage > 0) {
          p.takeDamage(rawDamage,
              trueDamage: true, attacker: owner, rawAmount: rawDamage);
        }
        break;
      case 'root':
        p.rootTimer = math.max(p.rootTimer, power);
        break;
      case 'blind':
        p.blindTimer = math.max(p.blindTimer, power);
        break;
      case 'slow':
        // 领域带来的减速按领域存活时长施加；其他通道回落 slow_sec。
        // 这样 prison_sec / frost_sec / mountain_sec 等逐能力时长才真正生效。
        p.chillTimer = math.max(p.chillTimer,
            effectDuration ?? param('slow_sec', 3.0));
        p.chillFactor = (1 - power.clamp(0.0, 0.9));
        break;
      case 'heal_block':
        p.healBlockTimer = math.max(p.healBlockTimer, power);
        break;
      case 'armor_break':
        p.armorBreakTimer = math.max(p.armorBreakTimer,
            param('armor_break_sec', 4.0));
        p.armorBreakRatio = power.clamp(0.0, 0.9);
        break;
      case 'pull':
        if (owner == null) break;
        final dir = owner.position - p.position;
        if (dir.length > 1) {
          p.applySkillShift(dir, power,
              param('pull_shift_sec', 0.6));
        }
        break;
      case 'push':
        if (owner == null) break;
        final dir = p.position - owner.position;
        if (dir.length > 1) {
          p.applySkillShift(dir, power,
              param('push_shift_sec', 0.6));
        }
        break;
      case 'dot':
        // 单来源 DOT 通道：伤害与时长必须整体替换。若各自取 max，
        // 多个领域叠加会拼出「A 的高伤害 × B 的长时长」这一不存在的组合。
        // 以总伤（每跳伤害×持续秒数）比大小，强者整体覆盖弱者。
        if (rawDamage * power >=
            p.skillDotPerTick * p.skillDotRemain) {
          p.skillDotPerTick = rawDamage;
          p.skillDotRemain = power;
          // 记录来源：盾抵 DOT 时照妖镜反震/破盾加成需命中该妖王
          p.skillDotOwner = owner;
          p.resetSkillDotTimer();
        }
        break;
      case 'sting':
        _applySting(code, power, owner, abilityKey);
        break;
      case 'drain':
        p.drainTimer = math.max(p.drainTimer,
            param('drain_sec', 4.0));
        break;
      case 'seal':
        final slots = weaponSlots.where((s) => s.level > 0).toList();
        if (slots.isNotEmpty) {
          p.sealedSlotCode = slots[rng.nextInt(slots.length)].code;
          p.sealTimer = math.max(p.sealTimer,
              param('seal_sec', 4.0));
        }
        break;
      case 'shield':
        // 妖王护罩：吸收量按接触伤害×层数，写回妖王实体
        if (owner != null) owner.grantWard(power);
        break;
      case 'shield_break':
        // 妖王破盾：撕开当前护盾的一部分；rawDamage 供盾破震荡取基准
        reducePlayerShield(
          p.shield * power.clamp(0.0, 1.0),
          rawDamage: rawDamage,
          attacker: owner,
        );
        break;
      case 'imprison':
        // 金铙困形：限移由 rootTimer 承担，视野收窄读 imprisonedTimer。
        // 暗角渐隐的分母保留最长一次困形时长，弱困形刷新不得缩短它。
        p.rootTimer = math.max(p.rootTimer, power);
        p.imprisonedTimer = math.max(p.imprisonedTimer, power);
        p.imprisonedSpan = math.max(math.max(p.imprisonedSpan, power), 0.1);
        break;
      case 'silk_stack':
        // 情丝叠层：满层触发一次定身并清空层数，与毒刺真伤通道互不干扰
        p.silkStacks += power.round().clamp(1, 10);
        p.silkTimer = param('silk_window', 6.0);
        final silkNeed = param('silk_max', 4).round().clamp(1, 20);
        if (p.silkStacks >= silkNeed) {
          p.silkStacks = 0;
          p.rootTimer = math.max(
              p.rootTimer, param('silk_root', 1.6));
          spawnFloatText(p.position + Vector2(0, -36), '情丝缚魂',
              const Color(0xFFD4709A));
        }
        break;
      case 'dispel':
        // 杨柳甘露：一次驱散多类负面，按 power 限定最多清除的种类数
        var cleaned = 0;
        final cap = power.round().clamp(1, 8);
        if (p.sealTimer > 0 && cleaned < cap) {
          p.sealTimer = 0;
          p.sealedSlotCode = '';
          cleaned++;
        }
        if (p.stingStacks > 0 && cleaned < cap) {
          p.stingStacks = 0;
          p.stingTimer = 0;
          cleaned++;
        }
        if (p.silkStacks > 0 && cleaned < cap) {
          p.silkStacks = 0;
          p.silkTimer = 0;
          cleaned++;
        }
        if (p.skillDotRemain > 0 && cleaned < cap) {
          p.skillDotRemain = 0;
          p.skillDotPerTick = 0;
          p.skillDotOwner = null;
          p.resetSkillDotTimer();
          cleaned++;
        }
        if (p.imprisonedTimer > 0 && cleaned < cap) {
          p.imprisonedTimer = 0;
          p.imprisonedSpan = 0;
          p.rootTimer = 0;
          cleaned++;
        }
        if (p.blindTimer > 0 && cleaned < cap) {
          p.blindTimer = 0;
          cleaned++;
        }
        if (p.chillTimer > 0 && cleaned < cap) {
          p.chillTimer = 0;
          p.chillFactor = 1;
          cleaned++;
        }
        // 自身回血：杨柳甘露是辅助型，驱散后按接触伤害回血
        if (owner != null && !owner.isDead) {
          owner.hp = math.min(owner.maxHp,
              owner.hp + owner.contactDamage * param('dew_heal', 2.0));
        }
        break;
      case 'ghost_fog':
        // 玄阴黑雾：致盲 + 减速 + 毒伤叠层同帧施加，区别黑风群的吸拉领域
        p.blindTimer = math.max(p.blindTimer, param('fog_blind', 2.5));
        p.chillTimer = math.max(p.chillTimer, param('fog_slow_sec', 3.0));
        p.chillFactor = 1 - param('fog_slow', 0.35).clamp(0.0, 0.9);
        _applySting(code, power, owner, abilityKey);
        break;
    }
  }

  void _applySting(
    String code,
    double power,
    JourneyMonsterComponent? owner,
    String? abilityKey,
  ) {
    final p = player;
    // 免死窗口内不叠毒层：毒伤爆发是真伤通道，无敌帧只让它跳过伤害，
    // 不应在窗口里悄悄攒层，出窗口立刻炸一笔。
    if (p.invulnTimer > 0) return;
    // 叠层数由能力专属的 sting_add / fog_ratio 决定，固定 +1 会让后台配置失效。
    p.stingStacks += power.round().clamp(1, 10);
    double param(String key, double fallback) =>
        (abilityKey?.isNotEmpty ?? false)
            ? abilityParam(code, abilityKey!, key, fallback)
            : monsterParam(code, key, fallback);
    p.stingTimer = math.max(p.stingTimer, param('sting_window', 6.0));
    final need = param('sting_max', 3).round().clamp(1, 20);
    if (p.stingStacks < need) return;
    p.stingStacks = 0;
    // 满层真伤：接触伤害×爆发倍率，绕甲结算
    final burst = (owner?.contactDamage ?? 0) *
        param('sting_burst_ratio', 1.2);
    p.takeDamage(burst, trueDamage: true, attacker: owner, rawAmount: burst);
    spawnFloatText(p.position + Vector2(0, -36), '倒马毒桩·爆发',
        const Color(0xFFB07CD4));
  }
}

/// 致盲/套取对玩家伤害的削减：在伤害基数上乘算，与增伤加法区隔离，
/// 使妖王负面态不被增伤上限/暴击等乘区吞掉。
extension JourneyBossDebuffDamage on JourneyFlameGame {
  double get bossSkillDamageFactor {
    var f = 1.0;
    if (player.blindTimer > 0) {
      f *= 1 - battleNum('boss', 'blind_damage', 0.35).clamp(0.0, 1.0);
    }
    if (player.drainTimer > 0) {
      f *= 1 - battleNum('boss', 'drain_damage', 0.25).clamp(0.0, 1.0);
    }
    return f;
  }
}
