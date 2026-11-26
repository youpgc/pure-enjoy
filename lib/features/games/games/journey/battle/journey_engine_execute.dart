part of 'journey_flame_game.dart';

/// 处决的防呆边界：妖王血线钳在最大生命的 1%~3%，普通怪钳在 1%~15%，
/// 防止后台误配成满血即斩或跳过妖王阶段能力与多场推进。
const double kJourneyExecuteBossFloorRatio = 0.01;
const double kJourneyExecuteBossCapRatio = 0.03;
const double kJourneyExecuteNormalFloorRatio = 0.01;
const double kJourneyExecuteNormalCapRatio = 0.15;

/// 处决攻防统一结算：玩家维度槽斩妖物、妖王专属能力斩玩家。
/// 所有阈值经 battleNum / monsterParam / slotValue 读取，缺行回落内置兜底。
/// 处决只把血条清零，后续保命（免死/无敌帧/还魂）与击杀奖励走各自既有链路。
extension JourneyExecuteCombat on JourneyFlameGame {
  /// 妖王是否携带处决能力（execute）或吞天斩杀（swallow_sky）。
  bool _hasPlayerExecuteAbility(JourneyMonsterComponent? attacker) =>
      attacker != null &&
      !attacker.isDead &&
      (attacker.model.hasAbility('execute') ||
          attacker.model.hasAbility('swallow_sky'));

  /// 妖王处决玩家：仅携带该能力的妖王之伤害触发，判定在扣血与护盾抵扣之前。
  /// 命中直接清血条（穿透护盾）；无敌帧期间不触发，免死/还魂由死亡链处理。
  /// [swallowHit] 仅由吞天巨口的真伤技能命中传入：接触伤害/其他来源即使
  /// 来自该妖王也不触发吞天斩杀，避免低血时被任意伤害瞬杀。
  bool tryExecutePlayer({
    required JourneyMonsterComponent? attacker,
    bool swallowHit = false,
  }) {
    if (!_hasPlayerExecuteAbility(attacker) || player.hp <= 0) return false;
    if (player.invulnTimer > 0) return false;
    final code = attacker!.model.code;
    // 吞天巨口走独立阈值，与原处决互不覆盖；两能力并存时取更高的斩杀线。
    // 吞天阈值只在技能命中窗口生效，execute 维持任意伤害触发的既有口径。
    final executeRatio = attacker.model.hasAbility('execute')
        ? abilityParam(code, 'execute', 'execute_hp_ratio', 0.10)
        : 0.0;
    final swallowRatio =
        (swallowHit && attacker.model.hasAbility('swallow_sky'))
            ? abilityParam(code, 'swallow_sky', 'sky_execute_ratio', 0.12)
            : 0.0;
    final ratio =
        math.max(executeRatio, swallowRatio).clamp(0.0, 1.0);
    if (ratio <= 0 || player.hp >= player.maxHp * ratio) return false;
    player.hp = 0;
    controller.hud.hp.value = 0;
    controller.hud.hitPulse.value++;
    // 飘字按本次真正触发的斩杀通道显示，双能力并存不误报吞天。
    spawnFloatText(
      player.position + Vector2(0, -36),
      swallowRatio >= executeRatio ? '吞天·斩杀' : '摄魂·处决',
      const Color(0xFFC0392B),
    );
    onPlayerHpChanged();
    return true;
  }

  /// 普通怪处决阈值：下限 + 每级增量×(等级−1)，钳在 [下限, 上限]。
  /// 每级增量取维度槽 value_per_level，上限来自战斗参数，展示与结算同源。
  double executeNormalRatio(int level) {
    final floor = battleNum(
            'execute', 'normal_floor', kJourneyExecuteNormalFloorRatio)
        .clamp(0.0, 1.0);
    final cap =
        battleNum('execute', 'normal_cap', kJourneyExecuteNormalCapRatio)
            .clamp(0.0, 1.0);
    final step = slotValue('execute', 0.0175);
    return (floor + step * (level - 1)).clamp(0.0, math.max(floor, cap));
  }

  /// 妖王处决血线：绝对血线按等级成长，再钳在最大生命的 1%~3%。
  /// 不乘妖王等级项，避免高等级血线放大到数十万。
  double executeBossHp(int level, double maxHp) {
    final base = battleNum('execute', 'boss_base', 5000);
    final step = battleNum('execute', 'boss_step', 5625);
    final floorRatio = battleNum(
            'execute', 'boss_floor_ratio', kJourneyExecuteBossFloorRatio)
        .clamp(0.0, 1.0);
    final capRatio =
        battleNum('execute', 'boss_cap_ratio', kJourneyExecuteBossCapRatio)
            .clamp(0.0, 1.0);
    final lo = maxHp * floorRatio;
    final hi = math.max(lo, maxHp * capRatio);
    return math.max(lo, math.min(base + step * (level - 1), hi));
  }

  /// 怪物受击后判定：血量落入阈值即清血条，复用现有击杀奖励链。
  /// 假身（变化术/分瓣梅花）不参与处决，避免提前清空其血条。
  bool tryExecuteMonster(JourneyMonsterComponent monster) {
    final level = slotLevel('execute');
    if (level <= 0 || monster.isDecoy || monster.hp <= 0) return false;
    final line = monster.model.isBoss
        ? executeBossHp(level, monster.maxHp)
        : monster.maxHp * executeNormalRatio(level);
    if (line <= 0 || monster.hp > line) return false;
    monster.hp = 0;
    spawnFloatText(
      monster.position + Vector2(0, -monster.radius - 14),
      '处决',
      const Color(0xFFE8C470),
    );
    return true;
  }
}
