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

  double outerRadius; // 当前外环半径（臂展槽/定风珠成长）

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
  double get spinCap;
  double get damageAmp;
  set damageAmp(double value);
  JourneyPlayerComponent get player;
}

/// 武器系统：
/// - 判定=扇形扫掠：怪与玩家连线角落在扇叶角 ± atan(半宽/距离) 内，
///   且怪距落在 [内环-怪半径, 外环+怪半径] → 扇叶扫到哪里哪里受击；
/// - 单怪 0.3s 冷却防反复叠伤；环带内缘贴脸怪按 8 折兜底扫击；
/// - 命中结算维度特效：穿刺（伤害乘成）/击退（推开）/吸血（回复）/
///   灼烧（持续掉血）；
/// - 维度槽操作（习得/升级/每级效果结算）。
mixin JourneyWeaponMixin on FlameGame implements JourneyWeaponHost {
  /// 某维度槽当前等级（未习得=0）。
  int slotLevel(String code) {
    for (final s in weaponSlots) {
      if (s.code == code) return s.level;
    }
    return 0;
  }

  /// 习得维度（占 1 空槽，Lv1）并应用每级效果。
  void learnSlot(String code) {
    if (weaponSlots.length >= 6) return;
    if (slotLevel(code) > 0) return;
    final slot = JourneyWeaponSlot(code, 1);
    weaponSlots.add(slot);
    controller.activeSlots.add(slot);
    applySlotEffect(code, 1);
    controller.hud.slotsRevision.value++;
  }

  /// 维度升级（+delta 级）并应用每级效果（上限由配置驱动，调用方判定）。
  void upgradeSlot(String code, {int delta = 1}) {
    for (final s in weaponSlots) {
      if (s.code == code) {
        s.level += delta;
        applySlotEffect(code, delta);
        controller.hud.slotsRevision.value++;
        return;
      }
    }
  }

  /// 维度每级效果结算：属性维度即时应用到战斗字段；
  /// 特效维度（击退/吸血/穿刺/灼烧）在命中时读 slotLevel 结算。
  void applySlotEffect(String code, int delta) {
    switch (code) {
      case 'radius': // 臂展：每级 +14（受击环带变宽，武器等比变大）
        final arm = weaponArm;
        if (arm != null) {
          arm.outerRadius = math.min(
            arm.outerRadius + 14 * delta,
            arm.outerRadiusBase * 2.2,
          );
        }
        break;
      case 'speed': // 转速：每级 +10%
        spinAmp = (spinAmp + 0.10 * delta).clamp(0.0, spinCap);
        break;
      case 'damage': // 伤害：每级 +20%
        damageAmp += 0.20 * delta;
        break;
      case 'magnet': // 磁吸：每级拾取范围 +40
        player.pickupRange += 40 * delta;
        break;
      case 'knockback':
      case 'lifesteal':
      case 'pierce':
      case 'burn':
        break; // 特效维度：命中结算（见 _hitMonster）
    }
  }

  void updateWeapons(JourneyFlameGame game, double dt) {
    final arm = game.weaponArm;
    if (arm == null) return;
    final center = game.player.position;
    final pierceLv = game.slotLevel('pierce');
    final knockLv = game.slotLevel('knockback');
    final lifestealLv = game.slotLevel('lifesteal');
    final burnLv = game.slotLevel('burn');

    for (final m in game.monsters) {
      if (m.isDead || m.orbHitCd > 0) continue;
      final toM = m.position - center;
      final dist = toM.length;
      if (dist < 1) continue;

      final nearEdge = dist - m.radius <= arm.outerRadius &&
          dist + m.radius >= arm.innerRadius;
      if (!nearEdge) {
        // 贴脸兜底：怪在环带内缘以内（贴身）按 8 折扫到
        if (dist < arm.innerRadius) {
          _hitMonster(game, m, arm.damage * game.damageAmp * 0.8,
              pierceLv: pierceLv,
              knockLv: knockLv,
              lifestealLv: lifestealLv,
              burnLv: burnLv,
              toM: toM);
          m.orbHitCd = 0.3;
        }
        continue;
      }

      // 扇形判定
      final monsterAngle = math.atan2(toM.y, toM.x);
      final angularHalf = math.atan2(arm.halfWidth + m.radius, dist);
      var hit = false;
      for (var i = 0; i < game.bladeCount; i++) {
        final a = arm.angle + i * math.pi * 2 / game.bladeCount;
        var diff = (monsterAngle - a) % (math.pi * 2);
        if (diff > math.pi) diff -= math.pi * 2;
        if (diff.abs() <= angularHalf) {
          hit = true;
          break;
        }
      }
      if (!hit) continue;
      _hitMonster(game, m, arm.damage * game.damageAmp,
          pierceLv: pierceLv,
          knockLv: knockLv,
          lifestealLv: lifestealLv,
          burnLv: burnLv,
          toM: toM);
      m.orbHitCd = 0.3;
    }
  }

  /// 命中结算：穿刺乘成 → 吸血回复 → 击退 → 灼烧点燃。
  void _hitMonster(
    JourneyFlameGame game,
    JourneyMonsterComponent m,
    double damage, {
    required int pierceLv,
    required int knockLv,
    required int lifestealLv,
    required int burnLv,
    required Vector2 toM,
  }) {
    var dmg = damage;
    if (pierceLv > 0) dmg *= 1.0 + 0.15 * pierceLv;
    m.takeDamage(dmg);
    if (lifestealLv > 0) {
      game.player.heal(damage * 0.05 * lifestealLv);
    }
    if (knockLv > 0) {
      m.position += toM.normalized() * (16.0 * knockLv);
    }
    if (burnLv > 0) {
      m.ignite(burnDps: 8.0 * burnLv, seconds: 2);
    }
  }
}

/// 环绕武器渲染（世界坐标覆盖组件，同时推进旋转相位）：
/// - 受击环带：内环~外环淡金填充 + 边界细线（伤害区间可视化）；
/// - 扇叶（bladeCount 条，等角间隔）：径向光带 + 武器 SVG 绘图
///   （纯武器内容资源，尺寸随臂长**等比**增长——长宽同系数放大）。
class JourneyOrbitWeapons extends Component {
  JourneyOrbitWeapons({required this.game});

  final JourneyFlameGame game;

  @override
  void update(double dt) {
    // dt=0 的布局期空刷不推进相位（与主类 update 短路口径一致）
    if (dt <= 0) return;
    final arm = game.weaponArm;
    if (arm == null) return;
    var speed = game.spinAmp; // 全局转速乘区（转速槽/天赋/避水珠）
    // 悟空「大圣威压」增益期间转速额外 +30%
    if (game._wukongBuffTimer > 0) speed += 0.3;
    arm.angle += arm.speedBase * speed * dt;
  }

  @override
  void render(Canvas canvas) {
    final arm = game.weaponArm;
    if (arm == null) return;
    final center = game.player.position.toOffset();
    final inner = arm.innerRadius;
    final outer = arm.outerRadius;
    final midR = (inner + outer) / 2;

    // 受击环带填充（淡金）+ 内外边界细线
    final bandPaint = Paint()
      ..color = const Color(0x16E8C470)
      ..style = PaintingStyle.stroke
      ..strokeWidth = arm.bandWidth;
    canvas.drawCircle(center, midR, bandPaint);
    final edgePaint = Paint()
      ..color = const Color(0x3DE8C470)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, inner, edgePaint);
    canvas.drawCircle(center, outer, edgePaint);

    // 武器尺寸随臂长等比增长（线性系数恒定，不设上限）
    final glyph = (arm.bandWidth * 0.52).clamp(22.0, double.maxFinite);
    final visHalf = arm.halfWidth * 0.72;

    final pic = JourneySprites.get(JourneySprites.weapon(game.weaponCode));
    for (var i = 0; i < game.bladeCount; i++) {
      final a = arm.angle + i * math.pi * 2 / game.bladeCount;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(a);

      // 径向光带（扇叶从容器延伸到外环）
      canvas.drawRect(
        Rect.fromLTWH(inner, -visHalf, outer - inner, visHalf * 2),
        Paint()..color = const Color(0x2FE8C470),
      );
      // 扇叶外端提亮（锋线）
      canvas.drawRect(
        Rect.fromLTWH(outer - 10, -visHalf, 10, visHalf * 2),
        Paint()..color = const Color(0x55F6E3B4),
      );

      if (pic != null) {
        canvas.translate(midR, 0);
        canvas.rotate(math.pi / 2);
        JourneySprites.draw(
          canvas,
          pic,
          dstRect: Rect.fromCenter(
            center: Offset.zero,
            width: glyph,
            height: glyph,
          ),
          srcWidth: 48,
          srcHeight: 48,
        );
      } else {
        // 精灵缺失回落：扇叶中点菱形锋刃（不退化为球/图标）
        canvas.translate(midR, 0);
        final path = Path()
          ..moveTo(0, -visHalf * 1.6)
          ..lineTo(visHalf * 1.6, 0)
          ..lineTo(0, visHalf * 1.6)
          ..lineTo(-visHalf * 1.6, 0)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFF6E3B4));
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFB98F3E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      canvas.restore();
    }
  }
}

/// 三选一候选池（维度槽口径）：
/// - 空槽且维度未入槽 → 「习得·X」（占 1 槽，Lv1）；
/// - 已入槽且未达上限 → 「X · 顿悟」（等级 +1，展示下一级效果）；
/// - 槽满：只出已有槽升级 + 通用成长项（不出现新维度）；
/// - 通用成长项常驻（伤害卡无条件入池，候选永不为空）。
List<JourneyUpgradeChoice> drawChoices(JourneyFlameGame game) {
  final pool = <JourneyUpgradeChoice>[];
  final defs = game.config?.slotDefMap() ?? _fallbackSlotDefs();
  final hasEmptySlot = game.weaponSlots.length < 6;

  // 维度卡：习得（空槽）或升级（未满级）
  for (final def in defs.values) {
    final held = game.weaponSlots.where((s) => s.code == def.code).toList();
    if (held.isEmpty) {
      if (hasEmptySlot) {
        pool.add(JourneyUpgradeChoice(
          JourneyUpgradeKind.slotLearn,
          code: def.code,
          title: '习得·${def.name}',
          desc: '${def.effectPerLevel}（占 1 槽 · Lv1）',
        ));
      }
    } else if (held.first.level < def.maxLevel) {
      pool.add(JourneyUpgradeChoice(
        JourneyUpgradeKind.slotUpgrade,
        code: def.code,
        title: '${def.name} · 顿悟',
        desc: '${def.effectPerLevel}（Lv${held.first.level + 1}/${def.maxLevel}）',
      ));
    }
  }

  // 被动加持卡
  if (game.passiveSlotCodes.length < 6) {
    for (final p in kJourneyPassiveEffects.entries) {
      if (game.passiveSlotCodes.contains(p.key)) continue;
      pool.add(_passiveGrantChoice(p.key, p.value.$1, p.value.$2));
    }
  }

  // 通用成长项（槽满后仍可选的基础属性增长）
  pool
    ..add(const JourneyUpgradeChoice(
      JourneyUpgradeKind.moveSpeed,
      title: '筋斗云气',
      desc: '移动速度 +9%',
    ))
    ..add(const JourneyUpgradeChoice(
      JourneyUpgradeKind.maxHp,
      title: '蟠桃益气',
      desc: '生命上限 +20 并回满同量',
    ))
    ..add(const JourneyUpgradeChoice(
      JourneyUpgradeKind.regen,
      title: '木灵回春',
      desc: '自动回复 +1/秒',
    ))
    ..add(const JourneyUpgradeChoice(
      JourneyUpgradeKind.pickupRange,
      title: '紫金磁引',
      desc: '拾取范围 +18',
    ));

  pool.shuffle();
  return pool.take(3).toList();
}

/// 内置维度定义兜底（远端 journey_weapon_slots 未就绪时）。
Map<String, JourneySlotDefModel> _fallbackSlotDefs() {
  return <String, JourneySlotDefModel>{
    for (final d in kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson))
      d.code: d,
  };
}

/// 被动加持效果文案（入槽即生效，效果实现见 _grantPassiveWeapon）。
const Map<String, (String, String)> kJourneyPassiveEffects =
    <String, (String, String)>{
  'jindou_cloud': ('筋斗云', '移动速度 +12%'),
  'pantao': ('蟠桃', '生命上限 +25，回复 +0.5/秒'),
  'renshen_guo': ('人参果', '经验获取 +25%'),
  'bishui_pearl': ('避水珠', '环绕转速 +15%'),
  'dingfeng_pearl': ('定风珠', '武器臂长 +18（受击区间变宽）'),
  'shelizi': ('舍利子', '武器伤害 +15%'),
};

JourneyUpgradeChoice _passiveGrantChoice(
  String code,
  String name,
  String desc,
) {
  return JourneyUpgradeChoice(
    JourneyUpgradeKind.passiveGrant,
    code: code,
    title: '加持·$name',
    desc: '$desc（占 1 被动槽）',
  );
}
