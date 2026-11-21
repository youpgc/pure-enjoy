/// 法宝分级（journey_weapon_levels 行）：法宝 1~8 级数值，各形态按列消费——
/// orbit/各形态伤害取 damage，projectile/boomerang/beam 取 interval_ms，
/// projectile 取 proj_count，magnet 命中固定回血取 heal_amount，
/// aura/magnet 取 value_num。列缺失时引擎回落 journey_weapons 的 base 列。
class JourneyWeaponLevelModel {
  final int lv;
  final int damage;
  final int intervalMs;
  final int projCount;
  final int healAmount;
  final double valueNum;

  const JourneyWeaponLevelModel({
    required this.lv,
    this.damage = 0,
    this.intervalMs = 0,
    this.projCount = 0,
    this.healAmount = 0,
    this.valueNum = 0,
  });

  factory JourneyWeaponLevelModel.fromJson(Map<String, dynamic> json) {
    return JourneyWeaponLevelModel(
      lv: (json['lv'] as num?)?.toInt() ?? 0,
      damage: (json['damage'] as num?)?.toInt() ?? 0,
      intervalMs: (json['interval_ms'] as num?)?.toInt() ?? 0,
      projCount: (json['proj_count'] as num?)?.toInt() ?? 0,
      healAmount: (json['heal_amount'] as num?)?.toInt() ?? 0,
      valueNum: (json['value_num'] as num?)?.toDouble() ?? 0,
    );
  }
}
