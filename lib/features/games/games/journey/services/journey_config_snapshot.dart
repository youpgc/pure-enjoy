import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import 'journey_seed.dart';

/// 西行·配置快照（一次聚合全部 journey_* 静态配置）。
class JourneyConfigSnapshot {
  final List<JourneyRegionModel> regions;
  final List<JourneyLevelModel> levels;
  final List<JourneyCharacterModel> characters;
  final List<JourneyWeaponModel> weapons;

  /// 五行天赋分支（4 角色 × 5 系 × 3 分支 = 60 行；v4 分支树制）。
  final List<JourneyTalentBranchModel> talentBranches;

  /// 怪物池（journey_monsters 远端配置；空=引擎回落内置种子池）。
  final List<JourneyMonsterModel> monsters;

  /// 武器维度槽定义（journey_weapon_slots；空=引擎回落内置兜底）。
  final List<JourneySlotDefModel> slotDefs;

  /// 法宝分级（journey_weapon_levels，按法宝 code 分组，lv 升序）；
  /// 空=引擎回落内置基准数值。
  final Map<String, List<JourneyWeaponLevelModel>> weaponLevels;

  /// 掉落表（journey_drops，table_code 分组）；空=消费侧回落内置种子。
  final List<JourneyDropModel> drops;

  /// 炼化配方（journey_evo_recipes，seq 升序=判定优先级）；
  /// 空=消费侧回落内置种子。
  final List<JourneyEvoRecipeModel> evoRecipes;

  /// 图鉴解锁（journey_relic_unlocks，seq 升序）；空=消费侧回落内置种子。
  final List<JourneyRelicUnlockModel> relicUnlocks;

  /// 拾取物配置（journey_pickups，code 升序）；空=消费侧回落内置种子。
  final List<JourneyPickupConfigModel> pickupConfigs;

  /// 每日游历地图列表（journey_daily_maps，后台可配）；空=消费侧回落种子。
  final List<JourneyDailyMapModel> dailyMaps;

  /// 无尽妖潮波次配置（journey_endless_waves，上限 99；空=全部内置公式）。
  final List<JourneyEndlessWaveModel> endlessWaves;

  /// 法宝数值参数（journey_weapon_params，code 分组：weaponCode→{code→值}；
  /// 空=引擎全部走内置兜底）。
  final Map<String, Map<String, double>> weaponParams;

  /// 妖王能力参数（journey_monster_params，code 分组：monsterCode→{code→值}；
  /// 空=引擎全部走内置兜底）。
  final Map<String, Map<String, double>> monsterParams;

  /// journey_globals 原始行（通用成长卡/经验曲线等扩展列直读；
  /// 列缺失/seed 快照为 null 时消费侧回落内置兜底）。
  final Map<String, dynamic>? globalsRaw;

  /// 还魂复活功德基准价（journey_globals.revive_merit_base）；
  /// 实际消耗=基准 × 关卡号。
  final int reviveMeritBase;

  /// 西行游戏 id（games.code='journey'；成绩上报用，空=未就绪不上报）。
  final String gameId;

  /// 成绩维度 id（game_dimensions，code→id：farthest_level/run_kills/
  /// run_merit）；成绩上报 values 键，空=未配置不上报。
  final Map<String, String> scoreDimIds;

  /// 同屏怪物实体上限（journey_globals.monster_cap，运营可在后台调整）。
  final int monsterCap;

  /// 开局铺场只数（journey_globals.initial_pack_size，0=关闭）；
  /// 波次关恢复铺场（修「接配置后开局空场走远看不到怪」）。
  final int initialPackSize;

  /// 妖穴集中概率（journey_globals.spawn_den_ratio，0~1；调低=沿途遭遇
  /// 更均匀）。刷怪点落入 demon_den 热区的比例。
  final double spawnDenRatio;

  /// 妖王天赋点掉率（journey_globals.talent_drop_rate，0~1；末场伏诛
  /// 判定命中后全部角色点池各 +1）。
  final double talentDropRate;

  /// 角色等级上限（journey_globals.char_level_cap；满级经验条恒满）。
  final int charLevelCap;

  /// true = 全部来自内置兜底（journey_* 表未部署或拉取失败）。
  final bool fromSeed;

  /// 全局参数数值读取：numeric 列经 PostgREST 可能返回数字或字符串。
  static double? _globalNum(Map<String, dynamic>? row, String key) {
    final v = row?[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 妖王首次降临延迟（秒）；列缺失或未配值时回落内置兜底。
  int get bossSpawnDelaySec =>
      _globalNum(globalsRaw, 'boss_spawn_delay_sec')?.toInt() ??
      kJourneyBossSpawnDelaySec;

  /// 前期发育保护期（秒）；期间不产生精英怪。
  int get earlyGameProtectSec =>
      _globalNum(globalsRaw, 'early_game_protect_sec')?.toInt() ??
      kJourneyEarlyGameProtectSec;

  /// 保护期结束后精英率每分钟增量。
  double get eliteRatePerMin =>
      _globalNum(globalsRaw, 'elite_rate_per_min') ??
      kJourneyEliteRatePerMin;

  /// 局内强度每分钟增长斜率；列缺失或未配值回落内置兜底。
  double get buffTimeSlope =>
      _globalNum(globalsRaw, 'buff_time_slope') ??
      kJourneyBuffTimeSlope;

  /// 每点关卡难度的强度乘区增量。
  double get buffLevelMult =>
      _globalNum(globalsRaw, 'buff_level_mult') ??
      kJourneyBuffLevelMult;

  /// 生效强度乘区上限。
  double get buffMultCap =>
      _globalNum(globalsRaw, 'buff_mult_cap') ??
      kJourneyBuffMultCap;

  /// 怪物最终移速上限（px/s）。
  double get monsterSpeedCap =>
      _globalNum(globalsRaw, 'monster_speed_cap') ??
      kJourneyMonsterSpeedCap;

  const JourneyConfigSnapshot({
    required this.regions,
    required this.levels,
    required this.characters,
    required this.weapons,
    required this.talentBranches,
    this.monsters = const <JourneyMonsterModel>[],
    this.slotDefs = const <JourneySlotDefModel>[],
    this.weaponLevels = const <String, List<JourneyWeaponLevelModel>>{},
    this.drops = const <JourneyDropModel>[],
    this.evoRecipes = const <JourneyEvoRecipeModel>[],
    this.relicUnlocks = const <JourneyRelicUnlockModel>[],
    this.pickupConfigs = const <JourneyPickupConfigModel>[],
    this.dailyMaps = const <JourneyDailyMapModel>[],
    this.endlessWaves = const <JourneyEndlessWaveModel>[],
    this.weaponParams = const <String, Map<String, double>>{},
    this.monsterParams = const <String, Map<String, double>>{},
    this.globalsRaw,
    this.reviveMeritBase = 20,
    this.gameId = '',
    this.scoreDimIds = const <String, String>{},
    this.monsterCap = 120,
    this.initialPackSize = 24,
    this.spawnDenRatio = 0.70,
    this.talentDropRate = 0.10,
    this.charLevelCap = 99,
    required this.fromSeed,
  });

  /// 维度定义（code → def）；远端空表回落内置种子。
  Map<String, JourneySlotDefModel> slotDefMap() {
    final defs = slotDefs.isNotEmpty
        ? slotDefs
        : kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson).toList();
    return <String, JourneySlotDefModel>{for (final d in defs) d.code: d};
  }

  JourneyRegionModel? regionOf(String code) {
    for (final r in regions) {
      if (r.code == code) return r;
    }
    return null;
  }

  JourneyWeaponModel? weaponOf(String code) {
    for (final w in weapons) {
      if (w.code == code) return w;
    }
    return null;
  }

  /// 每日游历地图（code 匹配；仅内置兜底快照回落种子）。
  JourneyDailyMapModel? dailyMapOf(String code) {
    for (final m in dailyMapList()) {
      if (m.code == code) return m;
    }
    return null;
  }

  /// 无尽妖潮波次（wave_no 匹配；未配置该波走引擎内置公式）。
  JourneyEndlessWaveModel? endlessWaveOf(int waveNo) {
    for (final w in endlessWaves) {
      if (w.waveNo == waveNo) return w;
    }
    return null;
  }

  /// 每日游历地图列表：远端就绪时如实返回后台配置（空列表=后台全部
  /// 禁用，App 显示「今日暂无游历」）；仅内置兜底快照回落种子保离线可玩。
  List<JourneyDailyMapModel> dailyMapList() {
    if (!fromSeed) return dailyMaps;
    return kJourneyDailyMapSeed.map(JourneyDailyMapModel.fromJson).toList();
  }

  /// 法宝数值参数（weaponCode+参数 code 读取；行缺失回落 fallback）。
  double weaponParam(String weaponCode, String code, double fallback) {
    return weaponParams[weaponCode]?[code] ?? fallback;
  }

  /// 妖王能力参数（monsterCode+参数 code 读取；行缺失回落 fallback）。
  double monsterParam(String monsterCode, String code, double fallback) {
    return monsterParams[monsterCode]?[code] ?? fallback;
  }

  // ---- 通用成长卡/经验曲线（journey_globals 列；缺省走内置兜底）----

  /// 三选一通用成长卡·移动速度加成（upgrade_move）。
  double get upgradeMove => _globalDouble('upgrade_move', 0.09);

  /// 三选一通用成长卡·生命上限（upgrade_hp）。
  double get upgradeHp => _globalDouble('upgrade_hp', 20);

  /// 三选一通用成长卡·自动回复（upgrade_regen）。
  double get upgradeRegen => _globalDouble('upgrade_regen', 1);

  /// 三选一通用成长卡·拾取范围（upgrade_pickup）。
  double get upgradePickup => _globalDouble('upgrade_pickup', 18);

  /// 经验曲线基数（exp_base：升级所需 = base + 当前等级 × exp_per_lv）。
  double get expBase => _globalDouble('exp_base', 12);

  /// 经验曲线每级增量（exp_per_lv）。
  double get expPerLv => _globalDouble('exp_per_lv', 7);

  /// 每次升级提升的基础攻击力（level_attack_per_lv）。
  double get levelAttackPerLv =>
      _globalNum(globalsRaw, 'level_attack_per_lv') ?? kJourneyLevelAttackPerLv;

  /// 每次升级提升的生命上限（level_hp_per_lv）。
  double get levelHpPerLv =>
      _globalNum(globalsRaw, 'level_hp_per_lv') ?? kJourneyLevelHpPerLv;

  /// 攻击力成长卡单次提升量（upgrade_attack）。
  double get upgradeAttack =>
      _globalNum(globalsRaw, 'upgrade_attack') ?? kJourneyUpgradeAttack;

  /// 攻击力成长卡累计提升上限（attack_upgrade_cap）。
  double get attackUpgradeCap =>
      _globalNum(globalsRaw, 'attack_upgrade_cap') ?? kJourneyAttackUpgradeCap;

  /// 妖王血量时间项系数（boss_hp_time_k）。
  double get bossHpTimeK =>
      _globalNum(globalsRaw, 'boss_hp_time_k') ?? kJourneyBossHpTimeK;

  double _globalDouble(String key, double fallback) {
    // globals 原始行直读（列缺失/seed 快照 null 时回落内置兜底）
    return (globalsRaw?[key] as num?)?.toDouble() ?? fallback;
  }

  List<JourneyLevelModel> levelsOfRegion(String regionCode) =>
      levels.where((l) => l.regionCode == regionCode).toList()
        ..sort((a, b) => a.levelNo.compareTo(b.levelNo));

  /// 掉落表行（tableCode 组；未配置返回空列表，消费侧兜底）。
  List<JourneyDropModel> dropTableOf(String tableCode) =>
      drops.where((d) => d.tableCode == tableCode).toList();

  /// 武器第一条炼化配方（seq 升序首条；无配方返回 null）。
  JourneyEvoRecipeModel? evoRecipeOf(String weaponCode) {
    for (final r in evoRecipes) {
      if (r.weaponCode == weaponCode) return r;
    }
    return null;
  }

  /// 武器图鉴解锁定价（未配置返回 null）。
  JourneyRelicUnlockModel? relicOf(String weaponCode) {
    for (final r in relicUnlocks) {
      if (r.weaponCode == weaponCode) return r;
    }
    return null;
  }

  /// 拾取物配置（未配置返回 null）。
  JourneyPickupConfigModel? pickupConfigOf(String code) {
    for (final p in pickupConfigs) {
      if (p.code == code) return p;
    }
    return null;
  }

  /// 某角色的五行天赋分支（element/seq 升序）；该角色无远端行 → 内置
  /// 60 行种子按同角色过滤兜底，消费侧不死局。
  List<JourneyTalentBranchModel> branchesOf(String char) {
    final own =
        talentBranches.where((b) => b.characterCode == char).toList();
    if (own.isEmpty) {
      return buildJourneyTalentBranchSeed()
          .where((row) => row['character_code'] == char)
          .map(JourneyTalentBranchModel.fromJson)
          .toList();
    }
    return own..sort((a, b) {
      final byElement = a.element.compareTo(b.element);
      return byElement != 0 ? byElement : a.seq.compareTo(b.seq);
    });
  }

  /// 某角色某系某分支（远端行缺失回落内置种子行）。
  JourneyTalentBranchModel branchOf(
      String char, String element, String branchType) {
    for (final b in branchesOf(char)) {
      if (b.element == element && b.branchType == branchType) return b;
    }
    // 异常配置（分支行被删）：给中性默认分支
    return JourneyTalentBranchModel(
        id: '',
        characterCode: char,
        element: element,
        branchType: branchType,
        branchCode: journeyBranchCode(char, element, branchType),
        name: branchType,
        attrKey: branchType);
  }

  /// 还魂复活功德价 = 基准价 × 关卡号。
  int reviveCostFor(int levelNo) => reviveMeritBase * levelNo;
}
