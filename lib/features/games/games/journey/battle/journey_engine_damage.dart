part of 'journey_flame_game.dart';

/// 全局节拍伤害：默认 0.5s 一结算，取接触中伤害最高怪；贴脸怪群不叠乘。
/// 节拍间隔可由 journey_battle_params.damage.hurt_interval 调整。
mixin JourneyDamageTickMixin {
  double _hurtTimer = 0;

  /// 玩家侧护甲减伤上限（百分比口径钳死值）：无论护甲多高，单次接触伤害
  /// 至少保留原值的 40%。怪物侧另用 [kJourneyMonsterArmorCap]（72%）。
  static const double armorReductionCap = kJourneyPlayerArmorCap;

  /// 护甲值 → 减伤比例：递减曲线 armor/(armor+K)（K 缺省 80，后台
  /// armor_curve_k 可调；100 甲=55.6%），再钳到 [cap] 以内。玩家/怪物
  /// 双轨：玩家上限 60%、怪物上限 72%，使 50~200 甲档位仍可区分。
  static double armorReductionRatio(
    double armor, {
    double curveK = kJourneyArmorCurveK,
    double cap = kJourneyPlayerArmorCap,
  }) {
    if (armor <= 0) return 0;
    return (armor / (armor + curveK)).clamp(0.0, cap);
  }

  void updateDamageTick(JourneyFlameGame game, double dt) {
    // 扩展特效计时（金刚琢/阴阳二气瓶）：每帧推进，暂停时随引擎冻结
    game.updateTriggerWeapons(dt);
    _hurtTimer += dt;
    if (_hurtTimer < game.battleNum('damage', 'hurt_interval', 0.5)) return;
    _hurtTimer = 0;

    final player = game.player;
    var strongest = 0.0;
    JourneyMonsterComponent? strongestM;
    // 空间哈希（节点12）：接触判定只查玩家附近候选（一个格径覆盖最大怪半径）
    final candidates = game.spatialGrid
        .queryRange(player.position, JourneySpatialGrid.cellSize);
    for (final m in candidates) {
      if (m.isDead || m.isCharging) continue;
      final overlap = (m.position - player.position).length <=
          m.radius + JourneyPlayerComponent._radius;
      if (overlap && m._contactDamage > strongest) {
        strongest = m._contactDamage;
        strongestM = m;
      }
    }
    if (strongestM != null) {
      // 虚弱（金刚琢）：虚弱期接触伤害按系数削减（护甲折算前生效）
      if (strongestM.weakenTimer > 0) {
        strongest *= game.battleNum('damage', 'weaken_mult', 0.5);
      }
      var afterArmor =
          (strongest *
                  (1 -
                      armorReductionRatio(player.effectiveArmor,
                          curveK: game.armorCurveK,
                          cap: game.battleNum('damage', 'player_armor_cap',
                              kJourneyPlayerArmorCap))))
              .clamp(1.0, double.maxFinite);
      // 铜皮铁骨（bajie 特殊能力）：受击后窗口内按系数减伤
      if (game._bajieGuard > 0) {
        afterArmor *= game.battleNum('ability', 'bajie_guard_mult', 0.70);
      }
      player.takeDamage(afterArmor, attacker: strongestM, rawAmount: strongest);
      // 反伤荆棘（§6 特效法宝）：对造成伤害的怪反弹 thorns 比例护甲后
      // 伤害（params.thorns，直接 takeDamage，不计暴击）；荆棘绿环提示
      if (game.effectWeapons.contains('fanshang_thorns')) {
        strongestM.takeDamage(
          afterArmor *
              game.weaponParam('fanshang_thorns', 'thorns', 0.30) *
              game.passiveAmpFactor,
        );
        game.fxLayer.spawnRing(
          strongestM.position,
          strongestM.radius + 6,
          color: const Color(0xFF9AD5C3),
        );
        // GameAudio.instance.journeyTrigger();
      }
      // 妖王接触附带控制/毒（西游记扩展）：
      // 金光缚身（百眼魔君）定身；倒马毒桩（蝎子精）禁疗（时长可配）。
      // 反伤/反震先于此处结算，来源已被击杀时不再遗留控制效果。
      if (!strongestM.isDead) {
        for (final ability in strongestM.model.effectiveAbilityKeys) {
          switch (ability) {
            case 'spider_web':
              player.rootTimer = game.abilityParam(
                  strongestM.model.code, ability, 'web_root', 0.8);
              break;
            case 'poison_mist': // 倒马毒桩：禁疗 + 接触叠毒刺，满层真伤爆发
              player.healBlockTimer = game.abilityParam(
                  strongestM.model.code, ability, 'poison_block', 3.0);
              game.applyBossSkillEffect('sting',
                  power: game.abilityParam(
                      strongestM.model.code, ability, 'sting_add', 1),
                  abilityKey: ability,
                  owner: strongestM);
              game.spawnFloatText(
                player.position + Vector2(0, -36),
                '倒马毒桩·禁疗',
                const Color(0xFF8E2F3C),
              );
              break;
            case 'ice_seal': // 灵感大王：接触附带减速（冰封周期再补破甲）
              game.applyBossSkillEffect('slow',
                  power: game.abilityParam(
                      strongestM.model.code, ability, 'seal_slow', 0.3),
                  abilityKey: ability,
                  owner: strongestM);
              break;
          }
        }
      }
    }

    // 分离力：随机抽样两两推开（几何占位轻量做法，防完全叠点）
    final ms = game.monsters;
    if (ms.length >= 2) {
      final a = ms[game.rng.nextInt(ms.length)];
      final b = ms[game.rng.nextInt(ms.length)];
      if (!identical(a, b) && !a.isDead && !b.isDead) {
        final d = b.position - a.position;
        final minDist = a.radius + b.radius;
        final len = d.length;
        if (len > 0.01 && len < minDist) {
          final push = d.normalized() * (minDist - len) * 0.5;
          a.position -= push;
          b.position += push;
        }
      }
    }
  }
}

/// 妖王冲撞结算：突进命中角色时沿锁定方向撞开角色，并结算一次伤害。
/// 伤害倍率/击退距离走 journey_monster_params（逐怪可配，缺省 2.0/160），
/// 与 0.5s 接触节拍互斥，避免同一突进重复扣血。
extension JourneyBossCharge on JourneyFlameGame {
  bool resolveBossChargeHit(JourneyMonsterComponent boss) {
    final player = this.player;
    if (player.invulnTimer > 0) return false;
    final d = player.position - boss.position;
    if (d.length > boss.radius + JourneyPlayerComponent._radius) return false;

    var raw = boss._contactDamage *
        monsterParam(boss.model.code, 'charge_ratio', 2.0);
    // 虚弱（金刚琢）：与接触节拍同口径，护甲折算前按系数削减
    if (boss.weakenTimer > 0) {
      raw *= battleNum('damage', 'weaken_mult', 0.5);
    }
    var afterArmor = (raw *
            (1 -
                    JourneyDamageTickMixin.armorReductionRatio(
                    player.effectiveArmor,
                    curveK: armorCurveK,
                    cap: battleNum('damage', 'player_armor_cap',
                        kJourneyPlayerArmorCap))))
        .clamp(1.0, double.maxFinite);
    if (_bajieGuard > 0) {
      afterArmor *= battleNum('ability', 'bajie_guard_mult', 0.70);
    }
    player.takeDamage(afterArmor, attacker: boss, rawAmount: raw);
    // 反伤荆棘：冲撞同属接触伤害，照常对撞人妖王反弹
    if (effectWeapons.contains('fanshang_thorns')) {
      boss.takeDamage(
        afterArmor *
            weaponParam('fanshang_thorns', 'thorns', 0.30) *
            passiveAmpFactor,
      );
      fxLayer.spawnRing(
        boss.position,
        boss.radius + 6,
        color: const Color(0xFF9AD5C3),
      );
      // GameAudio.instance.journeyTrigger();
    }
    player.applyChargeKnock(
      boss._chargeDir,
      monsterParam(boss.model.code, 'charge_knockback', 160),
    );
    // 金翅迅影·风刃轨迹：冲撞命中后在身后留一段减速领域
    if (boss.model.hasAbility('roc_speed')) {
      bossSkillLayer.castField(
        boss.position - boss._chargeDir * 60,
          radius: monsterParam(boss.model.code, 'blade_range', 120),
          life: monsterParam(boss.model.code, 'blade_sec', 3),
          tick: monsterParam(boss.model.code, 'blade_tick', 0.6),
        effect: 'slow',
        power: monsterParam(boss.model.code, 'blade_slow', 0.35),
        color: const Color(0xFFD4A73F),
        owner: boss,
      );
    }
    spawnFloatText(
      player.position + Vector2(0, -36),
      '妖王冲撞！',
      const Color(0xFFD4593F),
    );
    return true;
  }
}
