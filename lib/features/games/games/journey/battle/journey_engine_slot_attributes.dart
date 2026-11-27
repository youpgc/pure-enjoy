part of 'journey_flame_game.dart';

/// 维度槽取值与属性结算：把「1级初始值 + 每级增量×(等级−1)」的
/// 统一口径与属性槽的习得/升级累加集中在一处，避免武器主逻辑堆积。
extension JourneySlotAttributes on JourneyWeaponMixin {
  /// 线性型维度槽在 [level] 级的数值：每级值本身就是 1 级回退，
  /// 配了 base_value 时由统一公式覆盖。供回元/护体/缚灵/灼烧/金刚/
  /// 反震/嗜血/背水/击退等按等级直接结算的槽复用。
  double linearSlotValue(String code, int level, double perLevelFallback) =>
      slotValueAtLevel(
        code,
        level,
        perLevelFallback,
        levelOneFallback: slotValue(code, perLevelFallback),
      );

  /// 属性维度累加单位：首级（习得）取 1 级初始值（未配回落每级值），
  /// 后续升级取每级增量。习得时等级=1、升级后等级>1，据此分流，
  /// 使累加式属性槽与按等级结算的特效槽共用「初始值+每级增量」口径。
  double attributeUnit(String code, double perLevelFallback) =>
      slotLevel(code) <= 1
          ? slotBaseValue(code, slotValue(code, perLevelFallback))
          : slotValue(code, perLevelFallback);

  /// 维度每级效果结算：属性维度即时应用到战斗字段；
  /// 特效维度击退/吸血/穿刺破甲在命中时读 slotLevel 结算，灼烧由驻留判定读取。
  void applySlotEffect(String code, int delta) {
    switch (code) {
      case 'radius': // 臂展：首级初始值/后续每级增量（后台可配）
        final arm = weaponArm;
        if (arm != null) {
          arm.outerRadius = math.min(
            arm.outerRadius + attributeUnit('radius', 14) * delta,
            math.min(arm.outerRadiusBase * 2.2, maxArmDiameter / 2),
          );
        }
        break;
      case 'speed': // 转速：首级初始值/后续每级增量（最终角速度钳 5 圈/秒）
        spinAmp += attributeUnit('speed', 0.10) * delta;
        break;
      case 'damage': // 伤害：首级初始值/后续每级增量
        damageAmp += attributeUnit('damage', 0.20) * delta;
        break;
      case 'magnet': // 磁吸：每级拾取范围
        player.pickupRange += attributeUnit('magnet', 40) * delta;
        break;
      case 'crit_rate': // 暴击率：首级初始值/后续每级增量（引擎钳上限可配）
        critRate = (critRate + attributeUnit('crit_rate', 0.025) * delta)
            .clamp(0.0, battleNum('damage', 'crit_rate_cap', 0.60));
        break;
      case 'crit_damage': // 暴击伤害：首级初始值/后续每级增量（上下限可配）
        final cMin = battleNum('damage', 'crit_dmg_min', 1.0);
        final cMax = battleNum('damage', 'crit_dmg_cap', 2.0);
        critDamage = (critDamage + attributeUnit('crit_damage', 0.06) * delta)
            .clamp(math.min(cMin, cMax), math.max(cMin, cMax));
        break;
      case 'armor': // 护甲：首级初始值/后续每级增量（减伤曲线钳制在伤害侧）
        player.armor += attributeUnit('armor', 3.0) * delta;
        break;
      case 'vitality': // 生机：生命上限百分比，与蟠桃同构按当前上限放大并登记比例
        final ratio = (attributeUnit('vitality', 0.05) * delta).clamp(
          0.0,
          battleNum('weapon', 'vitality_cap', 0.6),
        );
        player.hpBonusRatio += ratio;
        final hpUp = player.maxHp * ratio;
        player.maxHp += hpUp;
        player.hp += hpUp;
        controller.hud.maxHp.value = player.maxHp;
        controller.hud.hp.value = player.hp;
        break;
      case 'cloud': // 腾云：移速百分比，加法区（与筋斗云/升级卡同级）
        moveSpeedAmp += attributeUnit('cloud', 0.05) * delta;
        break;
      case 'ward': // 金刚不坏：受击最终减伤，在 takeDamage 侧按等级读取
      case 'reflect': // 金钟罩：盾抵反震倍率，在受击反震结算侧按等级读取
      case 'execute': // 处决：残血斩杀，在怪物/玩家受击结算侧按等级读取
      case 'recovery': // 回元：周期回血，在 tickNewSlots 侧按等级读取
      case 'shield': // 护体金光：周期护盾，在 tickNewSlots 侧按等级读取
      case 'slow': // 缚灵：范围减速，在 tickNewSlots 侧按等级读取
      case 'bloodlust': // 嗜血：攻速随缺失生命档位变化，逐帧并入环绕转速
      case 'desperation': // 背水一战：增伤随档位变化，并入伤害公式合计
      case 'qiankun': // 乾坤：命中获盾，在 _hitMonster 结算
      case 'poison': // 淬毒：命中上毒，在 _hitMonster 结算
      case 'knockback':
      case 'lifesteal':
      case 'pierce':
        break; // 命中/周期结算特效（见 _hitMonster / tickNewSlots）
      case 'burn':
        break; // 灼烧驻留特效（见 JourneyBurnMixin.tickBurnAura）
    }
  }
}
