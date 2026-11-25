part of 'journey_flame_game.dart';

/// 盾破震荡的防呆边界：伤害倍率与半径的保护性上限，避免后台误配清场。
const double kJourneyBurstRatioCap = 3.0;
const double kJourneyBurstRadiusCap = 400.0;

/// 护盾攻防统一结算：照妖镜的盾抵反震、震妖钟的盾破震荡、妖王破盾。
/// 反震基准取减伤前原值（护甲/最终减伤/护盾抵扣之前），不吃目标护甲；
/// 所有数值经 weaponParam / monsterParam 读取，缺行回落内置兜底。
extension JourneyShieldCombat on JourneyFlameGame {
  /// 妖王破盾能力下，角色带盾时其伤害的额外加成。
  double shieldBreakBonus(JourneyMonsterComponent? attacker) {
    if (attacker == null || attacker.isDead || player.shield <= 0) return 0;
    if (attacker.model.abilityKey != 'shield_break') return 0;
    return monsterParam(attacker.model.code, 'shield_damage_bonus', 0.25)
        .clamp(0.0, 1.0);
  }

  /// 妖王破盾能力下，玩家反震的衰减系数（缺省减半）。
  double shieldReflectFactor(JourneyMonsterComponent attacker) =>
      attacker.model.abilityKey == 'shield_break'
          ? monsterParam(attacker.model.code, 'reflect_mult', 0.5)
              .clamp(0.0, 1.0)
          : 1.0;

  /// 护盾抵扣伤害时按减伤前原值反震来源妖物。
  /// 反震倍率 = 金钟罩维度基础倍率（每级增量×等级）+ 照妖镜额外倍率，整体钳上限；
  /// 两载体任一持有即可触发，反震不吃护甲（armorIgnore=1），护罩仍按怪物规则抵扣。
  void resolveShieldReflect(JourneyMonsterComponent attacker, double raw) {
    if (raw <= 0 || attacker.isDead) return;
    final hasMirror = passiveSlotCodes.contains('zhaoyao_jing');
    final reflectLv = slotLevel('reflect');
    if (!hasMirror && reflectLv <= 0) return;
    final cap = math.max(0.0, weaponParam('zhaoyao_jing', 'reflect_cap', 3.0));
    final base = reflectLv > 0 ? slotValue('reflect', 0.15) * reflectLv : 0.0;
    final extra =
        hasMirror ? weaponParam('zhaoyao_jing', 'reflect_ratio', 1.0) : 0.0;
    final ratio = (base + extra).clamp(0.0, cap);
    final damage = raw * ratio * shieldReflectFactor(attacker);
    if (damage <= 0) return;
    attacker.takeDamage(damage, armorIgnore: 1);
    fxLayer.spawnRing(
      attacker.position,
      attacker.radius + 8,
      color: const Color(0xFFF0D9A0),
    );
    spawnFloatText(
      attacker.position + Vector2(0, -attacker.radius - 14),
      hasMirror ? '照妖·反震' : '金钟·反震',
      const Color(0xFFE8C470),
    );
  }

  /// 护盾归零时的范围震荡：伤害基准取击破那一击的减伤前原值。
  /// 遍历副本，避免击杀后怪物列表变更打断本次结算。
  /// 统一输出护盾破碎提示，无论盾破来自受击还是妖王撕盾。
  void resolveShieldBurst(double raw) {
    spawnFloatText(
      player.position + Vector2(0, -36),
      '护盾破碎',
      const Color(0xFFD4593F),
    );
    if (!passiveSlotCodes.contains('zhenyao_zhong') || raw <= 0) return;
    final radius = weaponParam('zhenyao_zhong', 'burst_radius', 140)
        .clamp(0.0, kJourneyBurstRadiusCap);
    if (radius <= 0) return;
    final damage = raw *
        weaponParam('zhenyao_zhong', 'burst_ratio', 0.6)
            .clamp(0.0, kJourneyBurstRatioCap);
    if (damage <= 0) return;
    final armorIgnore =
        weaponParam('zhenyao_zhong', 'burst_armor_ignore', 0) > 0 ? 1.0 : 0.0;
    for (final m in monsters.toList()) {
      if (m.isDead) continue;
      if ((m.position - player.position).length > radius + m.radius) continue;
      m.takeDamage(damage, armorIgnore: armorIgnore);
    }
    fxLayer.spawnRing(
      player.position,
      radius,
      color: const Color(0xFFF3E3B3),
    );
    spawnFloatText(
      player.position + Vector2(0, -44),
      '震妖钟·盾破',
      const Color(0xFFE8C470),
    );
  }

  /// 妖王破盾效果：按当前护盾比例撕开护盾；盾破时走统一震荡钩子。
  /// 撕盾属于妖王伤害，携带处决能力且角色残血时先触发处决再结算护盾。
  void reducePlayerShield(double points,
      {double rawDamage = 0, JourneyMonsterComponent? attacker}) {
    if (points <= 0 || player.shield <= 0) return;
    if (tryExecutePlayer(attacker: attacker)) return;
    player.shield = math.max(0.0, player.shield - points);
    controller.hud.shield.value = player.shield;
    if (player.shield <= 0) {
      resolveShieldBurst(rawDamage);
    }
  }
}
