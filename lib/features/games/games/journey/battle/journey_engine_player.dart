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

  /// 蟠桃生命上限加成比例，未获得时为 0。局内固定额生命成长按
  /// (1 + 此比例) 放大，使蟠桃加成随角色生命成长同步提升；百分比成长
  /// 直接按当前上限结算，已含蟠桃部分，不重复放大。
  double pantaoHpRatio = 0;
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

  /// 妖王冲撞击退：命中登记方向与剩余距离，逐帧推进；期间摇杆仍可操作，
  /// 击退位移不计入西行里程。
  static const double _chargeKnockDuration = 0.25;
  Vector2 _chargeKnockDir = Vector2.zero();
  double _chargeKnockLeft = 0;
  double _chargeKnockSpeed = 0;

  /// 妖王技能牵引（紫金摄魂拉近/三昧神风推离）：命中登记方向与总距离，
  /// 逐帧推进给出可见位移过程；速度钳在玩家移速之下，且与摇杆同向时按
  /// 差额封顶不叠加（避免异常加速冲向妖王），反向摇杆仍可净挣脱（避免
  /// 被拉到贴脸连刀）。期间摇杆仍可操作，牵引位移不计入里程；与冲撞
  /// 队列各自独立，同帧并存不互相覆盖。
  Vector2 _skillShiftDir = Vector2.zero();
  double _skillShiftLeft = 0;
  double _skillShiftSpeed = 0;

  /// 牵引速度上限占玩家自身移速的比例：必须小于 1，反向摇杆才有净速度
  /// 挣脱；留余量使多妖王混战下仍有可反应的脱离窗口。
  static const double _skillShiftSpeedRatio = 0.8;

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
    final stick = game.controller.input.vector;
    if (rootTimer > 0) {
      rootTimer -= dt;
    } else if (stick.distanceSquared > 0.001) {
      position += Vector2(stick.dx, stick.dy) *
          game.baseSpeed *
          game.moveSpeedAmp *
          dt;
      facing = Vector2(stick.dx, stick.dy)..normalize();
    }
    // 妖王冲撞位移：撞开角色，随后与其他推离一起钳界；与摇杆同向时按
    // 差额封顶（净速度不超过击退速度），避免同向叠加把角色额外加速撞飞
    var knockStep = 0.0;
    if (_chargeKnockLeft > 0) {
      final activeAlong = rootTimer > 0
          ? 0.0
          : (stick.dx * _chargeKnockDir.x + stick.dy * _chargeKnockDir.y) *
              game.baseSpeed *
              game.moveSpeedAmp;
      final desired = activeAlong > 0
          ? math.max(0.0, _chargeKnockSpeed - activeAlong)
          : _chargeKnockSpeed;
      knockStep = math.min(_chargeKnockLeft, desired * dt);
      position += _chargeKnockDir * knockStep;
      _chargeKnockLeft -= knockStep;
    }
    // 妖王技能牵引位移：摄魂拉近/神风推离逐帧推进，使位移动画可见、
    // 玩家有时间反向挣脱，而非单帧闪现。牵引不与摇杆无条件叠加：同向时
    // 按差额补足到牵引速度（消除加速且斜向输入不削弱拉近），静止/反向
    // 用固定牵引额（不放大，保留挣脱窗口）。
    var skillShiftStep = 0.0;
    if (_skillShiftLeft > 0) {
      // 本帧玩家沿牵引方向的主动速度；定身期无摇杆按 0 处理
      final activeAlong = rootTimer > 0
          ? 0.0
          : (stick.dx * _skillShiftDir.x + stick.dy * _skillShiftDir.y) *
              game.baseSpeed *
              game.moveSpeedAmp;
      final desired = activeAlong > 0
          ? math.max(0.0, _skillShiftSpeed - activeAlong)
          : _skillShiftSpeed;
      skillShiftStep = math.min(_skillShiftLeft, desired * dt);
      position += _skillShiftDir * skillShiftStep;
      _skillShiftLeft -= skillShiftStep;
    }
    position.x = position.x
        .clamp(_radius + 8, game.worldSize - _radius - 8);
    position.y = position.y
        .clamp(_radius + 8, game.worldSize - _radius - 8);

    // 怪物占位：玩家不可穿过/挤开怪物；冲撞中的妖王例外（由击退处理）
    _blockByMonsters();

    // 参照物圆碰撞推离（unbreakable + 未破坏 breakable）
    _pushOutOfMapObjects();

    // 西行里程：按本帧净位移累计（挂机/定身/撞墙推离/冲撞击退/技能牵引不算）；
    // 无妖主线章回以此替代纯时长作为通关口径（1 里=25 世界单位）
    game.traveledUnits += ((position - prevPos) -
            _chargeKnockDir * knockStep -
            _skillShiftDir * skillShiftStep)
        .length;

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

    // 金身佛光（tang 特殊能力）：按参数周期回复最大生命比例（禁疗期间失效）
    if (game.hasAbility('tang') && healBlockTimer <= 0) {
      game._jinshenTimer += dt;
      if (game._jinshenTimer >=
          game.battleNum('ability', 'tang_heal_period_sec', 10)) {
        game._jinshenTimer = 0;
        if (hp < maxHp) {
          final amount = maxHp *
              game.battleNum('ability', 'tang_heal_ratio', 0.08);
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

  /// 怪物占位：玩家进入怪物接触圈时只推回自身，不挤开怪物（接触边界
  /// 保留重叠量供节拍伤害结算）。多怪叠压时两轮解算，沿法线自然滑动；
  /// 冲撞突进中的妖王不在此阻挡，由冲撞击退统一处理。
  void _blockByMonsters() {
    for (var pass = 0; pass < 2; pass++) {
      for (final m in game.monsters) {
        if (m.isDead || m.isCharging) continue;
        final d = position - m.position;
        final minDist = m.radius + _radius - kJourneyContactOverlap;
        final len = d.length;
        if (len >= minDist) continue;
        position = len > 0.01
            ? m.position + d * (minDist / len)
            : m.position + Vector2(minDist, 0);
      }
    }
    position.x = position.x
        .clamp(_radius + 8, game.worldSize - _radius - 8);
    position.y = position.y
        .clamp(_radius + 8, game.worldSize - _radius - 8);
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
    // 罗盘里数直接用实际距离（绕路时可能大于出生基准；接近度在
    // 超基准时钳 0，反推距离会恒等于基准值不再更新）
    if ((to.length - hud.bossDistWorld.value).abs() > 2) {
      hud.bossDistWorld.value = to.length;
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

  /// 妖王冲撞命中：沿冲撞方向把角色撞开，距离逐帧推进（不瞬移）；
  /// 与摇杆同向时按差额封顶，避免叠加加速。无敌帧期间免疫冲撞击退，
  /// 与免疫伤害口径一致。
  void applyChargeKnock(Vector2 dir, double distance) {
    if (invulnTimer > 0 || distance <= 0 || dir.length < 0.001) return;
    _chargeKnockDir = dir.normalized();
    _chargeKnockSpeed = distance / _chargeKnockDuration;
    _chargeKnockLeft = distance;
  }

  /// 妖王技能牵引命中：沿 [dir] 把角色渐进推移 [distance]（摄魂拉向妖王、
  /// 神风推离妖王）。[duration] 仅为期望时长，实际速度钳到玩家移速的
  /// [_skillShiftSpeedRatio]，且玩家主动同向移动时按差额封顶（不叠加
  /// 加速），反向摇杆可净挣脱；连续命中重置为单次距离、方向取最新来源，
  /// 控制时长有界，多妖王混战不会叠加成长期锁定。无敌帧只挡新命中，
  /// 不中断已登记的位移。
  void applySkillShift(Vector2 dir, double distance, double duration) {
    if (invulnTimer > 0 ||
        distance <= 0 ||
        dir.length < 0.001 ||
        duration <= 0) {
      return;
    }
    // 速度上限取玩家当前移速的一定比例：玩家移速随升级/筋斗云增长，
    // 牵引上限同步水涨船高，但始终低于玩家，反向摇杆始终能净挣脱。
    final escapeSpeed =
        game.baseSpeed * game.moveSpeedAmp * _skillShiftSpeedRatio;
    _skillShiftSpeed = math.min(distance / duration, escapeSpeed);
    _skillShiftDir = dir.normalized();
    // 连续命中重置为单次距离（方向取最新）而非累加，使控制时长有界：
    // 多妖王混战下不会叠加成长期锁定，玩家总能在单段位移后挣脱。
    _skillShiftLeft = distance;
  }

  /// 清除未走完的强制位移（还魂复活时调用）：死亡瞬间正在进行的牵引/
  /// 冲撞被暂停冻结，复活后若继续推进会出现「幽灵位移」把刚复活的角色
  /// 拉走。复活后重新受击会再次登记，无需保留本局残留。
  void clearForcedDisplacement() {
    _chargeKnockLeft = 0;
    _skillShiftLeft = 0;
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
