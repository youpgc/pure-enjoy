part of 'journey_flame_game.dart';

/// 怪物实体：驻守→追击→归位三态；精灵渲染 + 体型缩放。
/// 血量/速度/接触伤害走钳制后的生效乘区；妖王血量可传入独立的时间乘区，
/// 使其不随关卡难度放大，速度/接触伤害口径不变。
class JourneyMonsterComponent extends PositionComponent {
  JourneyMonsterComponent({
    required this.game,
    required this.model,
    required double buffMult,
    double? hpBuffMult,
    required super.position,
  })  : buffMult = clampJourneyBuff(game, buffMult),
        hp = model.baseHp * clampJourneyBuff(game, hpBuffMult ?? buffMult),
        maxHp = model.baseHp * clampJourneyBuff(game, hpBuffMult ?? buffMult),
        _speed = model.baseSpeed *
            (0.9 + clampJourneyBuff(game, buffMult) * 0.12),
        _contactDamageVal = model.contactDamage *
            (0.85 + clampJourneyBuff(game, buffMult) * 0.2) {
    // 妖王附加护甲（journey_monster_params.armor；缺省按能力兜底）
    bonusArmor = game.monsterParam(model.code, 'armor',
        model.abilityKey == 'unmovable'
            ? 30
            : model.abilityKey == 'iron_horn'
                ? 20
                : 0);
  }

  final JourneyFlameGame game;
  final JourneyMonsterModel model;
  final double buffMult;

  double hp;
  double maxHp;
  final double _speed;
  double _contactDamageVal;

  /// 妖王能力附加护甲（unmovable/iron_horn），受击按 armor/(armor+50) 减免。
  double bonusArmor = 0;

  double get _contactDamage =>
      _contactDamageVal * (_bloodFrenzy ? frenzyMult : 1.0);

  /// 血怒狂暴（九头虫）：血量 <frenzy_hp 比例时移速/接触伤害 frenzy_mult
  /// （journey_monster_params.frenzy_hp/frenzy_mult）。
  bool get _bloodFrenzy =>
      model.abilityKey == 'blood_frenzy' &&
      hp < maxHp * game.monsterParam(model.code, 'frenzy_hp', 0.4);

  double get frenzyMult =>
      game.monsterParam(model.code, 'frenzy_mult', 1.5);

  /// 移速倍率（journey_monster_params.move_mult；缺省按能力兜底，
  /// 狂暴再乘 frenzy_mult）。
  double get _speedMult {
    var mult = game.monsterParam(model.code, 'move_mult',
        switch (model.abilityKey) {
          'swift_wind' => 1.6,
          'roc_speed' => 1.8,
          _ => 1.0,
        });
    if (_bloodFrenzy) mult *= frenzyMult;
    return mult;
  }

  bool isDead = false;
  bool _aggro = false;

  /// 环绕法宝命中冷却：防旋转扫过同一怪连击叠伤。
  double orbHitCd = 0;

  /// 血条显示剩余时间：受击刷新，超时渐隐（妖王血条常显不受此控）。
  double _hpBarTimer = 0;

  /// 灼烧状态（武器灼烧维度命中点燃）：剩余秒数与每秒伤害。
  double burnRemaining = 0;
  double burnDps = 0;

  /// 定身剩余时间（幌金绳命中）：>0 时跳过移动，仍可受击/灼烧。
  double rootTimer = 0;

  /// 虚弱剩余时间（金刚琢命中）：>0 时接触伤害减半。
  double weakenTimer = 0;

  /// 紫金铃命中计数（扩展特效）：同一目标累计 3 次触发妖火爆炸。
  int lingHits = 0;

  /// 无尽妖潮所属波次（除尽推进制：该波怪全灭才刷下一波）。
  int endlessWave = 0;

  // ---- 妖王冲撞状态机（仅 model.isBoss，§7 MVP）----
  /// 冲撞相位：0 待机 / 1 蓄力 / 2 突进 / 3 收招。
  int _chargePhase = 0;
  double _chargeTimer = 0;
  Vector2 _chargeDir = Vector2.zero();
  double _chargeCd = 0;

  /// 点燃：刷新灼烧状态（重复命中刷新持续时间）。
  void ignite({required double burnDps, required double seconds}) {
    if (isDead) return;
    this.burnDps = burnDps;
    burnRemaining = seconds;
  }

  static const double _baseRadius = 18;
  double get radius => _baseRadius * model.sizeScale;

  // 驻守坐标（脱战后归位）
  late final Vector2 home = position.clone();

  /// 侦测半径：普通怪≈屏高 0.4 口径；妖王据点用更大触发圈。
  double get aggroRange => model.isBoss ? 420 : 260;

  /// 脱战半径 = 侦测 × 1.5。
  double get leashRange => aggroRange * 1.5;

  /// 脱战快速回血速率：每秒恢复 maxHp 的 40%（2.5 秒回满）。
  /// 口径：脱战（驻守/归位态）快速回满，再入战（追击态）立即停止；
  /// 妖王同规则——拉开距离即回满，惩罚拉脱打法。不触发死亡/掉落。
  static const double _regenPerSec = 0.4;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hpBarTimer > 0) {
      _hpBarTimer -= dt;
    }
    if (orbHitCd > 0) {
      orbHitCd -= dt;
    }
    if (isDead) return;

    // 离屏完全冻结（节点12 性能）：与玩家距离 >1400 时跳过索敌/移动/
    // 回血/灼烧结算，仅推进展示类计时（血条渐隐/命中冷却/定身）；
    // 灼烧离屏暂停（burnRemaining 不倒计时，回屏后继续结算伤害）。
    if ((game.player.position - position).length > 1400) {
      if (rootTimer > 0) {
        rootTimer -= dt;
      }
      if (weakenTimer > 0) {
        weakenTimer -= dt;
      }
      return;
    }

    // 灼烧掉血（武器灼烧维度）：持续期间每帧按 dps 扣血，计时归零熄灭
    if (burnRemaining > 0) {
      burnRemaining -= dt;
      takeDamage(burnDps * dt);
      if (isDead) return;
    }
    final player = game.player;
    final toPlayer = player.position - position;
    final dist = toPlayer.length;

    // 定身（幌金绳）：递减计时；期间只跳过移动，受击/灼烧照常
    final rooted = rootTimer > 0;
    if (rooted) {
      rootTimer -= dt;
    }
    // 虚弱（金刚琢）：递减计时，接触伤害在结算侧减半
    if (weakenTimer > 0) {
      weakenTimer -= dt;
    }

    // 三态两半径（妖王同规则：驻点待机→侦测追击→脱战归位据点）
    final wasAggro = _aggro;
    if (!_aggro && dist < aggroRange) {
      _aggro = true;
    } else if (_aggro && dist > leashRange) {
      _aggro = false;
    }
    // 妖王领地显隐（节点横幅）：进入侦测圈才亮大血条，脱战熄灭（变更才写）；
    // 进战瞬间按当前血量刷新比例（spawn/respawn 不再预写常显）
    if (model.isBoss && wasAggro != _aggro) {
      final hud = game.controller.hud;
      hud.bossEngaged.value = _aggro;
      if (_aggro) {
        hud.bossHpRatio.value = (hp / maxHp).clamp(0.0, 1.0);
        hud.bossMaxHp.value = maxHp.round();
        hud.bossHp.value = hp.clamp(0.0, maxHp).round();
      }
    }

    if (model.isBoss) {
      _updateCharge(dt, dist, toPlayer, rooted: rooted);
      // 妖王周期能力（追击态才走，定身中不放）
      if (_aggro && !rooted && model.abilityKey.isNotEmpty) {
        _tickBossAbility(dt, dist);
      }
    }

    if (_aggro) {
      if (_chargePhase == 0 && !rooted && dist > 1) {
        // 追击：直线朝玩家（分离力在 game 层统一做）
        position += toPlayer.normalized() * cappedMonsterSpeed(this) * dt;
      } else if (_chargePhase == 3 && !rooted && dist > 1) {
        // 收招：缓速归位追击
        position += toPlayer.normalized() * cappedMonsterSlowSpeed(this) * dt;
      }
      // 蓄力（1）原地预警；突进（2）位移由冲撞状态机锁定方向推进
    } else {
      // 驻守：向驻守点缓慢归位 + 小幅游荡
      final toHome = home - position;
      if (!rooted && toHome.length > 4) {
        position += toHome.normalized() * cappedMonsterSlowSpeed(this) * dt;
      }
      // 脱战快速回血：未追击玩家即回，上限 maxHp（进入追击态即停）
      if (hp < maxHp) {
        hp = math.min(hp + maxHp * _regenPerSec * dt, maxHp);
      }
    }
    // 禁止进入角色内圈：停在接触边界，随后统一钳回世界边界
    clampMonsterOutOfInnerCircle(this, player.position);
    clampMonsterToWorld(this, game.worldSize);
  }

  /// 妖王冲撞状态机：追击近距触发→蓄力 0.7s 预警→锁定方向突进 0.55s
  /// （速度 ×3.2，撞墙由世界边界钳制）→收招 1.0s 缓速→冷却 4.0s。
  void _updateCharge(double dt, double dist, Vector2 toPlayer,
      {required bool rooted}) {
    if (_chargeCd > 0) {
      _chargeCd -= dt;
    }
    switch (_chargePhase) {
      case 0:
        // 追击态近距触发（定身中不触发）
        if (_aggro && !rooted && _chargeCd <= 0 && dist < 340) {
          _chargePhase = 1;
          _chargeTimer = 0.7;
        }
        break;
      case 1:
        // 蓄力：原地不动（渲染红色预警圈闪烁）
        _chargeTimer -= dt;
        if (_chargeTimer <= 0) {
          _chargeDir = dist > 1 ? toPlayer.normalized() : Vector2(1, 0);
          _chargePhase = 2;
          _chargeTimer = 0.55;
        }
        break;
      case 2:
        // 突进：方向锁定，速度 ×3.2；定身期间位移跳过（幌金绳对妖王
        // 突进同样生效），突进时长照常消耗（root 中即原地停摆）
        _chargeTimer -= dt;
        if (!rooted) {
          position += _chargeDir * cappedMonsterSpeed(this) * 3.2 * dt;
        }
        if (_chargeTimer <= 0) {
          _chargePhase = 3;
          _chargeTimer = 1.0;
        }
        break;
      case 3:
        // 收招：缓速归位追击
        _chargeTimer -= dt;
        if (_chargeTimer <= 0) {
          _chargePhase = 0;
          // 金翅迅影（大鹏）：冲撞冷却减半（params.charge_cd 可调）
          _chargeCd = game.monsterParam(model.code, 'charge_cd',
              model.abilityKey == 'roc_speed' ? 2.0 : 4.0);
        }
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    // 局部坐标绘制（画布已平移到本组件位置），禁止叠加 position。
    final isBoss = model.isBoss;
    // 精灵优先（monster_<code>.svg，64 视箱）；失败回落几何占位；
    // 妖王渲染倍数高于普通怪，体型压制感明显
    final pic = JourneySprites.get(JourneySprites.monster(model.code));
    if (pic != null) {
      final size = radius * (isBoss ? 3.6 : 3.0);
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
          center: Offset(0, radius * 0.35),
          width: size,
          height: size,
        ),
        srcWidth: 64,
        srcHeight: 64,
      );
    } else {
      final isElite = model.isElite;
      final body = isBoss
          ? const Color(0xFF8E2F3C)
          : isElite
              ? const Color(0xFFA85C3A)
              : const Color(0xFF8A4A4A);
      canvas.drawCircle(Offset.zero, radius, Paint()..color = body);
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..color = isBoss
              ? const Color(0xFFE8C470)
              : const Color(0xFFFFFFFF).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isBoss ? 2.4 : 1.2,
      );
    }
    // 冲撞渲染（仅妖王）：蓄力=红色预警圈闪烁；突进=残影拖尾 2 层
    if (isBoss && _chargePhase == 1) {
      final blink = 0.2 + 0.3 * (0.5 + 0.5 * math.sin(_chargeTimer * 26));
      canvas.drawCircle(
        Offset.zero,
        radius + 18,
        Paint()..color = const Color(0xFFD4593F).withValues(alpha: blink),
      );
      canvas.drawCircle(
        Offset.zero,
        radius + 18,
        Paint()
          ..color =
              const Color(0xFFD4593F).withValues(alpha: (blink + 0.2).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
    if (isBoss && _chargePhase == 2) {
      for (var i = 1; i <= 2; i++) {
        canvas.drawCircle(
          Offset(-_chargeDir.x * 14 * i, -_chargeDir.y * 14 * i),
          radius * (1 - 0.18 * i),
          Paint()..color = const Color(0x668E2F3C),
        );
      }
    }
    // 血条口径：妖王常显；普通怪受击显示、2.5s 无新受击后 0.6s 渐隐
    if (hp < maxHp && (isBoss || _hpBarTimer > 0)) {
      final alpha = isBoss
          ? 1.0
          : (_hpBarTimer / 0.6).clamp(0.0, 1.0);
      final w = radius * 2.2;
      final rect = Rect.fromCenter(
        center: Offset(0, -radius - 9),
        width: w,
        height: 4,
      );
      canvas.drawRect(rect, Paint()..color = const Color(0x66000000));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, w * (hp / maxHp), 4),
        Paint()
          ..color = (isBoss
                  ? const Color(0xFFE8C470)
                  : const Color(0xFFD4593F))
              .withValues(alpha: alpha),
      );
    }
  }

  /// 多场妖王战的逐场伤害增强（+25%/场，血量由 buffMult 承担）。
  void scaleStageDamage(int stage) {
    if (stage <= 0) return;
    _contactDamageVal = _contactDamageVal * (1.0 + stage * 0.25);
  }

  void takeDamage(double amount) {
    if (isDead) return;
    // 妖王附加护甲（不动如山/金刚琢护体）：与玩家护甲同曲线减免
    if (bonusArmor > 0) {
      amount *= 1 - JourneyDamageTickMixin.armorReductionRatio(bonusArmor);
    }
    hp -= amount;
    _hpBarTimer = 2.5;
    // 分魂化形（白骨精）：血量首次跌破 50% 分裂 2 只妖卫（每场一次）
    if (model.abilityKey == 'bone_split' &&
        !_splitDone &&
        hp > 0 &&
        hp < maxHp * 0.5) {
      _splitDone = true;
      _spawnBoneSplinters();
    }
    // 妖王大血条（节点11）：差值 >0.005 才写，防高频刷 notifier
    if (model.isBoss) {
      final ratio = (hp / maxHp).clamp(0.0, 1.0);
      final hud = game.controller.hud;
      if ((hud.bossHpRatio.value - ratio).abs() > 0.005) {
        hud.bossHpRatio.value = ratio;
      }
      final hpNow = hp.clamp(0.0, maxHp).round();
      if (hud.bossHp.value != hpNow) hud.bossHp.value = hpNow;
    }
    if (hp <= 0) {
      isDead = true;
      game.onMonsterKilled(this);
      removeFromParent();
    }
  }

  bool _splitDone = false;

  /// 白骨妖卫 ×2：白骨精分魂（精英属性，血量 40% buff，落位本体两侧）。
  void _spawnBoneSplinters() {
    final pool = game.pool
        .where((m) => m.code == 'baigu_yaozu')
        .toList();
    if (pool.isEmpty) return;
    final model = pool.first;
    for (var i = 0; i < 2; i++) {
      final comp = JourneyMonsterComponent(
        game: game,
        model: model,
        buffMult: buffMult * 0.4,
        position: position +
            Vector2(i == 0 ? -46 : 46, 0),
      );
      // 继承本体波次标记：无尽妖潮除尽推进不漏分裂怪
      comp.endlessWave = endlessWave;
      game.monsters.add(comp);
      game.world.add(comp);
    }
    game.spawnFloatText(
      position + Vector2(0, -radius - 14),
      '分魂化形！',
      const Color(0xFFB07CD4),
    );
  }

  /// 妖王周期能力（swift_wind 阵风 / samadhi_fire 火圈 / gourd_pull 摄魂）：
  /// 各自独立计时，进战（追击态）才走，暂停时随引擎冻结。
  double _abilityTimer = 0;

  void _tickBossAbility(double dt, double dist) {
    _abilityTimer += dt;
    final code = model.abilityKey;
    final period = switch (code) {
      'swift_wind' => game.monsterParam(model.code, 'wind_period', 8.0),
      'samadhi_fire' => game.monsterParam(model.code, 'fire_period', 6.0),
      'gourd_pull' => game.monsterParam(model.code, 'pull_period', 10.0),
      _ => 0.0,
    };
    if (period <= 0 || _abilityTimer < period) return;
    final player = game.player;
    switch (code) {
      case 'swift_wind':
        // 三昧神风：阵风把玩家吹离 200px（世界边界钳制）
        final dir = (player.position - position);
        final len = dir.length;
        if (len > 1) {
          player.position += dir.normalized() *
              game.monsterParam(model.code, 'wind_push', 200);
          player.position.x =
              player.position.x.clamp(28.0, game.worldSize - 28);
          player.position.y =
              player.position.y.clamp(28.0, game.worldSize - 28);
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '三昧神风！',
            const Color(0xFFD4A73F),
          );
        }
        _abilityTimer = 0;
        break;
      case 'samadhi_fire':
        // 三昧真火：火圈 AOE——玩家在射程内受接触伤害比例（过护甲）
        final fireRange = game.monsterParam(model.code, 'fire_range', 250.0);
        final fireRatio = game.monsterParam(model.code, 'fire_ratio', 0.8);
        if (dist <= fireRange) {
          final raw = _contactDamage * fireRatio;
          player.takeDamage(
            raw * (1 - JourneyDamageTickMixin.armorReductionRatio(player.armor)),
          );
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '三昧真火',
            const Color(0xFFD4593F),
          );
        }
        game.fxLayer.spawnRing(position, fireRange);
        _abilityTimer = 0;
        break;
      case 'gourd_pull':
        // 紫金摄魂：把玩家拉向自身（距离可配，世界边界钳制）
        final dir = position - player.position;
        final len = dir.length;
        if (len > 1) {
          player.position += dir.normalized() *
              game.monsterParam(model.code, 'pull_dist', 180);
          player.position.x =
              player.position.x.clamp(28.0, game.worldSize - 28);
          player.position.y =
              player.position.y.clamp(28.0, game.worldSize - 28);
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '紫金摄魂',
            const Color(0xFFB07CD4),
          );
        }
        _abilityTimer = 0;
        break;
    }
  }
}
