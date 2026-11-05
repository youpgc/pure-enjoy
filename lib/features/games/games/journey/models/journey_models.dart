/// 西行·数据模型（对应 journey_* 配置表行）。
///
/// 全部模型只含 App 消费列；fromJson 缺省字段给安全默认值，
/// 与 GameModel 解析惯例一致（后端新增列不崩）。
library;

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

  const JourneyCharacterModel({
    required this.code,
    required this.name,
    required this.baseHp,
    required this.auraName,
    required this.auraDesc,
    required this.weaponCode,
    this.unlockLevelNo = 0,
    this.unlockMeritCost = 0,
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

  const JourneyWeaponModel({
    required this.code,
    required this.name,
    required this.category,
    required this.attackKind,
    required this.desc,
  });

  factory JourneyWeaponModel.fromJson(Map<String, dynamic> json) {
    return JourneyWeaponModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'active',
      attackKind: json['attack_kind'] as String? ?? '',
      desc: json['description'] as String? ?? '',
    );
  }

  bool get isActive => category == 'active';
  bool get isPassive => category == 'passive';
  bool get isEffect => category == 'effect';
}

/// 五行天赋层（5 系×(16 常规+1 标志强化)=85 层；天赋点总量 81 不可全满）。
class JourneyTalentModel {
  final String element; // metal/wood/water/fire/earth
  final int seq;
  final String name;
  final String attrKey;
  final double valuePerLevel;
  final bool isSignature;
  final String signatureDesc;

  const JourneyTalentModel({
    required this.element,
    required this.seq,
    required this.name,
    required this.attrKey,
    required this.valuePerLevel,
    this.isSignature = false,
    this.signatureDesc = '',
  });

  factory JourneyTalentModel.fromJson(Map<String, dynamic> json) {
    return JourneyTalentModel(
      element: json['element'] as String? ?? 'metal',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      attrKey: json['attr_key'] as String? ?? '',
      valuePerLevel: (json['value_per_level'] as num?)?.toDouble() ?? 0,
      isSignature: json['is_signature'] as bool? ?? false,
      signatureDesc: json['signature_desc'] as String? ?? '',
    );
  }

  /// 相生前置：点本层前「生我者」元素需要的最少层数（0=无前置）。
  /// 相生链：金←土、水←金、木←水、火←木、土←火。
  int prereqFrom() {
    if (seq <= 6) return 0;
    if (seq <= 12) return 6;
    if (seq <= 16) return 12;
    return 0; // 标志层前置单独判定（本系满 16+克我者≥4）
  }

  /// 标志层（第 17 层）的克衡前置：「克我者」元素最少层数。
  static const int signaturePrereqRestrainer = 4;
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
    );
  }

  bool get isBoss => aiTier == 'boss';
  bool get isElite => aiTier == 'elite';
}

/// 波次（journey_waves 行）：start_sec 起每 spawn_interval_ms 刷 count 只
/// monster_code，该波怪物属性乘 buff_mult——关卡刷怪全配置驱动。
class JourneyWaveModel {
  final int seq;
  final int startSec;
  final String monsterCode;
  final int count;
  final int spawnIntervalMs;
  final double buffMult;

  const JourneyWaveModel({
    required this.seq,
    required this.startSec,
    required this.monsterCode,
    required this.count,
    this.spawnIntervalMs = 1000,
    this.buffMult = 1.0,
  });

  factory JourneyWaveModel.fromJson(Map<String, dynamic> json) {
    return JourneyWaveModel(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      startSec: (json['start_sec'] as num?)?.toInt() ?? 0,
      monsterCode: json['monster_code'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      spawnIntervalMs: (json['spawn_interval_ms'] as num?)?.toInt() ?? 1000,
      buffMult: (json['buff_mult'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// 密度热区（journey_heat_zones 行）：demon_den=妖穴（刷怪集中），
/// safe_valley=安全谷（范围内不刷怪）。
class JourneyHeatZoneModel {
  final String kind; // demon_den / safe_valley
  final double x;
  final double y;
  final double radius;
  final double densityMult;

  const JourneyHeatZoneModel({
    required this.kind,
    required this.x,
    required this.y,
    required this.radius,
    this.densityMult = 1.0,
  });

  factory JourneyHeatZoneModel.fromJson(Map<String, dynamic> json) {
    return JourneyHeatZoneModel(
      kind: json['kind'] as String? ?? 'demon_den',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      radius: (json['radius'] as num?)?.toDouble() ?? 1,
      densityMult: (json['density_mult'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// 地图参照物（journey_map_objects 行）：关卡地图上的静态物件，
/// 渲染主题色按 kind 区分；破坏/掉落交互待后续批次。
class JourneyMapObjectModel {
  final String kind; // breakable/unbreakable/chest_point/milestone/waypoint
  final double x;
  final double y;
  final double radius;
  final int hp;
  final String? dropTableCode;

  const JourneyMapObjectModel({
    required this.kind,
    required this.x,
    required this.y,
    required this.radius,
    this.hp = 0,
    this.dropTableCode,
  });

  factory JourneyMapObjectModel.fromJson(Map<String, dynamic> json) {
    return JourneyMapObjectModel(
      kind: json['kind'] as String? ?? 'unbreakable',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      radius: (json['radius'] as num?)?.toDouble() ?? 1,
      hp: (json['hp'] as num?)?.toInt() ?? 0,
      dropTableCode: json['drop_table_code'] as String?,
    );
  }
}

/// 单关运行时配置（进关时按 level_id 从远端拉取；空=引擎走兜底刷怪）。
class JourneyLevelRuntime {
  final List<JourneyWaveModel> waves;
  final List<JourneyHeatZoneModel> heatZones;
  final List<JourneyMapObjectModel> mapObjects;

  const JourneyLevelRuntime({
    this.waves = const <JourneyWaveModel>[],
    this.heatZones = const <JourneyHeatZoneModel>[],
    this.mapObjects = const <JourneyMapObjectModel>[],
  });

  bool get isEmpty => waves.isEmpty && heatZones.isEmpty && mapObjects.isEmpty;
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

  const JourneySlotDefModel({
    required this.code,
    required this.name,
    required this.kind,
    required this.effectPerLevel,
    required this.maxLevel,
  });

  factory JourneySlotDefModel.fromJson(Map<String, dynamic> json) {
    return JourneySlotDefModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'effect',
      effectPerLevel: json['effect_per_level'] as String? ?? '',
      maxLevel: (json['max_level'] as num?)?.toInt() ?? 3,
    );
  }
}

/// 用户进度（journey_progress / journey_talent_points / journey_unlocks 聚合）
class JourneyProgressModel {
  final int meritBalance;
  final int farthestLevelNo;
  final int totalKills;
  final int talentPool; // 可分配天赋点（首通 1 点/难，总量 81）
  final Map<String, int> talentPoints; // talentKey(element:seq) -> points
  final Set<String> unlockedCharacters;
  final Set<String> unlockedWeapons;

  const JourneyProgressModel({
    this.meritBalance = 0,
    this.farthestLevelNo = 0,
    this.totalKills = 0,
    this.talentPool = 0,
    this.talentPoints = const <String, int>{},
    this.unlockedCharacters = const <String>{},
    this.unlockedWeapons = const <String>{},
  });

  bool characterUnlocked(String code) =>
      code == 'tang' || unlockedCharacters.contains(code);

  bool weaponUnlocked(String code) => unlockedWeapons.contains(code);

  int talentPointsOf(String element, int seq) =>
      talentPoints['$element:$seq'] ?? 0;

  /// 某元素已投总层数（按层取点，等于该系最高已点亮层号）。
  int talentLevelsOf(String element) {
    var count = 0;
    for (var i = 1; i <= 17; i++) {
      if (talentPoints['$element:$i'] != null) count++;
    }
    return count;
  }
}
