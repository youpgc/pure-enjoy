part of 'journey_flame_game.dart';

/// 角色装备与局外注入（extension，同 library 访问宿主私有成员）：
/// - 初始环绕臂构建（角色差异：转速/臂长/伤害/臂宽 + 专属特效槽）；
/// - 法宝分级（journey_weapon_levels 品阶伤害结算）；
/// - 被动加持入槽生效映射；
/// - 角色光环与天赋层增量注入；
/// - 无妖章回通关锚点（时长→西行里程换算基准）。
extension JourneyKit on JourneyFlameGame {
  /// 无妖章回（原著无妖，区域 boss_code=NULL）通关时长锚点：取关卡
  /// duration_target_sec 配置（game_levels.config jsonb，后台可调）。
  /// 无妖主线章回以锚点时长换算西行里程目标；每日游历不消费时长锚点
  /// （进图即亮「功成」、随时结算，无通关条件限制/提示）。
  int get surviveTargetSec =>
      level.durationTargetSec > 0 ? level.durationTargetSec : 300;

  /// 无妖主线章回西行里程目标（里）：基础移速 × 锚点时长 ÷ 25
  /// （1 里=25 世界单位，与妖王罗盘同约定）。恒速基础移速恰好在锚点
  /// 时长内走完；移速投入可提前达成，挂机/定身不累计里程、无法达成。
  int get travelTargetLi =>
      (JourneyPlayerComponent.baseSpeed * surviveTargetSec / 25).round();

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

  /// 法宝分级（journey_weapon_levels）：当前品阶伤害=分级表
  /// [min(角色等级, 8)] 级；分级表未配置该法宝或缺当前级时回落
  /// base_damage（后台「基础伤害」，保证单源可调不失效）。
  double _gradeDamage({required double fallback}) {
    final levels = config?.weaponLevels[character.weaponCode];
    if (levels != null && levels.isNotEmpty) {
      final grade = _charLv.clamp(1, 8);
      for (final l in levels) {
        if (l.lv == grade && l.damage > 0) return l.damage.toDouble();
      }
    }
    return fallback;
  }

  /// 升级后按法宝分级刷新当前品阶伤害（环绕形态消费 damage 列）；
  /// 已炼化保持 ×evoMult（炼化增幅不因升级刷新而丢失）。
  void _refreshWeaponGrade() {
    final arm = weaponArm;
    if (arm == null) return;
    arm.damage =
        _gradeDamage(fallback: weaponBaseDamage) * (evolved ? evoMult : 1.0);
  }

  /// 被动加持入槽：入槽即生效（效果映射，重复选择不会入池）。
  void _grantPassiveWeapon(String code) {
    if (passiveSlotCodes.contains(code) || passiveSlotCodes.length >= 6) return;
    switch (code) {
      case 'jindou_cloud': // 筋斗云：移速（params.move）
        moveSpeedAmp += weaponParam('jindou_cloud', 'move', 0.12);
        break;
      case 'pantao': // 蟠桃：生命上限+回复（params.hp/regen）
        final hpUp = weaponParam('pantao', 'hp', 25);
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
      // zijin_gourd 已改角色绑定特性法宝（紫金葫芦），被动加持槽位退役
      case 'sanheng_mao': // 三根毫毛：免死标记在血量归零链路查表生效
      case 'yujing_ping': // 玉净瓶甘露：周期回血在玩家 update 查表生效
      case 'huoyan_jingjing': // 火眼金睛：命中结算查表对精英/妖王增伤
        break;
    }
    passiveSlotCodes.add(code);
    controller.passiveSlots.add(code);
    controller.hud.slotsRevision.value++;
  }

  /// 局外预注入：出战角色五行天赋树线性增量 + 加强点特殊能力标记。
  void _applyLoadout() {
    final lo = loadout;
    // 特殊能力标记（'ability_<char>'）：加强点点亮 → 引擎钩子生效
    abilities.addAll(lo.abilities);
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
  void _applyCharacterKit() {
    switch (character.code) {
      case 'tang': // 佛光：周期回血（≈0.8/秒）
        player.regen += 0.8;
        break;
      case 'wukong': // 大圣威压：击杀概率触发短暂转速提升（见 onMonsterKilled）
        break;
      case 'bajie': // 贪食：拾取范围 + 经验获取加成
        player.pickupRange += 40;
        expAmp *= 1.15;
        break;
      case 'shaseng': // 坚韧：受击减伤（接触伤害固定减免）
        player.armor += 6;
        break;
      // ---- 非取经扩展角色（feature_journey_ext_chars_20261106）----
      case 'nezha': // 莲花化身：经验获取加成（击杀加速成长）
        expAmp *= 1.15;
        break;
      case 'honghaier': // 三昧真火：武器伤害加成（烈焰增伤）
        damageAmp *= 1.08;
        break;
      case 'tieshan': // 罡风偃月：移速加成（控场走位）
        moveSpeedAmp *= 1.08;
        break;
      case 'laojun': // 兜率炉火：暴击伤害加成（炉火淬炼）
        critDamage = (critDamage + 0.2).clamp(1.0, 2.0);
        break;
      case 'jinjiao': // 移山劲：护甲加成（厚血抗压前排）
        player.armor += 4;
        break;
    }
  }
}
