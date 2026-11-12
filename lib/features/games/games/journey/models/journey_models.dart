/// 西行·数据模型（对应 journey_* 配置表行）。
///
/// 全部模型只含 App 消费列；fromJson 缺省字段给安全默认值，
/// 与 GameModel 解析惯例一致（后端新增列不崩）。
library;

import 'journey_talent_models.dart';

export 'journey_config_models.dart';
export 'journey_runtime_models.dart';

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

/// 关卡（一关=一难；远端行=game_levels，西行属性在 config jsonb）
class JourneyLevelModel {
  /// 远端行 id（game_levels.id）：按需拉取该关的波次/热区/参照物配置；
  /// 内置兜底关卡无 id（空串→引擎走兜底刷怪）。
  final String id;
  final int levelNo;
  final String title;
  final String regionCode;
  final String kind;
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
      bossFights: (json['boss_fights'] as num?)?.toInt() ?? 1,
      durationTargetSec: (json['duration_target_sec'] as num?)?.toInt() ?? 600,
      suggestPower: (json['suggest_power'] as num?)?.toInt() ?? 0,
      firstClearMerit: (json['first_clear_merit'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toInt(),
    );
  }

  bool get isStory => kind == 'story';
}

/// 角色
class JourneyCharacterModel {
  final String code;
  final String name;
  final int baseHp;
  final String auraName;
  final String auraDesc;
  final String weaponCode;
  final int unlockLevelNo;
  final int unlockMeritCost;

  /// 开放/禁用开关（journey_characters.enabled，后台管理）；
  /// 禁用角色不出现在角色组/天赋页/出战舞台。缺省 true=开放。
  final bool enabled;

  const JourneyCharacterModel({
    required this.code,
    required this.name,
    required this.baseHp,
    required this.auraName,
    required this.auraDesc,
    required this.weaponCode,
    this.unlockLevelNo = 0,
    this.unlockMeritCost = 0,
    this.enabled = true,
  });

  factory JourneyCharacterModel.fromJson(Map<String, dynamic> json) {
    return JourneyCharacterModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseHp: (json['base_hp'] as num?)?.toInt() ?? 100,
      auraName: json['aura_name'] as String? ?? '',
      auraDesc: json['aura_desc'] as String? ?? '',
      weaponCode: json['weapon_code'] as String? ?? '',
      unlockLevelNo: (json['unlock_level_no'] as num?)?.toInt() ?? 0,
      unlockMeritCost: (json['unlock_merit_cost'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

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
class JourneyMonsterModel {  final String code;
  final String name;
  final String aiTier; // normal / elite / boss
  final int baseHp;
  final double baseSpeed;
  final int contactDamage;
  final double sizeScale;
  final int expDrop;
  final int meritDrop;

  /// 妖王能力（西游记背景扩展；空=无特殊能力，后台怪物页签可配）：
  /// unmovable/swift_wind/roc_speed/samadhi_fire/bone_split/gourd_pull/
  /// iron_horn/spider_web/blood_frenzy/poison_mist
  final String abilityKey;

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
}

/// 每日游历地图（journey_daily_maps 行）：运营后台可配的地图列表，
/// 用户每日任选其一进入（每日一次，进入即计次）。
class JourneyDailyMapModel {
  final String code;
  final String name;
  final String themeColor; // hex（#RRGGBB），驱动地图渲染
  final int milestoneLi; // 里程碑里数（进关播报）
  final int durationTargetSec; // 功成坚持时长（0=用虚拟关缺省 300）
  final String desc;

  /// 按图怪物池（journey_daily_maps.monster_pool，逗号分隔怪 code；
  /// 空=引擎内置全怪池兜底）。App 拆分后过滤刷怪池。
  final List<String> monsterPool;

  const JourneyDailyMapModel({
    required this.code,
    required this.name,
    this.themeColor = '#E8C470',
    this.milestoneLi = 800,
    this.durationTargetSec = 0,
    this.desc = '',
    this.monsterPool = const <String>[],
  });

  factory JourneyDailyMapModel.fromJson(Map<String, dynamic> json) {
    return JourneyDailyMapModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      themeColor: json['theme_color'] as String? ?? '#E8C470',
      milestoneLi: (json['milestone_li'] as num?)?.toInt() ?? 800,
      durationTargetSec:
          (json['duration_target_sec'] as num?)?.toInt() ?? 0,
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
/// 波次表——monster_code 命中妖王即妖王波（首只妖王 + 小怪护卫），否则
/// 按 count 分批刷怪；elite_count 指定本波末尾的精英只数（0=引擎按波号
/// 公式兜底）；buff_mult 覆盖内置增强曲线；未配置的波回落内置公式。
class JourneyEndlessWaveModel {
  final int waveNo;
  final String monsterCode;
  final int count;
  final double buffMult;
  final int eliteCount;

  const JourneyEndlessWaveModel({
    required this.waveNo,
    required this.monsterCode,
    this.count = 10,
    this.buffMult = 1,
    this.eliteCount = 0,
  });

  factory JourneyEndlessWaveModel.fromJson(Map<String, dynamic> json) {
    return JourneyEndlessWaveModel(
      waveNo: (json['wave_no'] as num?)?.toInt() ?? 0,
      monsterCode: json['monster_code'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 10,
      buffMult: (json['buff_mult'] as num?)?.toDouble() ?? 1,
      eliteCount: (json['elite_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 法宝分级（journey_weapon_levels 行）：法宝 1~8 级数值；
/// 环绕形态消费 damage，projectile 等形态消费 interval_ms。
class JourneyWeaponLevelModel {
  final int lv;
  final int damage;
  final int intervalMs;

  const JourneyWeaponLevelModel({
    required this.lv,
    this.damage = 0,
    this.intervalMs = 0,
  });

  factory JourneyWeaponLevelModel.fromJson(Map<String, dynamic> json) {
    return JourneyWeaponLevelModel(
      lv: (json['lv'] as num?)?.toInt() ?? 0,
      damage: (json['damage'] as num?)?.toInt() ?? 0,
      intervalMs: (json['interval_ms'] as num?)?.toInt() ?? 0,
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

  const JourneySlotDefModel({
    required this.code,
    required this.name,
    required this.kind,
    required this.effectPerLevel,
    required this.maxLevel,
    this.valuePerLevel = 0,
  });

  factory JourneySlotDefModel.fromJson(Map<String, dynamic> json) {
    return JourneySlotDefModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'effect',
      effectPerLevel: json['effect_per_level'] as String? ?? '',
      maxLevel: (json['max_level'] as num?)?.toInt() ?? 3,
      valuePerLevel: (json['value_per_level'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 用户进度（本地聚合：功德余额/最远关/角色天赋进度/流水/解锁记录）。
class JourneyProgressModel {
  final int meritBalance;
  final int farthestLevelNo;
  final int totalKills;

  /// 每角色独立天赋点池（charCode → 剩余点数，各 ≤81；
  /// 首通每难全部角色池各 +1）。
  final Map<String, int> talentPools;

  /// 天赋分支等级（charCode → branchCode → 0..maxLv；角色专属树改版：
  /// 每角色一棵五行树，分支编码约定 '{char}_{element}_' 前缀）。
  final Map<String, Map<String, int>> talentLevels;

  /// 功德流水（新的在前，上限 50）。
  final List<JourneyMeritRecordModel> meritRecords;

  /// 对局记录（新的在前，上限 50）。
  final List<JourneyRunRecordModel> runRecords;

  final Set<String> unlockedCharacters;
  final Set<String> unlockedWeapons;

  /// 已解锁成就 code（本地缓存；远端真源 = user_game_achievements）。
  final Set<String> unlockedAchievements;

  const JourneyProgressModel({
    this.meritBalance = 0,
    this.farthestLevelNo = 0,
    this.totalKills = 0,
    this.talentPools = const <String, int>{},
    this.talentLevels = const <String, Map<String, int>>{},
    this.meritRecords = const <JourneyMeritRecordModel>[],
    this.runRecords = const <JourneyRunRecordModel>[],
    this.unlockedCharacters = const <String>{},
    this.unlockedWeapons = const <String>{},
    this.unlockedAchievements = const <String>{},
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

  /// 角色天赋点池剩余点数（未初始化 0）。
  int talentPoolOf(String char) => talentPools[char] ?? 0;

  /// 角色本树已修总层数（全系层数和）。
  int talentSpentLayers(String char) {
    var total = 0;
    (talentLevels[char] ?? const <String, int>{}).forEach((_, lv) {
      total += lv;
    });
    return total;
  }
}
