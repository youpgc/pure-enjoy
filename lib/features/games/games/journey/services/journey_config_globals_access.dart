part of 'journey_config_snapshot.dart';

/// journey_globals 数值读取：numeric 列经 PostgREST 可能返回数字或字符串。
double? _journeyGlobalNum(Map<String, dynamic>? row, String key) {
  final v = row?[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// journey_globals 全局参数只读访问：列缺失/seed 快照为 null 时回落内置
/// 兜底，保证配置表未部署或后到时行为与改造前一致。
extension JourneyConfigGlobalsAccess on JourneyConfigSnapshot {
  double? _num(String key) => _journeyGlobalNum(globalsRaw, key);

  double _numOr(String key, double fallback) => _num(key) ?? fallback;

  int _intOr(String key, int fallback) => _num(key)?.toInt() ?? fallback;

  double _doubleOr(String key, double fallback) =>
      (globalsRaw?[key] as num?)?.toDouble() ?? fallback;

  /// 妖王天赋点掉率（0~1；伏诛判定命中后全账号共享天赋点池 +1）。
  double get talentDropRate => _numOr('talent_drop_rate', kJourneyTalentDropRate);

  /// 还魂复活功德基准价；实际消耗=基准 × 当前角色等级。
  int get reviveMeritBase => _intOr('revive_merit_base', kJourneyReviveMeritBase);

  /// 还魂复活功德封顶。
  int get reviveMeritCap => _intOr('revive_merit_cap', kJourneyReviveMeritCap);

  /// 同屏怪物实体上限。
  int get monsterCap => _intOr('monster_cap', 120);

  /// 开局铺场只数（0=关闭）；波次关恢复铺场。
  int get initialPackSize => _intOr('initial_pack_size', kJourneyInitialPackSize);

  /// 妖穴集中概率（0~1；调低=沿途遭遇更均匀）。
  double get spawnDenRatio => _numOr('spawn_den_ratio', kJourneySpawnDenRatio);

  /// 角色等级上限（满级经验条恒满）。
  int get charLevelCap => _intOr('char_level_cap', kJourneyCharLevelCap);

  /// 每日游历局内功德增长上限：达上限后不再增长，仍可继续游玩。
  int get meritCap => _intOr('merit_cap', 9999);

  /// 妖王首次降临延迟（秒）。
  int get bossSpawnDelaySec =>
      _intOr('boss_spawn_delay_sec', kJourneyBossSpawnDelaySec);

  /// 妖王降临倒计时提醒窗口（秒）；0=关闭提醒。
  int get bossWarnSec => _intOr('boss_warn_sec', kJourneyBossWarnSec);

  /// 妖王阵亡到复活/新妖王降临的冷却（秒）。
  int get bossRespawnCdSec =>
      _intOr('boss_respawn_cd_sec', kJourneyBossRespawnCdSec);

  /// 前期发育保护期（秒）；期间不产生精英怪。
  int get earlyGameProtectSec =>
      _intOr('early_game_protect_sec', kJourneyEarlyGameProtectSec);

  /// 保护期结束后精英率每分钟增量。
  double get eliteRatePerMin =>
      _numOr('elite_rate_per_min', kJourneyEliteRatePerMin);

  /// 精英率上限：后期仍保留普通怪比例。
  double get eliteRateCap => _numOr('elite_rate_cap', kJourneyEliteRateCap);

  /// 局内强度每分钟增长斜率。
  double get buffTimeSlope => _numOr('buff_time_slope', kJourneyBuffTimeSlope);

  /// 每点关卡难度的强度乘区增量。
  double get buffLevelMult => _numOr('buff_level_mult', kJourneyBuffLevelMult);

  /// 生效强度乘区上限。
  double get buffMultCap => _numOr('buff_mult_cap', kJourneyBuffMultCap);

  /// 怪物最终移速上限（px/s）。
  double get monsterSpeedCap =>
      _numOr('monster_speed_cap', kJourneyMonsterSpeedCap);

  /// 妖王接触伤害的玩家等级成长系数。
  double get bossDamageLvK =>
      _numOr('boss_damage_lv_k', kJourneyBossDamageLvK);

  // ---- 平衡曲线（经验幂次 / 怪物等级项 / 境界 / 品阶 / 精英血线）----

  /// 经验曲线幂次：升级所需 = exp_base + exp_per_lv × lv^pow；
  /// 1=旧线性曲线。
  double get expCurvePow => _numOr('exp_curve_pow', kJourneyExpCurvePow);

  /// 怪物经验随强度乘区缩放系数：经验 ×(1+乘区×K)；0=旧口径。
  double get expMultK => _numOr('exp_mult_k', kJourneyExpMultK);

  /// 经验产出成长通道：按玩家等级与局内时间增长，与强度乘区解耦。
  double get expLvPow => _numOr('exp_lv_pow', kJourneyExpLvPow);

  int get expLvBaseLv =>
      (_num('exp_lv_base_lv') ?? kJourneyExpLvBaseLv).round().clamp(1, 999);

  /// 时间项增幅钳非负：直接改库配负值时忽略，避免经验反向衰减。
  double get expTimeGain {
    final raw = _numOr('exp_time_gain', kJourneyExpTimeGain);
    return raw < 0 ? 0.0 : raw;
  }

  /// 成长乘区上限钳 ≥1：低于 1 会吞掉全部等级成长，按 1 处理退化为不放大。
  double get expGainCap {
    final raw = _numOr('exp_gain_cap', kJourneyExpGainCap);
    return raw < 1 ? 1.0 : raw;
  }

  /// 大型精英进池血线：0 或列缺失时回落兜底值。
  double get ecoEliteLargeHp {
    final raw = _num('eco_elite_large_hp');
    return raw == null || raw <= 0 ? kJourneyEcoEliteLargeHp : raw;
  }

  /// 普通怪血量玩家等级成长系数；精英不跟等级，0=旧口径。
  double get monsterLvK => _numOr('monster_lv_k', kJourneyMonsterLvK);

  /// 妖王血量玩家等级成长系数，与时间项叠乘；0=旧口径。
  double get bossHpLvK => _numOr('boss_hp_lv_k', kJourneyBossHpLvK);

  /// 每次境界突破的增伤增量：增伤Σ%加法合流。
  double get realmAmpPer => _numOr('realm_amp_per', kJourneyRealmAmpPer);

  /// 每次境界突破的生命上限增幅：maxHp 复利。
  double get realmHpPer => _numOr('realm_hp_per', kJourneyRealmHpPer);

  /// 境界步长：每 N 级一档境界，99 级共 9 档。
  int get realmStep => _intOr('realm_step', kJourneyRealmStep);

  /// 法宝品阶 L9+ 每级增幅：L8 锚点复利延展。
  double get weaponGradePerLv =>
      _numOr('weapon_grade_per_lv', kJourneyWeaponGradePerLv);

  // ---- 无尽妖潮·妖王潮（起点/配额/降临/领地/护卫/限流/经验曲线）----

  /// 妖潮起点波号：波次表首个 boss_count>0 的波优先于本值。
  int get endlessBossTideStartWave =>
      _intOr('endless_boss_tide_start_wave', kJourneyEndlessBossTideStartWave);

  /// 同波妖王配额上限（默认 99=波次刷新总量，与同屏并发为两个维度）。
  int get endlessBossCountCap =>
      _intOr('endless_boss_count_cap', kJourneyEndlessBossCountCap);

  /// 无尽妖王宝箱波内首杀掉落概率。
  double get endlessBossChestRate =>
      _numOr('endless_boss_chest_rate', kJourneyEndlessBossChestRate);

  /// 宝葫妖潮期每波炼化上限。
  int get endlessBossRefinePerWave =>
      _intOr('endless_boss_refine_per_wave', kJourneyEndlessBossRefinePerWave);

  /// 无尽模式专属升级需求曲线：need(lv) = base + per_lv × lv^pow。
  double get endlessExpBase => _numOr('endless_exp_base', kJourneyEndlessExpBase);

  double get endlessExpPerLv =>
      _numOr('endless_exp_per_lv', kJourneyEndlessExpPerLv);

  double get endlessExpPow => _numOr('endless_exp_pow', kJourneyEndlessExpPow);

  /// 同场并发妖王数上限。
  int get endlessBossConcurrent =>
      _intOr('endless_boss_concurrent', kJourneyEndlessBossConcurrent);

  /// 妖王补位降临倒计时秒。
  double get endlessBossArriveCd =>
      _numOr('endless_boss_arrive_cd', kJourneyEndlessBossArriveCd);

  /// 妖王能力每波额外增幅。
  double get endlessBossAmpPerWave =>
      _numOr('endless_boss_amp_per_wave', kJourneyEndlessBossAmpPerWave);

  /// 妖潮妖王血量每波额外增幅：血量乘区独立于经验/速度/接触伤害共用
  /// 乘区，不吃玩家等级项。
  double get endlessBossHpAmp =>
      _numOr('endless_boss_hp_amp', kJourneyEndlessBossHpAmp);

  /// 妖王领地半径 px。
  double get endlessBossTerritoryRadius =>
      _numOr('endless_boss_territory_radius', kJourneyEndlessBossTerritoryRadius);

  /// 多妖王锚点最小间距 px。
  double get endlessBossSpreadMinDist =>
      _numOr('endless_boss_spread_min_dist', kJourneyEndlessBossSpreadMinDist);

  /// 妖潮期护卫精英占比。
  double get endlessBossGuardEliteRatio =>
      _numOr('endless_boss_guard_elite_ratio', kJourneyEndlessBossGuardEliteRatio);

  // ---- 通用成长卡/经验曲线（journey_globals 列；缺省走内置兜底）----

  /// 三选一通用成长卡·移动速度加成。
  double get upgradeMove => _doubleOr('upgrade_move', 0.09);

  /// 三选一通用成长卡·生命上限。
  double get upgradeHp => _doubleOr('upgrade_hp', 20);

  /// 三选一通用成长卡·自动回复。
  double get upgradeRegen => _doubleOr('upgrade_regen', 1);

  /// 三选一通用成长卡·拾取范围。
  double get upgradePickup => _doubleOr('upgrade_pickup', 18);

  /// 经验曲线基数：升级所需 = base + 当前等级 × exp_per_lv。
  double get expBase => _doubleOr('exp_base', 12);

  /// 经验曲线每级增量。
  double get expPerLv => _doubleOr('exp_per_lv', 7);

  /// 每次升级提升的基础攻击力。
  double get levelAttackPerLv =>
      _numOr('level_attack_per_lv', kJourneyLevelAttackPerLv);

  /// 每次升级提升的生命上限。
  double get levelHpPerLv => _numOr('level_hp_per_lv', kJourneyLevelHpPerLv);

  /// 攻击力成长卡单次提升量。
  double get upgradeAttack => _numOr('upgrade_attack', kJourneyUpgradeAttack);

  /// 攻击力成长卡累计提升上限。
  double get attackUpgradeCap =>
      _numOr('attack_upgrade_cap', kJourneyAttackUpgradeCap);

  /// 妖王血量时间项系数。
  double get bossHpTimeK => _numOr('boss_hp_time_k', kJourneyBossHpTimeK);

  /// 护甲减伤曲线分母 K：armor/(armor+K)，K 越大同护甲减伤越低。
  double get armorCurveK => _numOr('armor_curve_k', kJourneyArmorCurveK);

  /// 怪物侧护甲减伤上限：高于玩家侧 60%，使 150~200 甲档位仍可区分。
  double get monsterArmorCap =>
      _numOr('monster_armor_reduction_cap', kJourneyMonsterArmorCap);

  /// 还魂复活功德价 = 基准价 × 当前角色等级，封顶 reviveMeritCap。
  int reviveCostFor(int charLevel) =>
      (reviveMeritBase * charLevel).clamp(0, reviveMeritCap);
}
