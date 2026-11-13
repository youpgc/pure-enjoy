part of 'journey_flame_game.dart';

/// 玩家（鎏金圆 + 朝向指示；环绕法宝由 JourneyOrbitWeapons 独立渲染）。
class JourneyPlayerComponent extends PositionComponent {
  JourneyPlayerComponent({
    required this.game,
    required super.position,
    this.maxHp = 100,
  }) : hp = maxHp;

  final JourneyFlameGame game;

  double maxHp;
  double hp;
  double regen = 0;
  double armor = 0;
  double pickupRange = 80;
  double _regenTimer = 0;
  double _compassLogTimer = 0;

  /// 无敌剩余时间（三根毫毛免死触发后 1.5s）：>0 时免疫接触伤害。
  double invulnTimer = 0;

  /// 玉净瓶甘露（扩展被动）：周期回血计时（每 20s 回 20% 生命）。
  double _ganluTimer = 0;

  /// 定身剩余时间（百眼魔君金光缚身）：>0 时摇杆移动失效。
  double rootTimer = 0;

  /// 禁疗剩余时间（蝎子精倒马毒桩）：>0 时治疗与回复失效。
  double healBlockTimer = 0;

  static const double _radius = 20;

  /// 基础移速（世界单位/秒）：无妖主线章回西行里程目标的换算基准。
  static const double baseSpeed = 240;

  Vector2 facing = Vector2(0, -1);

  @override
  void update(double dt) {
    super.update(dt);
    if (game._ended) return;

    // 西行里程基准点：本帧位移/推离全部落定前记录位置，帧尾取净位移
    final prevPos = position.clone();

    // 摇杆驱动（屏幕向量直接映射世界向量，全向自由移动）；
    // 金光缚身定身期间跳过移动
    if (rootTimer > 0) {
      rootTimer -= dt;
    } else {
      final v = game.controller.input.vector;
      if (v.distanceSquared > 0.001) {
        position += Vector2(v.dx, v.dy) * baseSpeed * game.moveSpeedAmp * dt;
        facing = Vector2(v.dx, v.dy)..normalize();
      }
    }
    position.x = position.x
        .clamp(_radius + 8, game.worldSize - _radius - 8);
    position.y = position.y
        .clamp(_radius + 8, game.worldSize - _radius - 8);

    // 参照物圆碰撞推离（unbreakable + 未破坏 breakable）
    _pushOutOfMapObjects();

    // 西行里程：按本帧净位移累计（挂机/定身/撞墙推离不产生里程）；
    // 无妖主线章回以此替代纯时长作为通关口径（1 里=25 世界单位）
    game.traveledUnits += (position - prevPos).length;

    // 木系自动回复（倒马毒桩禁疗期间失效）
    if (regen > 0 && healBlockTimer <= 0) {
      _regenTimer += dt;
      if (_regenTimer >= 1) {
        _regenTimer -= 1;
        if (hp < maxHp) {
          hp = (hp + regen).clamp(0.0, maxHp);
          game.onPlayerHpChanged();
        }
      }
    }
    if (healBlockTimer > 0) {
      healBlockTimer -= dt;
    }

    // 金身佛光（tang 特殊能力）：每 10s 回复 8% 最大生命（禁疗期间失效）
    if (game.hasAbility('tang') && healBlockTimer <= 0) {
      game._jinshenTimer += dt;
      if (game._jinshenTimer >= 10) {
        game._jinshenTimer = 0;
        if (hp < maxHp) {
          final amount = maxHp * 0.08;
          hp = (hp + amount).clamp(0.0, maxHp);
          game.onPlayerHpChanged();
          game.spawnFloatText(
            position + Vector2(0, -36),
            '金身佛光 +${amount.round()}',
            const Color(0xFFF6E3B4),
          );
        }
      }
    }

    // 无敌帧（三根毫毛）：递减计时，期间免疫接触伤害
    if (invulnTimer > 0) {
      invulnTimer -= dt;
    }

    // 玉净瓶甘露（扩展被动）：每 period 秒自动回复 heal 比例生命
    // （params.period/params.heal；禁疗期间失效）
    if (game.passiveSlotCodes.contains('yujing_ping') &&
        healBlockTimer <= 0) {
      _ganluTimer += dt;
      if (_ganluTimer >= game.weaponParam('yujing_ping', 'period', 20)) {
        _ganluTimer = 0;
        if (hp < maxHp) {
          final amount = maxHp * game.weaponParam('yujing_ping', 'heal', 0.20);
          hp = (hp + amount).clamp(0.0, maxHp);
          game.onPlayerHpChanged();
          game.spawnFloatText(
            position + Vector2(0, -36),
            '甘露 +${amount.round()}',
            const Color(0xFF9AD5C3),
          );
        }
      }
    }

    _reportCompass();
  }

  /// 参照物圆碰撞推离：玩家与实体参照物重叠时被推出
  /// o.radius+玩家半径（线性遍历，参照物总量小；chest_point/milestone/
  /// waypoint 等非实体参照物不阻挡）。
  void _pushOutOfMapObjects() {
    final objs = game.runtime.mapObjects;
    if (objs.isEmpty) return;
    for (var i = 0; i < objs.length; i++) {
      if (!game.isMapObjectSolid(i)) continue;
      final o = objs[i];
      final toObj = Vector2(o.x, o.y);
      final d = position - toObj;
      final len = d.length;
      final minDist = o.radius + _radius;
      if (len >= minDist) continue;
      if (len < 0.01) {
        // 完全重叠：沿 x 轴正向推出
        position = toObj + Vector2(minDist, 0);
      } else {
        position = toObj + d.normalized() * minDist;
      }
    }
    position.x = position.x
        .clamp(_radius + 8, game.worldSize - _radius - 8);
    position.y = position.y
        .clamp(_radius + 8, game.worldSize - _radius - 8);
  }

  /// 妖王罗盘上报（低频去重）：bearing=指向据点的世界角，progress=接近度
  /// （0=刚出发，1=已抵达据点圈）。
  void _reportCompass() {
    final boss = game.boss;
    if (boss == null) {
      if (_compassLogTimer <= 0) {
        _compassLogTimer = 3;
        debugPrint('罗盘: boss=null level=${game.level.levelNo}');
      }
      _compassLogTimer -= 0.016;
      return;
    }
    final hud = game.controller.hud;
    final to = boss.position - position;
    if (_compassLogTimer <= 0) {
      _compassLogTimer = 3;
      debugPrint('罗盘: to=${to.length.toStringAsFixed(0)} '
          'start=${game.bossStartDist.toStringAsFixed(0)} '
          'boss=${boss.position} player=$position');
    }
    _compassLogTimer -= 0.016;
    final brg = math.atan2(to.y, to.x);
    var d = brg - hud.bearing.value;
    if (d > math.pi) d -= math.pi * 2;
    if (d < -math.pi) d += math.pi * 2;
    if (d.abs() > 0.03) {
      hud.bearing.value = brg;
    }

    final ratio = 1 - to.length / game.bossStartDist;
    final near = ratio.clamp(0.0, 1.0);
    if ((near - hud.progress.value).abs() > 0.005) {
      hud.progress.value = near;
    }
  }

  @override
  void render(Canvas canvas) {
    // 注意：PositionComponent 的 render 画布已平移到本组件局部坐标，
    // 绘制必须围绕原点，禁止再叠加 position（双重偏移会画出屏外）。
    // 角色立绘优先（char_<code>.svg）；失败回落几何
    final pic = JourneySprites.get(JourneySprites.character(game.character.code));
    if (pic != null) {
      const size = 76.0;
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
          center: const Offset(0, -14),
          width: size * 0.74,
          height: size,
        ),
        srcWidth: 220,
        srcHeight: 300,
      );
      return;
    }
    // 底环
    canvas.drawCircle(
      Offset.zero,
      _radius + 4,
      Paint()
        ..color = const Color(0x33E8C470)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 本体
    canvas.drawCircle(
      Offset.zero,
      _radius,
      Paint()..color = const Color(0xFFF6E3B4),
    );
    canvas.drawCircle(
      Offset.zero,
      _radius,
      Paint()
        ..color = const Color(0xFFB98F3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 朝向点
    canvas.drawCircle(
      (facing * _radius * 0.62).toOffset(),
      4,
      Paint()..color = const Color(0xFFD4593F),
    );
  }

  void takeDamage(double amount) {
    if (hp <= 0) return;
    // 无敌帧（三根毫毛免死窗口）：免疫接触伤害
    if (invulnTimer > 0) return;
    hp = (hp - amount).clamp(0.0, maxHp);
    // 有效受击：屏幕边框呼吸灯按脉冲重启一次泛红提示
    game.controller.hud.hitPulse.value++;
    // 铜皮铁骨（bajie 特殊能力）：受击后 3s 内进入减伤/击退强化窗口
    if (game.hasAbility('bajie')) {
      game._bajieGuard = 3;
    }
    game.onPlayerHpChanged();
  }

  void heal(double amount) {
    // 倒马毒桩禁疗期间治疗失效
    if (healBlockTimer > 0) return;
    hp = (hp + amount).clamp(0.0, maxHp);
    game.onPlayerHpChanged();
  }
}
