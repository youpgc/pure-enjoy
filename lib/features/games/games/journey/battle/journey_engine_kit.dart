part of 'journey_flame_game.dart';

/// 角色装备与局外注入（extension，同 library 访问宿主私有成员）：
/// - 初始环绕臂构建（角色差异：转速/臂长/伤害/臂宽 + 专属特效槽）；
/// - 法宝分级（journey_weapon_levels 品阶伤害结算）；
/// - 被动加持入槽生效映射；
/// - 角色光环与天赋层增量注入；
/// - 无妖章回坚持通关时长。
extension JourneyKit on JourneyFlameGame {
  /// 无妖章回（原著无妖，区域 boss_code=NULL）通关口径：坚持满时长即功成。
  /// 时长取关卡 duration_target_sec 配置（game_levels.config jsonb，后台可调）。
  int get surviveTargetSec =>
      level.durationTargetSec > 0 ? level.durationTargetSec : 300;

  /// 建立角色初始环绕（特性法宝 1 件，角色差异在转速/臂长/伤害/臂宽），
  /// 并以角色专属特效占用主动槽 1（金箍棒=穿刺/钉耙=击退/宝杖=灼烧/
  /// 佛光=吸血）。
  void _buildStarterArm() {
    var speed = 2.6;
    var inner = 26.0;
    var outer = 104.0;
    var damage = 14.0;
    var width = 24.0;
    var starterEffect = 'pierce';
    switch (character.weaponCode) {
      case 'jingubang': // 金箍棒：快转窄扇叶 + 穿刺
        speed = 3.2;
        outer = 96;
        damage = 13;
        width = 22;
        starterEffect = 'pierce';
        break;
      case 'jiuchi_paba': // 九齿钉耙：慢转宽扇叶长杆 + 击退
        speed = 1.9;
        inner = 22;
        outer = 126;
        damage = 11;
        width = 30;
        starterEffect = 'knockback';
        break;
      case 'jiangyao_bangzhang': // 降妖宝杖：慢转重击 + 灼烧
        speed = 1.6;
        outer = 92;
        damage = 21;
        width = 26;
        starterEffect = 'burn';
        break;
      case 'staff_buddha_light': // 禅杖·佛光：均衡 + 吸血（佛光续航意象）
        starterEffect = 'lifesteal';
        break;
      default:
        break;
    }
    weaponBaseDamage = damage;
    weaponArm = JourneyWeaponArm(
      speedBase: speed,
      innerRadius: inner,
      outerRadiusBase: outer,
      damage: _gradeDamage(fallback: damage),
      bladeWidth: width,
    );
    learnSlot(starterEffect);
  }

  /// 法宝分级（journey_weapon_levels）：当前品阶伤害=分级表
  /// [min(角色等级, 8)] 级；表缺失回落角色内置基准。
  double _gradeDamage({required double fallback}) {
    final levels = config?.weaponLevels[character.weaponCode];
    if (levels != null && levels.isNotEmpty) {
      final grade = _charLv.clamp(1, 8);
      for (final l in levels) {
        if (l.lv == grade && l.damage > 0) return l.damage.toDouble();
      }
      return levels.first.damage.toDouble();
    }
    return fallback;
  }

  /// 升级后按法宝分级刷新当前品阶伤害（环绕形态消费 damage 列）。
  void _refreshWeaponGrade() {
    final arm = weaponArm;
    if (arm == null) return;
    arm.damage = _gradeDamage(fallback: weaponBaseDamage);
  }

  /// 被动加持入槽：入槽即生效（效果映射，重复选择不会入池）。
  void _grantPassiveWeapon(String code) {
    if (passiveSlotCodes.contains(code) || passiveSlotCodes.length >= 6) return;
    switch (code) {
      case 'jindou_cloud': // 筋斗云：移速
        moveSpeedAmp += 0.12;
        break;
      case 'pantao': // 蟠桃：血量+回复
        player.maxHp += 25;
        player.hp = (player.hp + 25).clamp(0.0, player.maxHp);
        controller.hud.maxHp.value = player.maxHp;
        controller.hud.hp.value = player.hp;
        player.regen += 0.5;
        break;
      case 'renshen_guo': // 人参果：经验
        expAmp += 0.25;
        break;
      case 'bishui_pearl': // 避水珠：转速
        spinAmp = (spinAmp + 0.15).clamp(0.0, spinCap);
        break;
      case 'dingfeng_pearl': {
        // 定风珠：臂长+18（受击区间变宽）；与三选一同用 1.8×基准上限
        final arm = weaponArm;
        if (arm != null) {
          arm.outerRadius =
              math.min(arm.outerRadius + 18, arm.outerRadiusBase * 1.8);
        }
        break;
      }
      case 'shelizi': // 舍利子：伤害
        damageAmp += 0.15;
        break;
      case 'zijin_gourd': // 紫金葫芦：拾取磁吸
        player.pickupRange += 50;
        break;
    }
    passiveSlotCodes.add(code);
    controller.passiveSlots.add(code);
    controller.hud.slotsRevision.value++;
  }

  /// 局外预注入：天赋层增量 + 标志层轻量映射。
  void _applyLoadout() {
    final lo = loadout;
    damageAmp += lo.damageAmp;
    spinAmp += lo.spinAmp;
    player.armor += lo.armorFlat;
    player.regen += lo.regenFlat;
    player.pickupRange += lo.pickupRangeFlat;
    expAmp = lo.expAmp;
    if (lo.bonusMaxHp > 0) {
      player.maxHp += lo.bonusMaxHp;
      player.hp += lo.bonusMaxHp;
    }
    if (lo.signatures.contains('signature_wood')) {
      player.maxHp = player.maxHp * 1.1;
      player.hp = player.hp * 1.1;
      player.regen *= 2;
    }
    if (lo.signatures.contains('signature_metal')) {
      damageAmp += 0.15;
    }
    if (lo.signatures.contains('signature_fire')) {
      damageAmp += 0.10;
    }
    if (lo.signatures.contains('signature_water')) {
      // 玄水·流转：环绕转速即时 +15%（上限放宽至 1.75 见 spinCap）
      spinAmp = (spinAmp + 0.15).clamp(0.0, spinCap);
    }
    if (lo.signatures.contains('signature_earth')) {
      player.pickupRange = 9999; // 厚土磁吸全屏
      player.armor += 4;
    }
  }

  /// 角色光环（四角色差异化）。
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
    }
  }
}
