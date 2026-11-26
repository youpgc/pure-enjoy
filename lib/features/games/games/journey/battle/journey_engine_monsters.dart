part of 'journey_flame_game.dart';

/// 怪物实体：驻守→追击→归位三态；血量/速度/接触伤害走钳制后的生效乘区；
/// 妖王血量可传入独立时间乘区，不随关卡难度放大，速度/接触伤害口径不变。
class JourneyMonsterComponent extends PositionComponent
    with JourneyKnockbackMixin, JourneyBurnMixin, JourneyBossAbilityMixin, JourneySlotStatusMixin {
  JourneyMonsterComponent({
    required this.game,
    required this.model,
    required double buffMult,
    double? hpBuffMult,
    bool bossLvHpTerm = true,
    required super.position,
  })  : buffMult = clampJourneyBuff(game, buffMult),
        hp = model.baseHp *
            journeyMonsterHpMult(
              game,
              model,
              buffMult: buffMult,
              hpBuffMult: hpBuffMult,
              bossLvHpTerm: bossLvHpTerm,
            ),
        maxHp = model.baseHp *
            journeyMonsterHpMult(
              game,
              model,
              buffMult: buffMult,
              hpBuffMult: hpBuffMult,
              bossLvHpTerm: bossLvHpTerm,
            ),
        _speed = model.baseSpeed *
            (game.battleNum('monster', 'speed_base', 0.9) +
                clampJourneyBuff(game, buffMult) *
                    game.battleNum('monster', 'speed_per_buff', 0.12)),
        _contactDamageVal = model.contactDamage *
            (game.battleNum('monster', 'contact_base', 0.85) +
                clampJourneyBuff(game, buffMult) *
                    game.battleNum('monster', 'contact_per_buff', 0.2)) {
    // 护甲：journey_monster_params.armor 逐怪覆盖优先；缺省按 AI 档兜底
    // （普通 25 / 精英 40 / 妖王按西游背景定档表），同 armor/(armor+K) 曲线
    bonusArmor = game.monsterParam(
        model.code,
        'armor',
        model.isBoss
            ? (kJourneyBossArmorDefaults[model.code] ??
                kJourneyBossArmorFallback)
            : (model.isElite
                ? kJourneyEliteBaseArmor
                : kJourneyNormalBaseArmor));
  }

  @override
  final JourneyFlameGame game;
  @override
  final JourneyMonsterModel model;
  final double buffMult;

  double hp;
  double maxHp;
  final double _speed;
  double _contactDamageVal;

  /// 怪物护甲（普通 25 / 精英 40 / 妖王按背景定档或 params 逐怪配置），
  /// 受击按 armor/(armor+K) 减免（怪物侧上限 72%），穿刺可按比例无视。
  double bonusArmor = 0;

  double get _contactDamage {
    final base = _contactDamageVal * (_bloodFrenzy ? frenzyMult : 1.0);
    if (!model.isBoss) return base;
    // 妖王压力对齐玩家成长：接触伤害随局内等级线性增长，实时取值使
    // 已刷出的妖王也随升级同步放大，等级提升不稀释压力比值。
    return base * (1.0 + (game._charLv - 1) * game.bossDamageLvK);
  }

  /// 妖王周期能力读取的生效接触伤害。
  @override
  double get contactDamage => _contactDamage;

  /// 血怒狂暴（九头虫）：血量 <frenzy_hp 比例时移速/接触伤害 frenzy_mult
  /// （journey_monster_params.frenzy_hp/frenzy_mult）。
  bool get _bloodFrenzy =>
      model.hasAbility('blood_frenzy') &&
      hp < maxHp * game.monsterParam(model.code, 'frenzy_hp', 0.4);

  double get frenzyMult =>
      game.monsterParam(model.code, 'frenzy_mult', 1.5);

  /// 移速倍率（journey_monster_params.move_mult；缺省按能力兜底，
  /// 狂暴再乘 frenzy_mult）。
  double get _speedMult {
    // 多个加速能力并存时按最高兜底倍率取，避免低倍率覆盖高倍率。
    var fallback = 1.0;
    for (final ability in model.effectiveAbilityKeys) {
      final candidate = switch (ability) {
        'swift_wind' => 1.6,
        'roc_speed' => 1.8,
        _ => 1.0,
      };
      if (candidate > fallback) fallback = candidate;
    }
    var mult = game.monsterParam(model.code, 'move_mult', fallback);
    if (_bloodFrenzy) mult *= frenzyMult;
    return mult;
  }

  @override
  bool isDead = false;
  bool _aggro = false;

  /// 环绕法宝命中冷却：防旋转扫过同一怪连击叠伤。
  double orbHitCd = 0;

  /// 并行攻击单位命中冷却：按形态分槽，避免不同形态互相吞命中。
  /// 槽位由 [_attackUnitSlot] 映射；同形态仍按 0.3s 去重。
  final List<double> attackUnitCds =
      List<double>.filled(kAttackUnitSlotCount, 0);

  /// 血条显示剩余时间：受击刷新，超时渐隐（妖王血条常显不受此控）。
  double _hpBarTimer = 0;

  /// 血条受击淡入进度（0.1s）：避免受击瞬间整条血条硬闪出现。
  double _hpBarFade = 0;

  /// 妖王冲撞视觉过渡：蓄力预警圈淡出 / 突进残影淡入淡出（0~1）。
  double _warningFade = 0;
  double _dashFade = 0;

  /// 预警圈淡出期间冻结的闪烁相位：突进计时语义已变，不能继续驱动闪烁。
  double _warningPhase = 0;

  /// 定身剩余时间（幌金绳命中）：>0 时跳过移动，仍可受击/灼烧。
  double rootTimer = 0;

  /// 虚弱剩余时间（金刚琢命中）：>0 时接触伤害减半。
  double weakenTimer = 0;

  /// 紫金铃命中计数（扩展特效）：同一目标累计 3 次触发妖火爆炸。
  int lingHits = 0;

  // ---- 妖王技能公共状态（仅 model.isBoss 使用）----
  /// 技能公共冷却：任意主动技起手后写入，GCD>0 期间禁止再次起手，
  /// 杜绝冲撞与周期能力同帧/近帧连刀。取值走 boss 组参数（缺省 3s）。
  double _skillGcd = 0;

  /// 护罩吸收量（金铙/月华）：受击时先抵扣，归零后正常走护甲与扣血。
  double ward = 0;

  /// 技能 GCD 就绪：仅妖王参与互斥，普通怪恒可释放。
  bool get skillGcdReady => !model.isBoss || _skillGcd <= 0;

  /// 任意主动技起手时写入公共冷却，逐怪 skill_gcd 优先于全局 boss 组。
  void startSkillGcd() {
    if (!model.isBoss) return;
    _skillGcd = game.monsterParam(
        model.code, 'skill_gcd', game.battleNum('boss', 'skill_gcd', 3.0));
  }

  /// 假身标记（变化术/分瓣梅花）：假身计入怪物列表承伤，但死亡不结算
  /// 经验/功德/掉落，且到时自动消散。
  bool isDecoy = false;
  double decoyLife = 0;

  /// 妖王技能专属的战斗中回血（劲节十八公·根须汲取）：交战态按最大
  /// 生命比例持续回复，区别于通用脱战回血；数值走逐怪 combat_regen。
  void regenInCombat(double dt) {
    if (!model.isBoss || !model.hasAbility('root_bind') || hp >= maxHp) {
      return;
    }
    final rate = game.monsterParam(model.code, 'combat_regen', 0.03);
    if (rate <= 0) return;
    hp = math.min(maxHp, hp + maxHp * rate * dt);
  }

  /// 受击写入护罩：按接触伤害×倍数授予，总量不超 maxHp 比例。
  void grantWard(double ratio) {
    if (!model.isBoss || ratio <= 0) return;
    final add = _contactDamage * ratio;
    final cap = maxHp * game.battleNum('boss', 'ward_cap', 0.35);
    ward = math.min(cap, ward + add);
  }

  /// 无尽妖潮所属波次（除尽推进制：该波怪全灭才刷下一波）。
  int endlessWave = 0;

  /// 独立经验基准（仅无尽妖王）：>0 时替代 exp_drop 作为经验基准，
  /// 使妖王经验随波成长，不再被限血选怪锁在低血档的经验值上。
  double expOverride = 0;

  /// 最近一次进入交战态的序号（大血条选取「最新交战」目标的依据）。
  int lastEngageSeq = 0;

  // ---- 妖王冲撞状态机（仅 model.isBoss，§7 MVP）----
  /// 冲撞相位：0 待机 / 1 蓄力 / 2 突进 / 3 收招。
  int _chargePhase = 0;
  double _chargeTimer = 0;
  Vector2 _chargeDir = Vector2.zero();
  double _chargeCd = 0;
  bool _chargeHit = false;

  static const double _baseRadius = 18;
  double get radius => _baseRadius * model.sizeScale;

  /// 突进相位且未被定身：只有真正产生突进位移时才是冲撞态。定身期间
  /// 位移跳过，恢复普通占位与接触伤害，不得判定撞开角色。
  bool get isCharging => _chargePhase == 2 && rootTimer <= 0;

  // 驻守坐标（脱战后归位）
  late final Vector2 home = position.clone();

  /// 领地半径（endless 妖王潮降临赋值；null=按 isBoss 默认两半径口径）：
  /// 软领地——侦测圈=领地半径（玩家进圈才接战），追出领地 ×leash 倍率
  /// 即脱战归位锚点（快速回血照旧）；配合降临锚点最小间距，多妖王
  /// 各守一方、不同时接战。
  double? territoryRadius;

  /// 侦测半径：妖王潮领地半径优先；普通怪≈屏高 0.4 口径；妖王据点
  /// 用更大触发圈。
  double get aggroRange => territoryRadius ??
      (model.isBoss
          ? game.battleNum('monster', 'aggro_boss', 420)
          : game.battleNum('monster', 'aggro_normal', 260));

  /// 脱战半径：领地口径=领地 ×leash 倍率（软领地追出 30% 即归位）；
  /// 默认口径=侦测 × 脱战倍率。
  double get leashRange => territoryRadius != null
      ? territoryRadius! *
          game.battleNum('endless', 'boss_leash_gain',
              kJourneyEndlessBossLeashGain)
      : aggroRange * game.battleNum('monster', 'leash_mult', 1.5);

  /// 脱战快速回血速率：每秒恢复 maxHp 的比例（默认 40%，2.5 秒回满）。
  /// 口径：脱战（驻守/归位态）快速回满，再入战（追击态）立即停止；
  /// 妖王同规则——拉开距离即回满，惩罚拉脱打法。不触发死亡/掉落。
  static const double _regenPerSec = 0.4;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hpBarTimer > 0) {
      _hpBarTimer -= dt;
      _hpBarFade = math.min(1, _hpBarFade + dt / 0.1);
    } else {
      _hpBarFade = 0;
    }
    // 冲撞相位切换的视觉过渡：蓄力预警圈淡出、突进残影淡入淡出。
    // 仅推进展示计时，不参与状态机判定，暂停时随引擎冻结。
    if (model.isBoss) {
      if (_chargePhase == 1) {
        _warningFade = 1;
        _dashFade = 0;
        _warningPhase = 0.5 + 0.5 * math.sin(_chargeTimer * 26);
      } else {
        if (_warningFade > 0) {
          _warningFade = math.max(0, _warningFade - dt / 0.18);
        }
        if (_chargePhase == 2) {
          _dashFade = math.min(1, _dashFade + dt / 0.12);
        } else if (_dashFade > 0) {
          _dashFade = math.max(0, _dashFade - dt / 0.18);
        }
      }
    }
    if (orbHitCd > 0) {
      orbHitCd -= dt;
    }
    for (var i = 0; i < attackUnitCds.length; i++) {
      if (attackUnitCds[i] > 0) {
        attackUnitCds[i] -= dt;
      }
    }
    if (isDead) return;

    // 妖王技能 GCD 逐帧递减（暂停随引擎冻结，定身中也照常恢复）
    if (model.isBoss && _skillGcd > 0) {
      _skillGcd = math.max(0, _skillGcd - dt);
    }

    // 击退动画先推进：离屏冻结只跳过索敌/回血，不能冻结未走完的位移
    _tickKnockback(dt);
    tickSlotStatus(dt); // 减速/寻猎计时：离屏也推进，寻猎怪不因冻结而卡态
    final knockFactor = knockChaseFactor * slotSlowFactor;
    final hunting = autoHuntApplies(game, this); // 冻结/追击共用，妖王恒 false

    // 离屏冻结：距离 >1400 时跳过索敌/移动/回血/灼烧，仅推进展示类计时；
    // 灼烧离屏暂停（burnRemaining 不倒计时，回屏后继续结算伤害）。
    if (!hunting &&
        lureTimer <= 0 && // 寻猎怪豁免冻结，否则被吸引的远处怪停在原地
        (game.player.position - position).length >
            game.battleNum('monster', 'freeze_dist', 1400)) {
      if (rootTimer > 0) {
        rootTimer -= dt;
      }
      if (weakenTimer > 0) {
        weakenTimer -= dt;
      }
      return;
    }

    // 灼烧掉血：逐来源独立扣血，互不相加；来源计时归零自动移除。
    // 固定值型来源（灼烧槽/领域灼烧）为真实伤害绕甲，百分比型来源经护甲减免。
    for (final tick in tickBurn(dt)) {
      takeDamage(tick.damage, armorIgnore: tick.trueDamage ? 1 : 0);
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

    // 三态两半径（妖王同规则：驻点待机→侦测追击→脱战归位据点）；
    // 全图追猎/寻猎的普怪强制常驻追击态，忽略两半径，直追到击杀（妖王不受寻猎影响）。
    final wasAggro = _aggro;
    final lured = lureTimer > 0;
    if (hunting || lured || (!_aggro && dist < aggroRange)) {
      _aggro = true;
    } else if (_aggro && dist > leashRange && !lured) {
      _aggro = false;
    }
    // 进入交战态时登记序号，供大血条按「最新交战」选取展示目标；
    // 血条数值与显隐统一由宿主每帧 syncBossHud 维护（多妖王不串台）。
    if (model.isBoss && !isDecoy && !wasAggro && _aggro) {
      lastEngageSeq = ++game.bossEngageSeq;
    }

    // 假身沿用本体模型但只是承伤分身：不施法、不冲撞、不回血，
    // 否则变化术假身会递归召出更多假身，造成指数增殖。
    if (model.isBoss && !isDecoy) {
      _updateCharge(dt, dist, toPlayer, rooted: rooted);
      // 妖王周期能力（追击态才走，定身中不放）
      if (_aggro && !rooted && model.effectiveAbilityKeys.isNotEmpty) {
        tickBossAbility(dt, dist);
      }
      // 交战态专属回血（根须汲取）：持续生效，定身中亦在战斗中
      if (_aggro) regenInCombat(dt);
    }

    // 假身到时消散：不计入击杀结算，直接移除
    if (isDecoy) {
      decoyLife -= dt;
      if (decoyLife <= 0) {
        isDead = true;
        removeFromParent();
        return;
      }
    }

    if (_aggro) {
      if (_chargePhase == 0 && !rooted && dist > 1) {
        // 追击：直线朝玩家（分离力在 game 层统一做）
        position += toPlayer.normalized() *
            cappedMonsterSpeed(this) *
            dt *
            knockFactor;
      } else if (_chargePhase == 3 && !rooted && dist > 1) {
        // 收招：缓速归位追击
        position += toPlayer.normalized() *
            cappedMonsterSlowSpeed(this) *
            dt *
            knockFactor;
      }
      // 蓄力（1）原地预警；突进（2）位移由冲撞状态机锁定方向推进
    } else {
      // 驻守：向驻守点缓慢归位 + 小幅游荡
      final toHome = home - position;
      if (!rooted && toHome.length > 4) {
        position += toHome.normalized() *
            cappedMonsterSlowSpeed(this) *
            dt *
            knockFactor;
      }
      // 脱战快速回血：未追击玩家即回，上限 maxHp（进入追击态即停）
      regenWhenDisengaged(dt);
    }
    // 普通状态停在接触边界；突进中不被角色挡住，命中后撞开角色并结算
    // 一次冲撞伤害（单次去重），随后统一钳回世界边界
    if (isCharging) {
      if (!_chargeHit && game.resolveBossChargeHit(this)) _chargeHit = true;
    } else {
      clampMonsterOutOfInnerCircle(this, player.position);
    }
    clampMonsterToWorld(this, game.worldSize);
  }

  /// 妖王冲撞状态机：追击近距触发→蓄力预警→锁定方向突进
  /// （速度乘区与玩家移速同档，走位需预判；撞墙由世界边界钳制）
  /// →收招缓速→冷却。各时序与距离走 boss 组参数，缺省沿用内置口径。
  void _updateCharge(double dt, double dist, Vector2 toPlayer,
      {required bool rooted}) {
    if (_chargeCd > 0) {
      _chargeCd -= dt;
    }
    switch (_chargePhase) {
      case 0:
        // 追击态近距触发（定身中不触发）
        if (_aggro &&
            !rooted &&
            _chargeCd <= 0 &&
            skillGcdReady &&
            dist < game.battleNum('boss', 'charge_trigger_dist', 340)) {
          _chargePhase = 1;
          _chargeTimer = game.battleNum('boss', 'charge_windup_sec', 0.7);
          // 冲撞起手占公共冷却，避免紧接着又放周期能力形成连刀
          startSkillGcd();
        }
        break;
      case 1:
        // 蓄力：原地不动（渲染红色预警圈闪烁）
        _chargeTimer -= dt;
        if (_chargeTimer <= 0) {
          _chargeDir = dist > 1 ? toPlayer.normalized() : Vector2(1, 0);
          _chargePhase = 2;
          _chargeTimer = game.battleNum('boss', 'charge_dash_sec', 0.55);
          _chargeHit = false;
        }
        break;
      case 2:
        // 突进：方向锁定，速度乘区与玩家移速同档；定身期间位移跳过
        //（幌金绳对妖王突进同样生效），突进时长照常消耗（root 中即原地停摆）
        _chargeTimer -= dt;
        if (!rooted) {
          position +=
              _chargeDir *
              cappedMonsterSpeed(this) *
              game.battleNum('boss', 'charge_speed_mult', 4.5) *
              dt;
        }
        if (_chargeTimer <= 0) {
          _chargePhase = 3;
          _chargeTimer = game.battleNum('boss', 'charge_recover_sec', 1.0);
        }
        break;
      case 3:
        // 收招：缓速归位追击
        _chargeTimer -= dt;
        if (_chargeTimer <= 0) {
          _chargePhase = 0;
          // 金翅迅影（大鹏）：冲撞冷却减半（params.charge_cd 可调）
          _chargeCd = game.monsterParam(model.code, 'charge_cd',
              model.hasAbility('roc_speed') ? 2.0 : 4.0);
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
    // 持续减益在怪物身上画状态环（灼烧/定身/虚弱/减速/寻猎/血怒），
    // 冲撞预警与残影、血条淡入统一由视觉 part 绘制，不写回战斗状态。
    drawStatusRings(canvas);
    drawChargeVisual(canvas);
    drawHpBar(canvas);
  }

  /// 多场妖王战的逐场伤害增强（缺省 +25%/场，血量由 buffMult 承担）。
  void scaleStageDamage(int stage) {
    if (stage <= 0) return;
    _contactDamageVal = _contactDamageVal *
        (1.0 +
            stage * game.battleNum('boss', 'stage_damage_gain', 0.25));
  }

  void takeDamage(double amount, {double armorIgnore = 0}) {
    if (isDead) return;
    // 护罩优先抵扣（金铙/月华护盾），破产部分再走护甲与扣血
    if (ward > 0) {
      final absorbed = math.min(ward, amount);
      ward -= absorbed;
      amount -= absorbed;
    }
    // 护甲减免（与玩家同曲线 armor/(armor+K)，怪物侧上限 72% 高于玩家
    // 60%，保 150~200 甲档位区分度）；穿刺命中按 armorIgnore 比例无视
    // 护甲（其余衍生伤害不受益）
    if (bonusArmor > 0) {
      final effArmor = bonusArmor * (1 - armorIgnore.clamp(0.0, 1.0));
      amount *= 1 - JourneyDamageTickMixin.armorReductionRatio(
          effArmor, curveK: game.armorCurveK, cap: game.monsterArmorCap);
    }
    hp -= amount;
    _hpBarTimer = 2.5;
    // 处决维度槽：任意伤害后血量落入阈值直接清血条，走既有击杀奖励链；
    // 置于阶段能力判定之前，处决命中后不再触发低血分裂/狂暴等阶段技。
    if (hp > 0) game.tryExecuteMonster(this);
    // 法天象地（牛魔王）：血量首次跌破阈值后接触伤害永久提升（每场一次）
    if (!isDecoy &&
        model.hasAbility('unmovable') &&
        !_giantTriggered &&
        hp > 0 &&
        hp < maxHp * game.monsterParam(model.code, 'giant_hp', 0.5)) {
      _giantTriggered = true;
      _contactDamageVal *= game.monsterParam(model.code, 'giant_damage', 1.4);
      game.spawnFloatText(
        position + Vector2(0, -radius - 14),
        '法天象地！',
        const Color(0xFFE04545),
      );
    }
    // 分魂化形（白骨精）：血量首次跌破阈值分裂 2 只妖卫（每场一次）
    if (!isDecoy &&
        model.hasAbility('bone_split') &&
        !_splitDone &&
        hp > 0 &&
        hp < maxHp * game.battleNum('monster', 'split_hp_ratio', 0.5)) {
      _splitDone = true;
      _spawnBoneSplinters();
    }
    if (hp <= 0) {
      isDead = true;
      game.onMonsterKilled(this);
      removeFromParent();
    }
  }

  bool _splitDone = false;
  bool _giantTriggered = false;

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
        buffMult: buffMult *
            game.battleNum('monster', 'split_hp_mult', 0.4),
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
}
