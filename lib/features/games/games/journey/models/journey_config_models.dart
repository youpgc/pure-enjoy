/// 西行·局外玩法配置模型（对应 journey_drops / journey_evo_recipes /
/// journey_relic_unlocks / journey_pickups 行）。
///
/// 模型只含 App 消费列；fromJson 缺省字段给安全默认值，与
/// journey_models.dart 解析惯例一致（后端新增列不崩）。
/// journey_models.dart export 本文件，统一从该入口引用。
library;

/// 掉落表行（journey_drops 行）：table_code 组内按 weight 概率掉落，
/// 数量取 qty_min~qty_max；weight=0 行不掉落，pickup_code 空=空掉落。
class JourneyDropModel {
  final String tableCode;

  /// 掉落来源（monster / breakable）。
  final String sourceKind;

  /// 拾取物 code（breakable 组「空掉落」行为 null）。
  final String? pickupCode;
  final int weight;
  final int qtyMin;
  final int qtyMax;

  const JourneyDropModel({
    required this.tableCode,
    this.sourceKind = 'monster',
    this.pickupCode,
    this.weight = 0,
    this.qtyMin = 0,
    this.qtyMax = 0,
  });

  factory JourneyDropModel.fromJson(Map<String, dynamic> json) {
    return JourneyDropModel(
      tableCode: json['table_code'] as String? ?? '',
      sourceKind: json['source_kind'] as String? ?? 'monster',
      pickupCode: json['pickup_code'] as String?,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      qtyMin: (json['qty_min'] as num?)?.toInt() ?? 0,
      qtyMax: (json['qty_max'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 炼化配方（journey_evo_recipes 行）：主动法宝 + 指定被动加持达到
/// [requiredPassiveLv] 级后炼化为结果形态；判定优先级 = seq 升序。
/// weapon_id/required_passive_id 已在配置服务层映射为 code。
class JourneyEvoRecipeModel {
  final int seq;
  final String weaponCode;
  final String requiredPassiveCode;
  final int requiredPassiveLv;
  final String resultCode;
  final String resultName;

  /// 炼化伤害倍率（evo_mult 列；0=未配置走引擎内置 1.6）。
  final double evoMult;

  const JourneyEvoRecipeModel({
    required this.seq,
    required this.weaponCode,
    required this.requiredPassiveCode,
    this.requiredPassiveLv = 1,
    required this.resultCode,
    this.resultName = '',
    this.evoMult = 0,
  });

  factory JourneyEvoRecipeModel.fromJson(Map<String, dynamic> json) {
    return JourneyEvoRecipeModel(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      weaponCode: json['weapon_code'] as String? ?? '',
      requiredPassiveCode: json['required_passive_code'] as String? ?? '',
      requiredPassiveLv: (json['required_passive_lv'] as num?)?.toInt() ?? 1,
      resultCode: json['result_code'] as String? ?? '',
      resultName: json['result_name'] as String? ?? '',
      evoMult: (json['evo_mult'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 图鉴解锁（journey_relic_unlocks 行）：特效法宝解锁 = 达成成就
/// （achievement_code）+ 功德定价（merit_cost）；未解锁不进候选池。
class JourneyRelicUnlockModel {
  final int seq;
  final String weaponCode;
  final String achievementCode;
  final int meritCost;

  const JourneyRelicUnlockModel({
    required this.seq,
    required this.weaponCode,
    required this.achievementCode,
    this.meritCost = 0,
  });

  factory JourneyRelicUnlockModel.fromJson(Map<String, dynamic> json) {
    return JourneyRelicUnlockModel(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      weaponCode: json['weapon_code'] as String? ?? '',
      achievementCode: json['achievement_code'] as String? ?? '',
      meritCost: (json['merit_cost'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 拾取物配置（journey_pickups 行）：effect=效果类别
/// （exp/merit/heal/chest），value=单次拾取效果数值。
class JourneyPickupConfigModel {
  final String code;
  final String name;
  final String effect;
  final int value;
  final double radius;
  final double magnetRange;

  const JourneyPickupConfigModel({
    required this.code,
    this.name = '',
    this.effect = '',
    this.value = 0,
    this.radius = 12,
    this.magnetRange = 40,
  });

  factory JourneyPickupConfigModel.fromJson(Map<String, dynamic> json) {
    return JourneyPickupConfigModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      effect: json['effect'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
      radius: (json['radius'] as num?)?.toDouble() ?? 12,
      magnetRange: (json['magnet_range'] as num?)?.toDouble() ?? 40,
    );
  }
}
