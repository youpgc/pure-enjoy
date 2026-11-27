part of 'journey_flame_game.dart';

/// 周身环绕武器（电风扇模型）：
/// 环带从角色容器延伸到外环，**初始武器（角色特性法宝，1 件）**随环绕
/// 速度旋转收割——扇叶扫到哪里哪里受击。6 主动槽=维度槽（非多件武器）：
/// 初始武器占 1 特效槽，空槽可习得新维度（属性/特效），各维度带等级
/// 上限（运营配置）。
class JourneyWeaponArm {
  JourneyWeaponArm({
    required this.speedBase,
    required this.innerRadius,
    required this.outerRadiusBase,
    required this.damage,
    required this.bladeWidth,
  }) : outerRadius = outerRadiusBase;

  final double speedBase; // 角速度 rad/s
  final double innerRadius; // 环带内缘（角色容器边缘）
  final double outerRadiusBase; // 臂长基准（外环半径）
  double damage; // 单次受击基准伤害（法宝分级随角色等级刷新）
  final double bladeWidth; // 扇叶判定宽度 px

  double outerRadius; // 当前外环半径（臂展槽/定风丹成长）

  double angle = 0; // 旋转相位（渲染与判定的单一真源）

  /// 判定臂半宽：臂长拉长后臂宽同比放大（钳 1~1.6 倍），伤害面同步增长。
  double get halfWidth {
    final grow = (outerRadius / outerRadiusBase).clamp(1.0, 1.6);
    return bladeWidth * 0.5 * grow;
  }

  /// 受击环带可视化宽度（外环-内环）。
  double get bandWidth => outerRadius - innerRadius;
}

/// 武器维度宿主接口：主类 implements，mixin 据此访问宿主成员。
abstract interface class JourneyWeaponHost {
  JourneyWeaponArm? get weaponArm;
  List<JourneyWeaponSlot> get weaponSlots;
  JourneyBattleController get controller;
  double get spinAmp;
  set spinAmp(double value);
  double get damageAmp;
  set damageAmp(double value);
  double get moveSpeedAmp;
  set moveSpeedAmp(double value);
  double get critRate;
  set critRate(double value);
  double get critDamage;
  set critDamage(double value);
  double get maxArmDiameter;
  double slotValue(String code, double fallback);
  double battleNum(String group, String key, double fallback);
  JourneyPlayerComponent get player;
}

/// 武器系统：
/// - 判定=扇形扫掠：怪与玩家连线角落在扇叶角 ± atan(半宽/距离) 内，
///   且怪距落在 [内环-怪半径, 外环+怪半径] → 扇叶扫到哪里哪里受击；
/// - 每个扇叶各自持有命中豁免（weapon.hit_cd，缺省 0.3 秒），
///   扇叶之间互不共享，同一扇叶在豁免窗口内不再结算伤害与命中效果；
/// - 命中结算维度特效：穿刺（破甲：按比例无视目标护甲）/击退（推开）/
///   吸血（回复）；
/// - 灼烧不走命中：三路来源统一由臂展圆内驻留满阈值点燃（见 tickBurnAura）；
/// - 维度槽操作（习得/升级/每级效果结算）。
mixin JourneyWeaponMixin on FlameGame implements JourneyWeaponHost {
  /// 某维度槽当前等级（未习得=0）。
  int slotLevel(String code) {
    // 装天封印：被封槽在有效期内等级按 0 计，槽定义与 UI 均不改
    if (player.sealedSlotCode == code && player.sealTimer > 0) return 0;
    for (final s in weaponSlots) {
      if (s.code == code) return s.level;
    }
    return 0;
  }

  /// 吸血比例（lv<=0 返回 0）：1 级取 lifesteal_base，每级增量取维度槽
  /// value_per_level（远端可覆盖），钳 lifesteal_cap。环绕与并行单位共用，
  /// 保证同名参数在两条命中链上口径一致。
  double lifestealRatioOf(int lv) {
    if (lv <= 0) return 0;
    return (battleNum('weapon', 'lifesteal_base', kJourneyLifestealBaseRatio) +
            slotValue('lifesteal', kJourneyLifestealRatioPerLv) * (lv - 1))
        .clamp(
          0.0,
          battleNum('weapon', 'lifesteal_cap', kJourneyLifestealRatioCap),
        );
  }

  /// 单次吸血回血点：命中伤害×比例，低伤命中保底 lifesteal_floor。
  double lifestealHealOf(double dmg, int lv) {
    if (lv <= 0 || dmg <= 0) return 0;
    return math.max(
      dmg * lifestealRatioOf(lv),
      battleNum('weapon', 'lifesteal_floor', kJourneyLifestealHealFloor),
    );
  }

  /// 法宝/被动槽变更通知 HUD：槽栏由 ValueListenableBuilder 监听
  /// slotsRevision。onLoad 建立初始环绕时处于 GameWidget 构建期，同步写
  /// ValueNotifier 会令监听 widget 在 build 中被标脏（markNeedsBuild during
  /// build）；构建期统一推迟到帧尾，其余时刻即时写。
  void bumpSlotsRevision() {
    void apply() => controller.hud.slotsRevision.value++;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// 习得维度（占 1 空槽，Lv1）并应用每级效果。
  void learnSlot(String code) {
    if (weaponSlots.length >= 6) return;
    if (slotLevel(code) > 0) return;
    final slot = JourneyWeaponSlot(code, 1);
    weaponSlots.add(slot);
    controller.activeSlots.add(slot);
    applySlotEffect(code, 1);
    bumpSlotsRevision();
  }

  /// 维度升级（+delta 级）并应用每级效果（上限由配置驱动，调用方判定）。
  void upgradeSlot(String code, {int delta = 1}) {
    for (final s in weaponSlots) {
      if (s.code == code) {
        s.level += delta;
        applySlotEffect(code, delta);
        bumpSlotsRevision();
        return;
      }
    }
  }

  /// 维度每级效果结算：属性维度即时应用到战斗字段；
  /// 特效维度击退/吸血/穿刺破甲在命中时读 slotLevel 结算，灼烧由驻留判定读取。
  void applySlotEffect(String code, int delta) {
    switch (code) {
      case 'radius': // 臂展：每级 +（value_per_level 后台可配）
        final arm = weaponArm;
        if (arm != null) {
          arm.outerRadius = math.min(
            arm.outerRadius + slotValue('radius', 14) * delta,
            math.min(arm.outerRadiusBase * 2.2, maxArmDiameter / 2),
          );
        }
        break;
      case 'speed': // 转速：每级 +（value_per_level；最终角速度钳 5 圈/秒）
        spinAmp += slotValue('speed', 0.10) * delta;
        break;
      case 'damage': // 伤害：每级 +（value_per_level）
        damageAmp += slotValue('damage', 0.20) * delta;
        break;
      case 'magnet': // 磁吸：每级拾取范围 +（value_per_level）
        player.pickupRange += slotValue('magnet', 40) * delta;
        break;
      case 'crit_rate': // 暴击率：每级 +（value_per_level；引擎钳上限可配）
        critRate = (critRate + slotValue('crit_rate', 0.025) * delta)
            .clamp(0.0, battleNum('damage', 'crit_rate_cap', 0.60));
        break;
      case 'crit_damage': // 暴击伤害：每级 +（value_per_level；上下限可配）
        final cMin = battleNum('damage', 'crit_dmg_min', 1.0);
        final cMax = battleNum('damage', 'crit_dmg_cap', 2.0);
        critDamage = (critDamage + slotValue('crit_damage', 0.06) * delta)
            .clamp(math.min(cMin, cMax), math.max(cMin, cMax));
        break;
      case 'armor': // 护甲：每级 +（value_per_level；减伤曲线钳制在伤害侧）
        player.armor += slotValue('armor', 3.0) * delta;
        break;
      case 'vitality': // 生机：生命上限百分比，与蟠桃同构按当前上限放大并登记比例
        final ratio = (slotValue('vitality', 0.05) * delta).clamp(
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
        moveSpeedAmp += slotValue('cloud', 0.05) * delta;
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

  void updateWeapons(JourneyFlameGame game, double dt) {
    // 臂展驻留灼烧：三路灼烧由整臂展圆内驻留满阈值点燃，不随命中附加。
    // 对全部怪判定（含离屏怪以清零驻留），灼烧伤害仍由怪物自身 tickBurn 结算。
    final dwellSec = game.battleNum('weapon', 'burn_dwell_sec', 1.0);
    for (final m in game.monsters) {
      m.tickBurnAura(game, dt, dwellSec: dwellSec, monsterRadius: m.radius);
    }
    final arm = game.weaponArm;
    if (arm == null) return;
    final center = game.player.position;
    // 破甲比例与并行单位共用 armorIgnoreRatio 单一口径。
    final pierceIgnore = game.armorIgnoreRatio;
    final knockLv = game.slotLevel('knockback');
    final lifestealLv = game.slotLevel('lifesteal');

    // 空间哈希（节点12）：先取玩家附近候选（外环 + 最大怪半径 + 余量）
    // 再扇形判定，避免 monsterCap 全量遍历
    final hitCd = game.bladeHitCd;
    final candidates = game.spatialGrid.queryRange(
      center,
      arm.outerRadius + 120 + 40,
    );
    for (final m in candidates) {
      if (m.isDead) continue;
      final toM = m.position - center;
      final dist = toM.length;
      if (dist < 1) continue;

      // 无内圈豁免：外环可及（外缘重叠）即参与扇形判定，
      // 内圈贴身经过同样造成全额伤害
      if (dist - m.radius > arm.outerRadius) continue;

      // 扇形判定：逐扇叶检查各自豁免，命中后立即登记；扇叶之间互不共享
      final hitBlade = bladeAngleHit(
        game: game,
        arm: arm,
        targetAngle: math.atan2(toM.y, toM.x),
        angularHalf: bladeAngularHalf(arm, m.radius, dist),
        canHit: (i) => m.bladeHitCds.canBladeHit(i),
      );
      if (hitBlade == null) continue;
      _hitMonster(game, m, game.hitDamageBase,
          pierceIgnore: pierceIgnore,
          knockLv: knockLv,
          lifestealLv: lifestealLv,
          toM: toM);
      m.bladeHitCds.markBladeHit(hitBlade, hitCd);
    }

    // 参照物扫掠同样按扇叶独立豁免
    game.sweepMapObjects(game, arm, dt);
  }

  /// 命中结算：暴击判定 → 穿刺破甲（按比例无视护甲，在 takeDamage 内
  /// 生效）→ 触发型法宝（幌金绳定身/暴击雷引闪电链）→ 吸血回复 → 击退。
  /// 灼烧不随命中点燃，统一由臂展驻留判定驱动。
  /// 暴击/特效只弹关键浮动文字（普通命中不弹字，防刷屏）。
  void _hitMonster(
    JourneyFlameGame game,
    JourneyMonsterComponent m,
    double damage, {
    required double pierceIgnore,
    required int knockLv,
    required int lifestealLv,
    required Vector2 toM,
    bool allowSignature = true,
    double? conditionBase,
  }) {
    var dmg = damage;
    // 伏魔重击（沙僧环绕专属爆发）：并行单位高频命中若也能消耗，
    // 会在小伤害上浪费 3 倍爆发并吞掉环绕定身，故按 allowSignature 屏蔽。
    if (allowSignature && game.hasAbility('shaseng') && game._fumoCharged) {
      game._fumoCharged = false;
      game._fumoTimer = 0;
      dmg *= 3;
      // 定身波及半径钳制在武器臂长内（以受击怪为圆心）。
      final reach = math.min(
        260.0,
        game.weaponArm?.outerRadius ?? double.maxFinite,
      );
      for (final other in game.monsters) {
        if (!other.isDead &&
            (other.position - m.position).length <= reach) {
          other.rootTimer = 1;
        }
      }
      game.spawnFloatText(
        m.position + Vector2(0, -m.radius - 14),
        '伏魔重击',
        const Color(0xFFD4593F),
      );
    }
    // 火眼金睛（扩展被动）：对精英/妖王的条件增伤并入伤害公式的增伤合计
    // （伤害=基础值×(1+Σ通用%+条件%)，与通用增伤加法合流、单次乘算）。
    // 环绕传环绕基础值、弹道传自身未增伤基础值，两轨同一口径。
    if ((m.model.isBoss || m.model.isElite) &&
        game.passiveSlotCodes.contains('huoyan_jingjing')) {
      dmg += (conditionBase ?? game.damageBaseValue) *
          game.weaponParam('huoyan_jingjing', 'elite', 0.2);
      game.fxLayer.spawnRing(
        m.position,
        m.radius + 6,
        color: const Color(0xFFFFB27A),
      );
      // GameAudio.instance.journeyTrigger();
    }
    // 暴击判定（§8）：率与倍率见主类字段
    final isCrit = game.critRate > 0 && game.rng.nextDouble() < game.critRate;
    if (isCrit) {
      dmg *= game.critDamage;
    }
    // 穿刺破甲：比例在 takeDamage 内按目标护甲生效（灼烧/法宝等衍生
    // 伤害不传 armorIgnore，不受益破甲，口径与吸血一致）
    m.takeDamage(dmg, armorIgnore: pierceIgnore);
    if (isCrit) {
      game.spawnFloatText(
        m.position + Vector2(0, -m.radius - 14),
        '会心 ${dmg.round()}',
        const Color(0xFFE8C470),
      );
      // 暴击雷引：暴击触发闪电链（params.range/params.targets/params.chain）
      if (game.effectWeapons.contains('baoji_thunder')) {
        _lightningChain(
          game,
          m,
          dmg * game.weaponParam('baoji_thunder', 'chain', 0.4),
        );
      }
      // 七星剑：暴击对精英/妖王追加真伤（params.bonus；绕护甲）
      if (game.effectWeapons.contains('qixing_jian') &&
          (m.model.aiTier != 'normal' || m.model.isBoss)) {
        m.takeDamage(
          dmg * game.weaponParam('qixing_jian', 'bonus', 0.3),
          armorIgnore: 1,
        );
      }
    }
    // 幌金绳：命中按概率定身；混天绫：命中按概率把妖物拖向玩家近身
    if (!m.isDead &&
        game.effectWeapons.contains('kunxian_rope') &&
        game.rng.nextDouble() < game.weaponParam('kunxian_rope', 'chance', 0.12)) {
      m.rootTimer = game.weaponParam('kunxian_rope', 'root', 1.5);
      game.fxLayer.spawnRing(m.position, m.radius + 8,
          color: const Color(0xFFFFE9A8));
    }
    if (!m.isDead &&
        game.effectWeapons.contains('huntian_ling') &&
        game.rng.nextDouble() < game.weaponParam('huntian_ling', 'chance', 0.12)) {
      final toPlayer = game.player.position - m.position;
      final drag = math.min(game.weaponParam('huntian_ling', 'drag', 90),
          toPlayer.length - m.radius - 20);
      if (drag > 0) m.applyDrag(toPlayer, drag);
      game.fxLayer.spawnRing(m.position, m.radius + 8,
          color: const Color(0xFFD98AD9));
    }
    // 紫金铃（扩展特效）：同一目标累计命中 hits 次引发妖火爆炸
    if (!m.isDead && game.effectWeapons.contains('zijin_ling')) {
      m.lingHits++;
      if (m.lingHits >= game.weaponParam('zijin_ling', 'hits', 3).round()) {
        m.lingHits = 0;
        _lingBurst(game, m);
      }
    }
    if (lifestealLv > 0) {
      // 吸血：按最终命中伤害（含暴击/伏魔/火眼加伤）比例回复，比例与保底
      // 走共享口径（见 lifestealHealOf）；秒窗合计钳到最大生命一定比例
      // （防多目标高频命中叠乘；禁疗由 addLifestealHeal 拦截）。
      game.addLifestealHeal(game.lifestealHealOf(dmg, lifestealLv));
    }
    final qiankunLv = game.slotLevel('qiankun');
    if (qiankunLv > 0) {
      // 乾坤：命中获盾，基数与每级增量后台可配；gainShield 封顶最大生命，
      // 盾满不再增长，与护体/拾取护盾共用同一盾池。
      final add =
          game.battleNum(
            'weapon',
            'qiankun_base',
            kJourneyQiankunShieldBase,
          ) +
          game.slotValue('qiankun', kJourneyQiankunShieldPerLv) *
              (qiankunLv - 1);
      game.player.gainShield(add);
    }
    final poisonLv = game.slotLevel('poison');
    if (poisonLv > 0 && !m.isDead) {
      // 淬毒：命中点燃中毒，同一 source key 覆盖实现不可叠加、二次命中
      // 重置时长；伤害按伤害基础值（武器伤害+等级攻击+角色基础攻击）比例
      // 结算，走绕甲的真实伤害通道。
      final base =
          game.battleNum('weapon', 'poison_base', kJourneyPoisonRatioBase) +
          game.slotValue('poison', kJourneyPoisonRatioPerLv) * (poisonLv - 1);
      m.ignite(
        source: 'weapon_poison',
        burnDps: game.damageBaseValue * base * game.passiveAmpFactor,
        seconds:
            game.battleNum('weapon', 'poison_sec', kJourneyPoisonSeconds),
        trueDamage: true,
      );
    }
    if ((knockLv > 0 || game.player.bonusKnockback > 0) &&
        m.knockbackCd <= 0) {
      var kb = game.slotValue('knockback', 16) * knockLv +
          game.player.bonusKnockback; // 击退槽 + 飞龙宝杖被动加成
      // 铜皮铁骨（bajie 特殊能力）：受击窗口内击退强度放大
      if (game._bajieGuard > 0) {
        kb *= game.battleNum('ability', 'bajie_knock_mult', 1.5);
      }
      // 不动如山（牛魔王）：抗击退（journey_monster_params.knock_resist）
      kb *= 1 -
          game.monsterParam(
            m.model.code,
            'knock_resist',
            m.model.hasAbility('unmovable') ? 0.8 : 0,
          );
      m.applyKnockback(toM, kb);
      // 抗击退把距离抵消到 0 时不计入冷却，避免吞掉窗口内后续有效击退。
      if (kb > 0) m.knockbackCd = game.knockbackHitCd;
    }
  }

  /// 暴击雷引：从受击怪出发，range 内最近 ≤targets 只其他怪各受
  /// chain 比例本击伤害（params.range/params.targets/params.chain，
  /// 直接结算，不计暴击），并画 0.15s 白色连线。
  void _lightningChain(
    JourneyFlameGame game,
    JourneyMonsterComponent from,
    double damage,
  ) {
    // 连锁半径钳制在武器臂长内：以受击怪为圆心，但波及目标不得超出
    // 玩家可见屏（臂长受 maxArmDiameter/2 约束，天然在屏内）。
    final range = math.min(
      game.weaponParam('baoji_thunder', 'range', 260),
      game.weaponArm?.outerRadius ?? double.maxFinite,
    );
    final targets = game.weaponParam('baoji_thunder', 'targets', 2).round();
    final candidates = <JourneyMonsterComponent>[];
    for (final m in game.monsters) {
      if (identical(m, from) || m.isDead) continue;
      if ((m.position - from.position).length <= range) {
        candidates.add(m);
      }
    }
    if (candidates.isEmpty) return;
    double d2(JourneyMonsterComponent m) => (m.position - from.position).length2;
    candidates.sort((a, b) => d2(a).compareTo(d2(b)));
    for (final m in candidates.take(targets)) {
      m.takeDamage(damage);
      game.fxLayer.spawnLightning(from.position, m.position);
    }
  }

  /// 紫金铃妖火爆炸：目标 range 内其他怪受 damage 比例武器伤害
  /// （params.range/params.damage，不计暴击），爆炸圈 FX + 浮动字提示。
  void _lingBurst(JourneyFlameGame game, JourneyMonsterComponent m) {
    final arm = game.weaponArm;
    if (arm == null) return;
    final damage = game.hitDamageBase *
        game.weaponParam('zijin_ling', 'damage', 0.6);
    // 爆炸半径钳制在武器臂长内（以目标怪为圆心，不波及屏外目标）。
    final range = math.min(
      game.weaponParam('zijin_ling', 'range', 120),
      arm.outerRadius,
    );
    for (final other in game.monsters) {
      if (other.isDead || identical(other, m)) continue;
      if ((other.position - m.position).length <= range) {
        other.takeDamage(damage);
      }
    }
    game.fxLayer.spawnRing(m.position, range);
    game.spawnFloatText(
      m.position + Vector2(0, -m.radius - 14),
      '妖火爆裂',
      const Color(0xFFD4593F),
    );
  }

}
