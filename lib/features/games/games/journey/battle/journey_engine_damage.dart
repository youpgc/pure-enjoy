part of 'journey_flame_game.dart';

/// 全局节拍伤害：0.5s 一结算，取接触中伤害最高怪；贴脸怪群不叠乘。
/// （口径详见概念文档 §7；节拍间隔后台可调，客户端先取常量。）
mixin JourneyDamageTickMixin {
  double _hurtTimer = 0;
  static const double hurtInterval = 0.5;

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
    if (_hurtTimer < hurtInterval) return;
    _hurtTimer = 0;

    final player = game.player;
    var strongest = 0.0;
    JourneyMonsterComponent? strongestM;
    // 空间哈希（节点12）：接触判定只查玩家附近候选（一个格径覆盖最大怪半径）
    final candidates = game.spatialGrid
        .queryRange(player.position, JourneySpatialGrid.cellSize);
    for (final m in candidates) {
      if (m.isDead) continue;
      final overlap = (m.position - player.position).length <=
          m.radius + JourneyPlayerComponent._radius;
      if (overlap && m._contactDamage > strongest) {
        strongest = m._contactDamage;
        strongestM = m;
      }
    }
    if (strongestM != null) {
      // 虚弱（金刚琢）：虚弱期接触伤害减半（在护甲折算前生效）
      if (strongestM.weakenTimer > 0) {
        strongest *= 0.5;
      }
      var afterArmor =
          (strongest *
                  (1 -
                      armorReductionRatio(player.armor,
                          curveK: game.armorCurveK)))
              .clamp(1.0, double.maxFinite);
      // 铜皮铁骨（bajie 特殊能力）：受击后窗口内额外减伤 30%
      if (game._bajieGuard > 0) {
        afterArmor *= 0.70;
      }
      player.takeDamage(afterArmor);
      // 反伤荆棘（§6 特效法宝）：对造成伤害的怪反弹 thorns 比例护甲后
      // 伤害（params.thorns，直接 takeDamage，不计暴击）
      if (game.effectWeapons.contains('fanshang_thorns')) {
        strongestM.takeDamage(
          afterArmor * game.weaponParam('fanshang_thorns', 'thorns', 0.30),
        );
      }
      // 妖王接触附带控制/毒（西游记扩展）：
      // 金光缚身（百眼魔君）定身；倒马毒桩（蝎子精）禁疗（时长可配）
      switch (strongestM.model.abilityKey) {
        case 'spider_web':
          player.rootTimer = game.monsterParam(
              strongestM.model.code, 'web_root', 0.8);
          break;
        case 'poison_mist':
          player.healBlockTimer = game.monsterParam(
              strongestM.model.code, 'poison_block', 3.0);
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '倒马毒桩·禁疗',
            const Color(0xFF8E2F3C),
          );
          break;
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
