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
  double get damageAmp;
  set damageAmp(double value);
  double get critRate;
  set critRate(double value);
  double get critDamage;
  set critDamage(double value);
  double get maxArmDiameter;
  double slotValue(String code, double fallback);
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
      case 'crit_rate': // 暴击率：每级 +（value_per_level；引擎钳 ≤60%）
        critRate = (critRate + slotValue('crit_rate', 0.025) * delta)
            .clamp(0.0, 0.60);
        break;
      case 'crit_damage': // 暴击伤害：每级 +（value_per_level；钳 ≤+100%）
        critDamage = (critDamage + slotValue('crit_damage', 0.06) * delta)
            .clamp(1.0, 2.0);
        break;
      case 'armor': // 护甲：每级 +（value_per_level；减伤曲线钳制在伤害侧）
        player.armor += slotValue('armor', 1.5) * delta;
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

    // 空间哈希（节点12）：先取玩家附近候选（外环 + 最大怪半径 + 余量）
    // 再扇形判定，避免 monsterCap 全量遍历
    final candidates = game.spatialGrid.queryRange(
      center,
      arm.outerRadius + 120 + 40,
    );
    for (final m in candidates) {
      if (m.isDead || m.orbHitCd > 0) continue;
      final toM = m.position - center;
      final dist = toM.length;
      if (dist < 1) continue;

      // 无内圈豁免：外环可及（外缘重叠）即参与扇形判定，
      // 内圈贴身经过同样造成全额伤害
      if (dist - m.radius > arm.outerRadius) continue;

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
      _hitMonster(game, m, arm.damage * game.damageMult,
          pierceLv: pierceLv,
          knockLv: knockLv,
          lifestealLv: lifestealLv,
          burnLv: burnLv,
          toM: toM);
      m.orbHitCd = 0.3;
    }

    // 参照物扫掠：可击破参照物被扇叶命中扣血（无暴击，0.3s/个冷却）
    _sweepMapObjects(game, arm, dt);
  }

  /// 命中结算：暴击判定 → 穿刺乘成 → 触发型法宝（捆仙索定身/暴击雷引
  /// 闪电链）→ 吸血回复 → 击退 → 灼烧点燃。
  /// 暴击/特效只弹关键浮动文字（普通命中不弹字，防刷屏）。
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
    // 伏魔重击（shaseng 特殊能力）：充能就绪的下一次命中 3 倍伤害，
    // 并定身该怪 260px 内所有怪 1s（浮动字提示）
    if (game.hasAbility('shaseng') && game._fumoCharged) {
      game._fumoCharged = false;
      game._fumoTimer = 0;
      dmg *= 3;
      for (final other in game.monsters) {
        if (!other.isDead &&
            (other.position - m.position).length <= 260) {
          other.rootTimer = 1;
        }
      }
      game.spawnFloatText(
        m.position + Vector2(0, -m.radius - 14),
        '伏魔重击',
        const Color(0xFFD4593F),
      );
    }
    if (pierceLv > 0) dmg *= 1.0 + 0.15 * pierceLv;
    // 火眼金睛（扩展被动）：精英与妖王受伤 +（params.elite）
    if ((m.model.isBoss || m.model.isElite) &&
        game.passiveSlotCodes.contains('huoyan_jingjing')) {
      dmg *= game.weaponParam('huoyan_jingjing', 'elite', 1.2);
    }
    // 暴击判定（§8）：率与倍率见主类字段
    final isCrit = game.critRate > 0 && game.rng.nextDouble() < game.critRate;
    if (isCrit) {
      dmg *= game.critDamage;
    }
    m.takeDamage(dmg);
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
    }
    // 捆仙索：命中 chance 概率定身 root 秒（params.chance/params.root）
    if (!m.isDead &&
        game.effectWeapons.contains('kunxian_rope') &&
        game.rng.nextDouble() <
            game.weaponParam('kunxian_rope', 'chance', 0.12)) {
      m.rootTimer = game.weaponParam('kunxian_rope', 'root', 1.5);
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
      // 吸血：每级回复武器伤害 value_per_level 比例，钳 ≤100%
      game.player.heal(
        damage * (game.slotValue('lifesteal', 0.12) * lifestealLv).clamp(0.0, 1.0),
      );
    }
    if (knockLv > 0) {
      var kb = game.slotValue('knockback', 16) * knockLv;
      // 铜皮铁骨（bajie 特殊能力）：受击窗口内击退强度 +50%
      if (game._bajieGuard > 0) kb *= 1.5;
      // 不动如山（牛魔王）：抗击退（journey_monster_params.knock_resist）
      kb *= 1 -
          game.monsterParam(
            m.model.code,
            'knock_resist',
            m.model.abilityKey == 'unmovable' ? 0.8 : 0,
          );
      m.position += toM.normalized() * kb;
    }
    if (burnLv > 0) {
      // 灼烧：每秒 value_per_level 点，持续 2 秒（时长为引擎机制常量）
      m.ignite(burnDps: game.slotValue('burn', 8.0) * burnLv, seconds: 2);
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
    final range = game.weaponParam('baoji_thunder', 'range', 260);
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
    final damage =
        arm.damage * game.damageMult * game.weaponParam('zijin_ling', 'damage', 0.6);
    final range = game.weaponParam('zijin_ling', 'range', 120);
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

  /// 参照物扫掠判定（§7/§2）：可击破参照物中心距玩家 ≤ 外环+radius
  /// （无内圈豁免）且角度落在扇叶角 ± atan(半宽+radius, dist)
  /// → 扣 hp（arm.damage×乘区，无暴击）；per-object 0.3s 冷却保证 hp
  /// 「累积破坏」口径成立（无冷却时高伤一帧即碎）。
  void _sweepMapObjects(
    JourneyFlameGame game,
    JourneyWeaponArm arm,
    double dt,
  ) {
    final cd = game._mapObjHitCd;
    if (cd.isNotEmpty) {
      final expired = <int>[];
      cd.forEach((k, v) {
        if (v - dt <= 0) {
          expired.add(k);
        } else {
          cd[k] = v - dt;
        }
      });
      for (final k in expired) {
        cd.remove(k);
      }
    }
    final center = game.player.position;
    final objs = game.runtime.mapObjects;
    for (var i = 0; i < objs.length; i++) {
      if (!game.isMapObjectBreakableAlive(i)) continue;
      if (cd.containsKey(i)) continue;
      final o = objs[i];
      final toO = Vector2(o.x, o.y) - center;
      final dist = toO.length;
      // 无内圈豁免：外环可及即参与扇形判定
      if (dist > arm.outerRadius + o.radius || dist < 1) {
        continue;
      }
      final objAngle = math.atan2(toO.y, toO.x);
      final angularHalf = math.atan2(arm.halfWidth + o.radius, dist);
      var hit = false;
      for (var b = 0; b < game.bladeCount; b++) {
        final a = arm.angle + b * math.pi * 2 / game.bladeCount;
        var diff = (objAngle - a) % (math.pi * 2);
        if (diff > math.pi) diff -= math.pi * 2;
        if (diff.abs() <= angularHalf) {
          hit = true;
          break;
        }
      }
      if (!hit) continue;
      game.damageMapObject(i, arm.damage * game.damageMult);
      game._mapObjHitCd[i] = 0.3;
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
    // 身外身法（wukong 特殊能力）：增益期间转速额外 +30%
    if (game._shenfenTimer > 0) speed += 0.3;
    // 最终角速度统一钳 5 圈/秒（10π rad/s）：speedBase×乘区超过不再增加；
    // 方向由局外设置注入（spinDirection：1=顺时针，-1=逆时针）
    arm.angle += game.spinDirection *
        (arm.speedBase * speed).clamp(0.0, 10 * math.pi) *
        dt;
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

    // 武器长度=臂长（内缘→外缘径向跨度），宽高同系数等比放大：
    // 精灵方形容器随臂长整体缩放，臂长增长武器随之变长变宽
    final glyph = arm.bandWidth;
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

/// 西游扩展特效触发（金刚琢/阴阳二气瓶）：周期结算，目标取玩家 900 内
/// 最近存活怪；对局暂停时随引擎冻结（挂在伤害节拍前每帧推进）。
extension JourneyTriggerWeapons on JourneyFlameGame {
  /// 金刚琢：每 12s 套取最近怪，受 250% 武器伤害且接触伤害减半 5s；
  /// 阴阳二气瓶：每 18s 吸纳最近怪，定身 2.5s 并每秒受 40% 武器伤害。
  /// 无目标时约 1s 后重试（计时回退到阈值前 1s，不白等一整轮）。
  void updateTriggerWeapons(double dt) {
    if (_ended) return;
    final arm = weaponArm;
    if (arm == null) return;
    final hasZhuo = effectWeapons.contains('jinggang_zhuo');
    final hasPing = effectWeapons.contains('yinyang_ping');
    if (!hasZhuo && !hasPing) return;

    JourneyMonsterComponent? nearest;
    var best = 900.0;
    for (final m in monsters) {
      if (m.isDead) continue;
      final d = (m.position - player.position).length;
      if (d < best) {
        best = d;
        nearest = m;
      }
    }

    if (hasZhuo) {
      _zhuoTimer += dt;
      if (_zhuoTimer >= weaponParam('jinggang_zhuo', 'period', 12)) {
        final target = nearest;
        if (target != null && !target.isDead) {
          _zhuoTimer = 0;
          target.takeDamage(
            arm.damage *
                damageMult *
                weaponParam('jinggang_zhuo', 'damage', 2.5),
          );
          target.weakenTimer = weaponParam('jinggang_zhuo', 'weak', 5);
          fxLayer.spawnRing(target.position, 26);
          spawnFloatText(
            target.position + Vector2(0, -target.radius - 14),
            '金刚琢！',
            const Color(0xFFE8C470),
          );
        } else {
          _zhuoTimer = weaponParam('jinggang_zhuo', 'period', 12) - 1;
        }
      }
    }

    if (hasPing) {
      _pingTimer += dt;
      if (_pingTimer >= weaponParam('yinyang_ping', 'period', 18)) {
        final target = nearest;
        if (target != null && !target.isDead) {
          _pingTimer = 0;
          target.rootTimer = weaponParam('yinyang_ping', 'root', 2.5);
          target.ignite(
            burnDps: arm.damage *
                damageMult *
                weaponParam('yinyang_ping', 'burn', 0.4),
            seconds: weaponParam('yinyang_ping', 'root', 2.5),
          );
          fxLayer.spawnRing(target.position, 30);
          spawnFloatText(
            target.position + Vector2(0, -target.radius - 14),
            '入瓶！',
            const Color(0xFF9AD5C3),
          );
        } else {
          _pingTimer = weaponParam('yinyang_ping', 'period', 18) - 1;
        }
      }
    }
  }
}

