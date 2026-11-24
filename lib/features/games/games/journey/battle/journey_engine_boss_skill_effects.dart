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
/// - seal：封印一个已选槽。
extension JourneyBossSkillEffects on JourneyFlameGame {
  void applyBossSkillEffect(
    String effect, {
    required double power,
    double rawDamage = 0,
    JourneyMonsterComponent? owner,
  }) {
    final p = player;
    if (p.invulnTimer > 0 && effect != 'root') return;
    final code = owner?.model.code ?? '';
    switch (effect) {
      case 'hit':
      case 'fire_hit':
        final dmg = rawDamage > 0
            ? rawDamage
            : (owner?.contactDamage ?? 0) *
                monsterParam(code, 'skill_hit_ratio', 0.6);
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
        );
        break;
      case 'true_hit':
        // 真伤爆发：绕甲、跳过最终减伤区，仅护盾在 takeDamage 内抵扣
        if (rawDamage > 0) p.takeDamage(rawDamage, trueDamage: true);
        break;
      case 'root':
        p.rootTimer = math.max(p.rootTimer, power);
        break;
      case 'blind':
        p.blindTimer = math.max(p.blindTimer, power);
        break;
      case 'slow':
        p.chillTimer = math.max(p.chillTimer,
            monsterParam(code, 'slow_sec', 3.0));
        p.chillFactor = (1 - power.clamp(0.0, 0.9));
        break;
      case 'heal_block':
        p.healBlockTimer = math.max(p.healBlockTimer, power);
        break;
      case 'armor_break':
        p.armorBreakTimer = math.max(p.armorBreakTimer,
            monsterParam(code, 'armor_break_sec', 4.0));
        p.armorBreakRatio = power.clamp(0.0, 0.9);
        break;
      case 'pull':
        if (owner == null) break;
        final dir = owner.position - p.position;
        if (dir.length > 1) {
          p.applySkillShift(dir, power,
              monsterParam(code, 'pull_shift_sec', 0.6));
        }
        break;
      case 'push':
        if (owner == null) break;
        final dir = p.position - owner.position;
        if (dir.length > 1) {
          p.applySkillShift(dir, power,
              monsterParam(code, 'push_shift_sec', 0.6));
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
          p.resetSkillDotTimer();
        }
        break;
      case 'sting':
        _applySting(code, power, owner);
        break;
      case 'drain':
        p.drainTimer = math.max(p.drainTimer,
            monsterParam(code, 'drain_sec', 4.0));
        break;
      case 'seal':
        final slots = weaponSlots.where((s) => s.level > 0).toList();
        if (slots.isNotEmpty) {
          p.sealedSlotCode = slots[rng.nextInt(slots.length)].code;
          p.sealTimer = math.max(p.sealTimer,
              monsterParam(code, 'seal_sec', 4.0));
        }
        break;
      case 'shield':
        // 妖王护罩：吸收量按接触伤害×层数，写回妖王实体
        if (owner != null) owner.grantWard(power);
        break;
    }
  }

  void _applySting(String code, double power, JourneyMonsterComponent? owner) {
    final p = player;
    p.stingStacks++;
    p.stingTimer = monsterParam(code, 'sting_window', 6.0);
    final need = monsterParam(code, 'sting_max', 3).round().clamp(1, 20);
    if (p.stingStacks < need) return;
    p.stingStacks = 0;
    // 满层真伤：接触伤害×爆发倍率，绕甲结算
    final burst = (owner?.contactDamage ?? 0) *
        monsterParam(code, 'sting_burst_ratio', 1.2);
    p.takeDamage(burst, trueDamage: true);
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
