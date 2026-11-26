/// 西行·数据模型（对应 journey_* 配置表行）。
///
/// 全部模型只含 App 消费列；fromJson 缺省字段给安全默认值，
/// 与 GameModel 解析惯例一致（后端新增列不崩）。
library;

import 'journey_talent_models.dart';

export 'journey_character_model.dart';
export 'journey_config_models.dart';
export 'journey_runtime_models.dart';
export 'journey_weapon_level_model.dart';

/// 区域（关卡分组；远端 38 章段，boss_code=本段妖王驱动妖王战）
class JourneyRegionModel {
  final String code;
  final String name;
  final int seq;
  final String themeColor;

  /// 本章段妖王编码（NULL=叙事段无妖王战）；App 优先用它驱动妖王，
  /// 为空时回落引擎内置映射。
  final String? bossCode;

  const JourneyRegionModel({
    required this.code,
    required this.name,
    required this.seq,
    required this.themeColor,
    this.bossCode,
  });

  factory JourneyRegionModel.fromJson(Map<String, dynamic> json) {
    return JourneyRegionModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      themeColor: json['theme_color'] as String? ?? '#E8C470',
      bossCode: json['boss_code'] as String?,
    );
  }
}

/// 关卡（一关=一难；远端行=game_levels，西行属性在 journey_levels 子表）
class JourneyLevelModel {
  /// 远端行 id（game_levels.id）：按需拉取该关的波次/热区/参照物配置；
  /// 内置兜底关卡无 id（空串→引擎走兜底刷怪）。
  final String id;
  final int levelNo;
  final String title;
  final String regionCode;
  final String kind;

  /// 本关妖王编码（journey_levels.boss_code；NULL/空=沿用本段区域妖王）。
  /// 车迟国三关借此各挂虎力/鹿力/羊力，实现原著三场斗法。
  final String? bossCode;

  final int bossFights;
  final int durationTargetSec;
  final int suggestPower;
  final int firstClearMerit;

  /// 难度系数（game_levels.difficulty，后台可调）：怪物属性乘区数据源；
  /// 远端缺省回落难号。
  final int difficulty;

  const JourneyLevelModel({
    this.id = '',
    required this.levelNo,
    required this.title,
    required this.regionCode,
    this.kind = 'battle',
    this.bossCode,
    this.bossFights = 1,
    this.durationTargetSec = 600,
    this.suggestPower = 0,
    this.firstClearMerit = 0,
    int? difficulty,
  }) : difficulty = difficulty ?? levelNo;

  factory JourneyLevelModel.fromJson(Map<String, dynamic> json) {
    final levelNo = (json['level_no'] as num?)?.toInt() ?? 0;
    return JourneyLevelModel(
      id: json['id'] as String? ?? '',
      levelNo: levelNo,
      // 远端 game_levels 列名=name，seed 键=title，双源兼容
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      regionCode: json['region_code'] as String? ?? '',
      kind: json['level_kind'] as String? ?? 'battle',
      bossCode: json['boss_code'] as String?,
      bossFights: (json['boss_fights'] as num?)?.toInt() ?? 1,
      durationTargetSec: (json['duration_target_sec'] as num?)?.toInt() ?? 600,
      suggestPower: (json['suggest_power'] as num?)?.toInt() ?? 0,
      firstClearMerit: (json['first_clear_merit'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toInt(),
    );
  }

  bool get isStory => kind == 'story';
}

/// 角色（journey_character_model.dart）：aura/realm jsonb 解析器
/// 随角色模型独立成文件，经 export 保持原 import 点不变。

/// 法宝（主动/被动/特效三分类共用主表）
class JourneyWeaponModel {
  final String code;
  final String name;
  final String category; // active / passive / effect
  final String attackKind;
  final String desc;

  // 主动法宝初始环绕参数（后台 journey_weapons 可配；0/空=未配置走引擎兜底）
  final double orbitSpeed; // 转速基准（rad/s）
  final double innerRadius; // 环带内缘
  final double outerRadius; // 臂长（环带外缘）
  final double bladeWidth; // 臂宽（扇叶宽度基准）
  final double baseDamage; // 基础伤害（分级表缺失时兜底）
  final String starterEffect; // 初始特效槽 code（pierce/knockback/burn/lifesteal）

  // 非常规形态的基础参数（journey_weapons 可配；0=未配置走引擎兜底）
  final double baseIntervalMs; // 发射/投掷/扫击周期兜底（projectile/boomerang/beam）
  final double projectileSpeed; // 弹体飞行速度（projectile/boomerang）
  final int pierce; // 穿透个数（projectile）
  final double aoeRadius; // 领域/光束半径（aura/beam/magnet）
  final double rangePx; // 最大射程（projectile/boomerang/beam）

  /// 归属角色（空=通用法宝；非空=跟随该角色解锁，角色未解锁不可解锁）
  final String characterCode;

  /// 出处（非取经角色的法宝来源，如 哪吒/太上老君；纯展示不影响解锁）
  final String ownerName;

  const JourneyWeaponModel({
    required this.code,
    required this.name,
    required this.category,
    required this.attackKind,
    required this.desc,
    this.orbitSpeed = 0,
    this.innerRadius = 0,
    this.outerRadius = 0,
    this.bladeWidth = 0,
    this.baseDamage = 0,
    this.starterEffect = '',
    this.baseIntervalMs = 0,
    this.projectileSpeed = 0,
    this.pierce = 0,
    this.aoeRadius = 0,
    this.rangePx = 0,
    this.characterCode = '',
    this.ownerName = '',
  });

  factory JourneyWeaponModel.fromJson(Map<String, dynamic> json) {
    return JourneyWeaponModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'active',
      attackKind: json['attack_kind'] as String? ?? '',
      desc: json['description'] as String? ?? '',
      orbitSpeed: (json['orbit_speed'] as num?)?.toDouble() ?? 0,
      innerRadius: (json['inner_radius'] as num?)?.toDouble() ?? 0,
      outerRadius: (json['outer_radius'] as num?)?.toDouble() ?? 0,
      bladeWidth: (json['blade_width'] as num?)?.toDouble() ?? 0,
      baseDamage: (json['base_damage'] as num?)?.toDouble() ?? 0,
      starterEffect: json['starter_effect'] as String? ?? '',
      baseIntervalMs: (json['base_interval_ms'] as num?)?.toDouble() ?? 0,
      projectileSpeed: (json['projectile_speed'] as num?)?.toDouble() ?? 0,
      pierce: (json['pierce'] as num?)?.toInt() ?? 0,
      aoeRadius: (json['aoe_radius'] as num?)?.toDouble() ?? 0,
      rangePx: (json['range_px'] as num?)?.toDouble() ?? 0,
      characterCode: json['character_code'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
    );
  }

  bool get isActive => category == 'active';
  bool get isPassive => category == 'passive';
  bool get isEffect => category == 'effect';
}

/// 法宝数值参数（journey_weapon_params 行）：code=参数语义键（引擎逻辑
/// 判断用，如 move/hp/period），value_num=数值；后台独立页签可配，
/// 引擎按法宝 code+参数 code 读取，行缺失回落内置兜底。
class JourneyWeaponParamModel {
  final String weaponCode;
  final String code;
  final double value;

  const JourneyWeaponParamModel({
    required this.weaponCode,
    required this.code,
    required this.value,
  });

  factory JourneyWeaponParamModel.fromJson(Map<String, dynamic> json) {
    return JourneyWeaponParamModel(
      weaponCode: json['weapon_code'] as String? ?? '',
      code: json['code'] as String? ?? '',
      value: (json['value_num'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 怪物（journey_monsters 行）
class JourneyMonsterModel {
  final String code;
  final String name;
  final String aiTier; // normal / elite / boss
  final int baseHp;
  final double baseSpeed;
  final int contactDamage;
  final double sizeScale;
  final int expDrop;
  final int meritDrop;

  /// 妖王能力（西游记背景扩展；空=无特殊能力，后台怪物页签可配）：
  /// 原有：unmovable/swift_wind/roc_speed/samadhi_fire/bone_split/gourd_pull/
  /// iron_horn/spider_web/blood_frenzy/poison_mist；
  /// 新增：inner_core/fake_body/water_prison/five_thunder/ice_seal/mirror/
  /// root_bind/golden_bag/devour/three_bells/spear_thrust/earth_trap/
  /// plum_flower/nine_seize/ice_charge/moon_guard/tiger_pounce/black_wind/
  /// deer_belly/ram_oil；
  /// 稀有扩展：sleeve_cosmos/heavenly_eye/banana_storm/five_mountain/
  /// golden_bell/silk_fate/trunk_coil/swallow_sky/pure_dew/lotus_guard/
  /// ghost_fog/divine_fire，另有 shield_break/execute。
  final String abilityKey;

  /// 能力键列表（journey_monster_abilities 承载；空=沿用单值 abilityKey）。
  /// 新表有行时按 slot 升序填入，构建时已过滤 enabled=false 的行。
  final List<String> abilityKeys;

  /// 新表是否有该妖王的能力行（即使全部关闭也为 true）。
  /// 用于区分「未配置，回落主表单值」与「配置了但全部关闭，确实无能力」。
  final bool hasAbilityRows;

  const JourneyMonsterModel({
    required this.code,
    required this.name,
    required this.aiTier,
    required this.baseHp,
    required this.baseSpeed,
    required this.contactDamage,
    this.sizeScale = 1,
    this.expDrop = 5,
    this.meritDrop = 0,
    this.abilityKey = '',
    this.abilityKeys = const <String>[],
    this.hasAbilityRows = false,
  });

  factory JourneyMonsterModel.fromJson(Map<String, dynamic> json) {
    return JourneyMonsterModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      aiTier: json['ai_tier'] as String? ?? 'normal',
      baseHp: (json['base_hp'] as num?)?.toInt() ?? 10,
      baseSpeed: (json['base_speed'] as num?)?.toDouble() ?? 60,
      contactDamage: (json['contact_damage'] as num?)?.toInt() ?? 5,
      sizeScale: (json['size_scale'] as num?)?.toDouble() ?? 1,
      expDrop: (json['exp_drop'] as num?)?.toInt() ?? 5,
      meritDrop: (json['merit_drop'] as num?)?.toInt() ?? 0,
      abilityKey: json['ability_key'] as String? ?? '',
    );
  }

  bool get isBoss => aiTier == 'boss';
  bool get isElite => aiTier == 'elite';

  /// 生效能力键集合：新表有行时以其为准（即使全部关闭也返回空，不回落
  /// 主表单值，否则后台的关闭开关会失效）；无行才回落单值 abilityKey。
  List<String> get effectiveAbilityKeys => hasAbilityRows
      ? abilityKeys
      : (abilityKey.isEmpty ? const <String>[] : <String>[abilityKey]);

  /// 是否持有指定能力（覆盖所有按单值 abilityKey 判定的旧调用点）。
  bool hasAbility(String key) => effectiveAbilityKeys.contains(key);

  JourneyMonsterModel withAbilityKeys(List<String> keys) => JourneyMonsterModel(
        code: code,
        name: name,
        aiTier: aiTier,
        baseHp: baseHp,
        baseSpeed: baseSpeed,
        contactDamage: contactDamage,
        sizeScale: sizeScale,
        expDrop: expDrop,
        meritDrop: meritDrop,
        abilityKey: abilityKey,
        // 后台重复配置同一能力键时去重，避免同帧重复派发。
        abilityKeys: keys.toSet().toList(),
        hasAbilityRows: true,
      );
}

/// 妖王能力行（journey_monster_abilities）：一妖多能力的承载行。
class JourneyMonsterAbilityModel {
  final String id;
  final String monsterId;
  final int slot;
  final String abilityKey;
  final bool enabled;

  const JourneyMonsterAbilityModel({
    required this.id,
    required this.monsterId,
    required this.slot,
    required this.abilityKey,
    this.enabled = true,
  });

  factory JourneyMonsterAbilityModel.fromJson(Map<String, dynamic> json) {
    return JourneyMonsterAbilityModel(
      id: json['id'] as String? ?? '',
      monsterId: json['monster_id'] as String? ?? '',
      slot: (json['slot'] as num?)?.toInt() ?? 0,
      abilityKey: json['ability_key'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// 同关逐战妖王编排（journey_level_boss_fights）：一行一场。
class JourneyLevelBossFightModel {
  final String id;
  final String levelId;
  final int fightNo;
  final String bossCode;
  final String note;

  const JourneyLevelBossFightModel({
    required this.id,
    required this.levelId,
    required this.fightNo,
    required this.bossCode,
    this.note = '',
  });

  factory JourneyLevelBossFightModel.fromJson(Map<String, dynamic> json) {
    return JourneyLevelBossFightModel(
      id: json['id'] as String? ?? '',
      levelId: json['level_id'] as String? ?? '',
      fightNo: (json['fight_no'] as num?)?.toInt() ?? 1,
      bossCode: json['boss_code'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

/// 每日游历地图（journey_daily_maps 行）：运营后台可配的地图列表，
/// 用户每日任选其一进入（每日一次，进入即计次）。
class JourneyDailyMapModel {
  final String code;
  final String name;
  final String themeColor; // hex（#RRGGBB），驱动地图渲染
  final int milestoneLi; // 里程碑里数（进关播报）
  final String desc;

  /// 按图怪物池（journey_daily_maps.monster_pool，逗号分隔怪 code；
  /// 空=引擎内置全怪池兜底）。App 拆分后过滤刷怪池。
  final List<String> monsterPool;

  const JourneyDailyMapModel({
    required this.code,
    required this.name,
    this.themeColor = '#E8C470',
    this.milestoneLi = 800,
    this.desc = '',
    this.monsterPool = const <String>[],
  });

  factory JourneyDailyMapModel.fromJson(Map<String, dynamic> json) {
    return JourneyDailyMapModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      themeColor: json['theme_color'] as String? ?? '#E8C470',
      milestoneLi: (json['milestone_li'] as num?)?.toInt() ?? 800,
      desc: json['description'] as String? ?? '',
      monsterPool: ((json['monster_pool'] as String?) ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

/// 无尽妖潮波次（journey_endless_waves 行，上限 99）：后台可配的独立
/// 波次表——boss_count>0 即妖王波（妖王种类引擎随机），普通怪按 count
/// 分批刷怪、monster_code 指定普通段/护卫怪种（留空=分阶随机池）；
/// elite_count 指定本波末尾的精英只数（0=引擎按波号公式兜底）；
/// boss_count 指定妖潮期本波妖王配额（0=引擎按全局公式兜底）；
/// buff_mult 覆盖内置增强曲线；未配置的波回落内置公式。
class JourneyEndlessWaveModel {
  final int waveNo;
  final String monsterCode;
  final int count;
  final double buffMult;
  final int eliteCount;

  /// 本波妖王配额（妖潮期生效；0=按全局基数+递增公式兜底，≤10）。
  final int bossCount;

  const JourneyEndlessWaveModel({
    required this.waveNo,
    required this.monsterCode,
    this.count = 10,
    this.buffMult = 1,
    this.eliteCount = 0,
    this.bossCount = 0,
  });

  factory JourneyEndlessWaveModel.fromJson(Map<String, dynamic> json) {
    return JourneyEndlessWaveModel(
      waveNo: (json['wave_no'] as num?)?.toInt() ?? 0,
      monsterCode: json['monster_code'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 10,
      buffMult: (json['buff_mult'] as num?)?.toDouble() ?? 1,
      eliteCount: (json['elite_count'] as num?)?.toInt() ?? 0,
      bossCount: (json['boss_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 武器维度槽定义（journey_weapon_slots 行）：6 主动槽=维度槽（非 6 件
/// 武器）——初始武器占 1 特效槽，空槽由三选一「习得」卡填入新维度，
/// 已入槽维度可升级至上限；每级效果与上限由运营配置。
class JourneySlotDefModel {
  final String code;
  final String name;
  final String kind; // attribute / effect
  final String effectPerLevel;
  final int maxLevel;

  /// 每级数值（value_per_level 列；0=未配置走引擎内置兜底）。
  final double valuePerLevel;

  /// 周期触发秒数（period_sec 列；仅回元/护体等周期槽使用，0=回落引擎兜底）。
  final double periodSec;

  const JourneySlotDefModel({
    required this.code,
    required this.name,
    required this.kind,
    required this.effectPerLevel,
    required this.maxLevel,
    this.valuePerLevel = 0,
    this.periodSec = 0,
  });

  factory JourneySlotDefModel.fromJson(Map<String, dynamic> json) {
    return JourneySlotDefModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'effect',
      effectPerLevel: json['effect_per_level'] as String? ?? '',
      maxLevel: (json['max_level'] as num?)?.toInt() ?? 3,
      valuePerLevel: (json['value_per_level'] as num?)?.toDouble() ?? 0,
      periodSec: (json['period_sec'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 三选一基础值成长卡（journey_upgrade_cards）：伏魔真力/筋斗云气/
/// 蟠桃益气/木灵回春/紫金磁引五张常驻成长项。名称、每级数值、是否入池
/// 均后台可配；展示文案由引擎按 code + 数值生成，避免文案与数值两处脱节。
/// 抽卡权重只在四类之间配置（economy 组 choice_weight_*），类内均匀随机。
/// 远端表未就绪时回落内置种子。
class JourneyUpgradeCardModel {
  final String code;
  final String name;
  final double value;
  final bool enabled;
  final int sortOrder;

  const JourneyUpgradeCardModel({
    required this.code,
    required this.name,
    required this.value,
    this.enabled = true,
    this.sortOrder = 0,
  });

  factory JourneyUpgradeCardModel.fromJson(Map<String, dynamic> json) {
    return JourneyUpgradeCardModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 用户进度（本地聚合：功德余额/最远关/角色天赋进度/流水/解锁记录）。
class JourneyProgressModel {
  final int meritBalance;
  final int farthestLevelNo;
  final int totalKills;

  /// 全账号共享天赋点池（单 int：任意角色点亮消耗同一池，点完即所有
  /// 角色均无点可点；总量受首通/妖王掉点约束，点池本身不设上限）。
  final int talentPool;

  /// 天赋分支等级（charCode → branchCode → 0..maxLv；角色专属树改版：
  /// 每角色一棵五行树，分支编码约定 '{char}_{element}_' 前缀）。
  final Map<String, Map<String, int>> talentLevels;

  /// 功德流水（新的在前，上限 50）。
  final List<JourneyMeritRecordModel> meritRecords;

  /// 西行记录（新的在前，上限 50）。
  final List<JourneyRunRecordModel> runRecords;

  final Set<String> unlockedCharacters;
  final Set<String> unlockedWeapons;

  /// 已解锁成就 code（本地缓存；远端真源 = user_game_achievements）。
  final Set<String> unlockedAchievements;

  /// 每日游历 gate：最近一次进图的北京日期键（yyyyMMdd）。
  /// 与进度双写远端 journey_progress.last_daily_date，清本地缓存后
  /// 由远端恢复，防止绕过「每日一次」。空=从未游历。
  final String lastDailyDate;

  /// 累计获得功德（仅正向入账求和）：远端 journey_progress.total_merit_earned
  /// 为真源，作为 merit_earned 成就判定口径，不依赖本地流水完整性。
  final int totalMeritEarned;

  const JourneyProgressModel({
    this.meritBalance = 0,
    this.farthestLevelNo = 0,
    this.totalKills = 0,
    this.talentPool = 0,
    this.talentLevels = const <String, Map<String, int>>{},
    this.meritRecords = const <JourneyMeritRecordModel>[],
    this.runRecords = const <JourneyRunRecordModel>[],
    this.unlockedCharacters = const <String>{},
    this.unlockedWeapons = const <String>{},
    this.unlockedAchievements = const <String>{},
    this.lastDailyDate = '',
    this.totalMeritEarned = 0,
  });

  bool characterUnlocked(String code) =>
      code == 'tang' || unlockedCharacters.contains(code);

  bool weaponUnlocked(String code) => unlockedWeapons.contains(code);

  /// 五行轨迹已点亮层数（v4 分支树：key 即分支编码，未点亮 0）。
  int talentLevelOf(String char, String branchCode) =>
      talentLevels[char]?[branchCode] ?? 0;

  /// 某系总层数（core+growth+sig 三分支和，0..16）。
  int talentElementLv(String char, String element) {
    var total = 0;
    for (final b in kJourneyTalentBranchTypes) {
      total += talentLevelOf(char, journeyBranchCode(char, element, b));
    }
    return total;
  }

  /// 加强点是否已点亮（五系修满 80 层后消耗第 81 点）。
  bool talentEnhanceLit(String char) =>
      (talentLevels[char]?[kJourneyTalentEnhanceKey] ?? 0) > 0;

  /// 角色本树已修总层数（全系层数和）。
  int talentSpentLayers(String char) {
    var total = 0;
    (talentLevels[char] ?? const <String, int>{}).forEach((_, lv) {
      total += lv;
    });
    return total;
  }
}
