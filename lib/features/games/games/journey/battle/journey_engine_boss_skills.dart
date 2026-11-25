part of 'journey_flame_game.dart';

/// 30 位妖王独特能力统一调度（西游记背景扩展）。
///
/// 能力键沿用 journey_monsters.ability_key（后台可配），调度集中在本 part：
/// - 周期技按逐怪 <能力>_period 读取（缺省内置兜底），到点检查 GCD 后释放；
/// - 接触附带、血线触发、受击/死亡触发分别挂在既有结算入口；
/// - 所有强度数值经 monsterParam/battleNum 后台可调，缺省回落内置常量。
extension JourneyBossSkillCast on JourneyFlameGame {
  /// 周期能力统一调度：周期读取、计时推进、GCD 检查、派发全在一处，
  /// 避免计时上限与派发口径分离；计时到点且 GCD 就绪才起手。
  void tickBossSkill(JourneyMonsterComponent boss, double dt, double dist) {
    final code = boss.model.code;
    final key = boss.model.abilityKey;
    if (key.isEmpty) return;
    // 法天象地是血线被动（接触伤害提升挂在受击钩子），不进周期调度，
    // 否则每次空转都会写入 GCD，把妖王自身的冲撞机会挡掉。
    if (key == 'unmovable') return;
    // 处决是受击侧被动（任意伤害达阈值即斩），不进周期调度。
    if (key == 'execute') return;
    // 九头噬仅在狂暴期释放扇形弹道；非狂暴期停表等待，不空占 GCD。
    if (key == 'blood_frenzy' && !boss._bloodFrenzy) return;
    final period = monsterParam(code, '${key}_period', _periodFallback(key));
    if (period <= 0) return;
    boss.advancePeriodic(dt, period);
    // 计时到点但 GCD 未就绪：停表等待，不空转、不写 GCD
    if (!boss.periodicReady(period) || !boss.skillGcdReady) return;
    boss.ackPeriodic();
    boss.startSkillGcd();
    _dispatchSkill(boss, key, dist);
  }

  /// 各能力缺省周期（秒）；后台 journey_monster_params.<key>_period 优先。
  double _periodFallback(String key) => switch (key) {
        'swift_wind' => 8.0,
        'bone_split' => 12.0,
        'gourd_pull' => 10.0,
        'samadhi_fire' => 6.0,
        'iron_horn' => 12.0,
        'poison_mist' => 9.0,
        'unmovable' => 14.0,
        'blood_frenzy' => 8.0,
        'spider_web' => 10.0,
        'roc_speed' => 12.0,
        'inner_core' => 7.0,
        'fake_body' => 12.0,
        'water_prison' => 9.0,
        'five_thunder' => 7.0,
        'ice_seal' => 9.0,
        'mirror' => 12.0,
        'root_bind' => 10.0,
        'golden_bag' => 10.0,
        'devour' => 9.0,
        'three_bells' => 9.0,
        'spear_thrust' => 8.0,
        'earth_trap' => 10.0,
        'plum_flower' => 12.0,
        'nine_seize' => 11.0,
        'ice_charge' => 10.0,
        'moon_guard' => 9.0,
        'tiger_pounce' => 8.0,
        'black_wind' => 10.0,
        'deer_belly' => 9.0,
        'ram_oil' => 10.0,
        'shield_break' => 9.0,
        _ => 0.0,
      };

  void _dispatchSkill(JourneyMonsterComponent boss, String key, double dist) {
    final code = boss.model.code;
    final pos = boss.position;
    final p = player;
    switch (key) {
      // ---- 已有能力加深 ----
      case 'swift_wind': // 三昧神风：吹离 + 致盲（风沙迷眼）
        final to = p.position - pos;
        if (to.length > 1) {
          p.applySkillShift(
              to,
              monsterParam(code, 'wind_push', 200),
              monsterParam(code, 'wind_shift_sec', 0.6));
        }
        applyBossSkillEffect('blind',
            power: monsterParam(code, 'blind_sec', 2.5), owner: boss);
        break;
      case 'samadhi_fire': // 三昧真火：三段火车 + 烟熏致盲
        _fireTrain(boss, code, dist);
        break;
      case 'gourd_pull': // 紫金摄魂：拉拽 + 装天封印一槽
        final to = pos - p.position;
        if (to.length > 1) {
          p.applySkillShift(
              to,
              monsterParam(code, 'pull_dist', 180),
              monsterParam(code, 'pull_shift_sec', 0.6));
        }
        applyBossSkillEffect('seal', power: 0, owner: boss);
        break;
      case 'bone_split': // 白骨三变：周期换形态，交替护罩/致幻
        if (boss._boneForm % 2 == 0) {
          boss.grantWard(monsterParam(code, 'form_ward', 0.5));
          spawnFloatText(pos + Vector2(0, -boss.radius - 14), '白骨·幻形',
              const Color(0xFFB07CD4));
        } else {
          applyBossSkillEffect('blind',
              power: monsterParam(code, 'form_blind', 2.0), owner: boss);
        }
        boss._boneForm++;
        break;
      case 'iron_horn': // 金刚琢：套取增益（增伤削减）+ 短暂护罩
        applyBossSkillEffect('drain', power: 0, owner: boss);
        boss.grantWard(monsterParam(code, 'steal_ward', 0.4));
        break;
      case 'poison_mist': // 倒马毒桩：周期叠毒刺 + 毒雾领域
        applyBossSkillEffect('sting',
            power: monsterParam(code, 'sting_add', 1), owner: boss);
        bossSkillLayer.castField(pos,
            radius: monsterParam(code, 'mist_range', 120),
            life: monsterParam(code, 'mist_sec', 4),
            tick: monsterParam(code, 'mist_tick', 1.0),
            effect: 'dot',
            power: monsterParam(code, 'mist_sec', 4),
            // 毒雾持续伤害需给出每 tick 基数，否则 dot 通道只有时长没有伤害
            rawDamage: boss.contactDamage *
                monsterParam(code, 'mist_ratio', 0.1),
            color: const Color(0xFF7FA85C),
            owner: boss);
        break;
      case 'unmovable': // 法天象地：血线触发体型/伤害提升（被动，见血线钩子）
        break;
      case 'blood_frenzy': // 九头噬：狂暴期扇形多弹道
        if (boss._bloodFrenzy) _fangVolley(boss, code);
        break;
      case 'spider_web': // 千眼金光：大范围持续定身领域
        bossSkillLayer.castField(pos,
            radius: monsterParam(code, 'light_range', 220),
            life: monsterParam(code, 'light_sec', 5),
            tick: monsterParam(code, 'light_tick', 0.8),
            effect: 'root',
            power: monsterParam(code, 'light_root', 0.6),
            rawDamage: 0,
            color: const Color(0xFFE8C470),
            owner: boss);
        break;
      case 'roc_speed': // 阴阳二气瓶：周期禁锢（长定身）
        if (dist <= monsterParam(code, 'bottle_range', 260)) {
          applyBossSkillEffect('root',
              power: monsterParam(code, 'bottle_root', 1.6), owner: boss);
        }
        break;
      // ---- 新增能力（后续 part 续写）----
      default:
        _dispatchNewSkill(boss, key, dist);
    }
  }

  void _fireTrain(JourneyMonsterComponent boss, String code, double dist) {
    final waves = monsterParam(code, 'fire_waves', 3).round().clamp(1, 6);
    final gap = monsterParam(code, 'fire_wave_gap', 0.35);
    final range = monsterParam(code, 'fire_range', 250);
    for (var i = 0; i < waves; i++) {
      bossSkillLayer.castTelegraph(
          player.position,
          radius: range,
          delay: gap * i + monsterParam(code, 'fire_first_delay', 0.1),
          damage: boss.contactDamage * monsterParam(code, 'fire_ratio', 0.8),
          effect: 'fire_hit',
          power: 0,
          color: const Color(0xFFD4593F),
          owner: boss);
    }
    applyBossSkillEffect('blind',
        power: monsterParam(code, 'smoke_blind', 1.5), owner: boss);
  }

  void _fangVolley(JourneyMonsterComponent boss, String code) {
    final count = monsterParam(code, 'fang_count', 5).round().clamp(1, 12);
    final spread = monsterParam(code, 'fang_spread', 0.9);
    final base = (player.position - boss.position).normalized();
    for (var i = 0; i < count; i++) {
      final a = (i - (count - 1) / 2) * spread / math.max(1, count - 1);
      final dir = Vector2(
        base.x * math.cos(a) - base.y * math.sin(a),
        base.x * math.sin(a) + base.y * math.cos(a),
      );
      bossSkillLayer.castProjectile(boss.position, dir,
          speed: monsterParam(code, 'fang_speed', 320),
          radius: monsterParam(code, 'fang_radius', 12),
          life: monsterParam(code, 'fang_life', 3),
          damage: boss.contactDamage * monsterParam(code, 'fang_ratio', 0.5),
          effect: 'hit',
          power: 0,
          color: const Color(0xFFE04545),
          owner: boss);
    }
  }
}
