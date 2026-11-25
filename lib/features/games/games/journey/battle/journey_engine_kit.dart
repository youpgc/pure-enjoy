part of 'journey_flame_game.dart';

/// 角色装备与局外注入（extension，同 library 访问宿主私有成员）：
/// - 初始环绕臂构建（角色差异：转速/臂长/伤害/臂宽 + 专属特效槽）；
/// - 法宝分级（journey_weapon_levels 品阶伤害结算）；
/// - 被动加持入槽生效映射；
/// - 角色光环与天赋层增量注入；
/// - 无妖章回通关锚点（时长→西行里程换算基准）。
extension JourneyKit on JourneyFlameGame {
  /// 无妖章回（原著无妖，区域 boss_code=NULL）通关时长锚点：取关卡
  /// duration_target_sec 配置（journey_levels 子表，后台可调）。
  /// 无妖主线章回以锚点时长换算西行里程目标；每日游历不消费时长锚点
  /// （进图即亮「功成」、随时结算，无通关条件限制/提示）。
  int get surviveTargetSec =>
      level.durationTargetSec > 0 ? level.durationTargetSec : 300;

  /// 无妖主线章回西行里程目标（里）：基础移速 × 锚点时长 ÷ 25
  /// （1 里=25 世界单位，与妖王罗盘同约定）。恒速基础移速恰好在锚点
  /// 时长内走完；移速投入可提前达成，挂机/定身不累计里程、无法达成。
  int get travelTargetLi =>
      (baseSpeed * surviveTargetSec / battleNum('player', 'units_per_li', 25))
          .round();

  /// 建立角色初始环绕（特性法宝 1 件）：转速/内缘/臂长/臂宽/基础伤害/
  /// 初始特效全部读 journey_weapons 后台配置；行未配置（或字段为 0/空）
  /// 时回落内置差异兜底，保证离线种子同样成立。
  void _buildStarterArm() {
    // 基础转速在原始节奏上提速约四分之一：扇叶扫掠更连贯，单怪受击
    // 冷却会吸收大部分频率增益，整体 DPS 不随转速等比例放大。
    var speed = 3.3;
    var inner = 26.0;
    var outer = 104.0;
    var damage = 14.0;
    var width = 24.0;
    var starterEffect = 'pierce';
    switch (character.weaponCode) {
      case 'jingubang': // 金箍棒：快转窄扇叶 + 穿刺
        speed = 4.0;
        outer = 96;
        damage = 13;
        width = 22;
        starterEffect = 'pierce';
        break;
      case 'jiuchi_paba': // 九齿钉耙：慢转宽扇叶长杆 + 击退
        speed = 2.4;
        inner = 22;
        outer = 126;
        damage = 11;
        width = 30;
        starterEffect = 'knockback';
        break;
      case 'jiangyao_bangzhang': // 降妖宝杖：慢转重击 + 灼烧
        speed = 2.0;
        outer = 92;
        damage = 21;
        width = 26;
        starterEffect = 'burn';
        break;
      case 'staff_buddha_light': // 九环锡杖·佛光：均衡 + 吸血（佛光续航意象）
        starterEffect = 'lifesteal';
        break;
      default:
        break;
    }
    // 后台配置覆盖（journey_weapons 初始环绕参数列，运营可调）
    final w = config?.weaponOf(character.weaponCode);
    if (w != null) {
      if (w.orbitSpeed > 0) speed = w.orbitSpeed;
      if (w.innerRadius > 0) inner = w.innerRadius;
      if (w.outerRadius > 0) outer = w.outerRadius;
      if (w.bladeWidth > 0) width = w.bladeWidth;
      if (w.baseDamage > 0) damage = w.baseDamage;
      if (w.starterEffect.isNotEmpty) starterEffect = w.starterEffect;
    }
    weaponBaseDamage = damage;
    weaponArm = JourneyWeaponArm(
      speedBase: speed,
      innerRadius: inner,
      outerRadiusBase: outer,
      damage: _gradeDamage(fallback: damage),
      bladeWidth: width,
    );
    // 初始臂长与臂展槽升级共用同一上限口径（后台超限配置防首次升级反向缩短）
    weaponArm!.outerRadius = math.min(
      weaponArm!.outerRadius,
      math.min(weaponArm!.outerRadiusBase * 2.2, maxArmDiameter / 2),
    );
    learnSlot(starterEffect);
  }

  /// 法宝分级（journey_weapon_levels）：L1~L8 查分级表；L9 起分级表未定义，
  /// 以 L8 品阶伤害为锚按每级增幅复利延展 ×(1+增幅)^(等级−8)
  /// （journey_globals.weapon_grade_per_lv 可覆盖，缺省 1.5%）。
  /// 分级表未配置该法宝或缺当前级时回落 base_damage（后台「基础伤害」，
  /// 保证单源可调不失效），L9+ 同样按锚点复利。
  double _gradeDamage({required double fallback}) {
    final per = config?.weaponGradePerLv ?? kJourneyWeaponGradePerLv;
    final levels = config?.weaponLevels[character.weaponCode];
    double? gradeOf(int lv) {
      for (final l in levels ?? const <JourneyWeaponLevelModel>[]) {
        if (l.lv == lv && l.damage > 0) return l.damage.toDouble();
      }
      return null;
    }

    final anchor = gradeOf(math.min(_charLv, 8)) ?? fallback;
    if (_charLv <= 8) return anchor;
    return anchor * math.pow(1 + per, _charLv - 8).toDouble();
  }

  /// 升级后按法宝分级刷新当前品阶伤害（环绕形态消费 damage 列）；
  /// 已炼化保持 ×evoMult（炼化增幅不因升级刷新而丢失）。
  void _refreshWeaponGrade() {
    final arm = weaponArm;
    if (arm == null) return;
    arm.damage =
        _gradeDamage(fallback: weaponBaseDamage) * (evolved ? evoMult : 1.0);
    // 并行攻击单位的分级数值同源刷新（各自取分级表的形态列）。
    _refreshAttackUnits();
  }

  /// 被动加持入槽：入槽即生效（效果映射，重复选择不会入池）。
  void _grantPassiveWeapon(String code) {
    if (passiveSlotCodes.contains(code) || passiveSlotCodes.length >= 6) return;
    switch (code) {
      case 'jindou_cloud': // 筋斗云：移速（params.move）
        moveSpeedAmp += weaponParam('jindou_cloud', 'move', 0.12);
        break;
      case 'pantao': // 蟠桃：生命上限+回复（params.hp_ratio/regen）
        // 登记加成比例，不在此结算固定上限：后续固定额生命成长同步放大，
        // 使蟠桃加成随角色成长持续提升；hp_ratio 缺行回落 0.2。
        final hpRatio = weaponParam('pantao', 'hp_ratio', 0.2);
        player.pantaoHpRatio = hpRatio;
        final hpUp = player.maxHp * hpRatio;
        player.maxHp += hpUp;
        player.hp = (player.hp + hpUp).clamp(0.0, player.maxHp);
        controller.hud.maxHp.value = player.maxHp;
        controller.hud.hp.value = player.hp;
        player.regen += weaponParam('pantao', 'regen', 0.5);
        break;
      case 'renshen_guo': // 人参果：经验（params.exp）
        expAmp += weaponParam('renshen_guo', 'exp', 0.25);
        break;
      case 'bishui_pearl': // 避水珠：转速（params.spin）
        spinAmp += weaponParam('bishui_pearl', 'spin', 0.15);
        break;
      case 'dingfeng_pearl': {
        // 定风丹：臂长+（params.radius；与臂展槽同用 2.2×基准上限，
        // 且直径不超屏幕宽-40）——口径统一保证纯增益不反向缩短
        final arm = weaponArm;
        if (arm != null) {
          arm.outerRadius = math.min(
            arm.outerRadius + weaponParam('dingfeng_pearl', 'radius', 18),
            math.min(arm.outerRadiusBase * 2.2, maxArmDiameter / 2),
          );
        }
        break;
      }
      case 'shelizi': // 舍利子：伤害（params.damage）
        damageAmp += weaponParam('shelizi', 'damage', 0.15);
        break;
      case 'jinlan_kasha': // 锦襕袈裟：护体护甲（params.armor）
        player.armor += weaponParam('jinlan_kasha', 'armor', 5);
        break;
      case 'feilong_staff': // 飞龙宝杖：命中击退加成（params.knockback）
        player.bonusKnockback += weaponParam('feilong_staff', 'knockback', 12);
        break;
      case 'bihuo_zhao': // 辟火罩：火系伤害减免（params.resist）
        player.fireResist = (player.fireResist +
                weaponParam('bihuo_zhao', 'resist', 0.15))
            .clamp(0.0, 0.8);
        break;
      // zijin_gourd 已改角色绑定特性法宝（紫金葫芦），被动加持槽位退役
      case 'sanheng_mao': // 三根毫毛：免死标记在血量归零链路查表生效
      case 'yujing_ping': // 玉净瓶甘露：周期回血在玩家 update 查表生效
      case 'huoyan_jingjing': // 火眼金睛：命中结算查表对精英/妖王增伤
      case 'zhaoyao_jing': // 照妖镜：护盾抵伤时反震（受击入口查表）
      case 'zhenyao_zhong': // 震妖钟：护盾归零时范围震荡（受击入口查表）
        break;
    }
    passiveSlotCodes.add(code);
    controller.passiveSlots.add(code);
    bumpSlotsRevision();
  }

  /// 局外预注入：出战角色五行天赋树线性增量 + 加强点特殊能力标记。
  void _applyLoadout() {
    final lo = loadout;
    // 特殊能力标记（'ability_<char>'）：加强点点亮 → 引擎钩子生效
    abilities.addAll(lo.abilities);
    attackAmp += lo.attackAmp;
    damageAmp += lo.damageAmp;
    spinAmp += lo.spinAmp;
    player.armor += lo.armorFlat;
    player.regen += lo.regenFlat;
    player.pickupRange += lo.pickupRangeFlat;
    expAmp *= lo.expAmp; // 乘区注入（loadout 基准 1.0；不覆盖角色光环乘区）
    // 暴击注入（§8）：均为增量叠加（角色光环先注入，天赋增量不覆盖）；
    // 暴击率钳 ≤0.60、暴击伤害钳 [1.0, 2.0]
    critRate = (critRate + lo.critRateFlat).clamp(0.0, 0.60);
    critDamage = (critDamage + lo.critDamageBonus).clamp(1.0, 2.0);
    if (lo.bonusMaxHp > 0) {
      player.maxHp += lo.bonusMaxHp;
      player.hp += lo.bonusMaxHp;
    }
    // 化形枝标志特效（v4）：
    // wood 回春：回复翻倍 + 生命上限突破 +10%
    if (lo.signatures.contains('signature_wood')) {
      player.maxHp = player.maxHp * 1.1;
      player.hp = player.hp * 1.1;
      player.regen *= 2;
    }
    // earth 不动：拾取磁吸全屏
    if (lo.signatures.contains('signature_earth')) {
      player.pickupRange = 9999;
    }
  }

  /// 角色光环（取经 4 人 + 非取经扩展 5 人差异化）。
  /// 入口先注入角色初始属性（journey_characters.armor 初始护甲，
  /// 与天赋/光环/局内护甲槽累加），再叠加光环差异化效果。
  void _applyCharacterKit() {
    player.armor += character.armor;
    // 数值取角色光环参数（journey_character_aura_params 一行一键，按角色
    // 聚合注入，后台可配），键缺失回落内置兜底；键语义见角色模型注释。
    switch (character.code) {
      case 'tang': // 佛光：周期回血
        player.regen += character.auraNum('regen', 0.8);
        break;
      case 'wukong': // 大圣威压：击杀概率触发短暂转速提升（见 onMonsterKilled）
        break;
      case 'bajie': // 贪食：拾取范围 + 经验获取加成
        player.pickupRange += character.auraNum('pickup', 40);
        expAmp *= 1 + character.auraNum('exp_amp', 0.15);
        break;
      case 'shaseng': // 坚韧：护甲加成
        player.armor += character.auraNum('armor', 6);
        break;
      // ---- 非取经扩展角色（feature_journey_ext_chars_20261106）----
      case 'nezha': // 莲花化身：经验获取加成（击杀加速成长）
        expAmp *= 1 + character.auraNum('exp_amp', 0.15);
        break;
      case 'honghaier': // 三昧真火：武器伤害加成（烈焰增伤，加法合流）
        damageAmp += character.auraNum('damage_amp', 0.08);
        break;
      case 'tieshan': // 罡风偃月：移速加成（控场走位）
        moveSpeedAmp *= 1 + character.auraNum('move_amp', 0.08);
        break;
      case 'laojun': // 兜率炉火：基础暴击率 + 暴击伤害加成（炉火淬炼）
        // 基础暴击率为暴伤光环的收益前提，与天赋暴击率增量叠合后在
        // _applyLoadout 统一钳 ≤0.60；暴击伤害钳 [1.0, 2.0]。
        critRate += character.auraNum('crit_rate', 0.05);
        critDamage =
            (critDamage + character.auraNum('crit_damage', 0.2)).clamp(1.0, 2.0);
        break;
      case 'jinjiao': // 移山劲：护甲加成（厚血抗压前排）
        player.armor += character.auraNum('armor', 4);
        break;
    }
  }
}
