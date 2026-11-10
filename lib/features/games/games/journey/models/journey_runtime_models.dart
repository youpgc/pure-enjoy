/// 西行·关卡运行时配置模型（进关按 level_id 拉取的从属表行：
/// 波次/密度热区/地图参照物/单关聚合）。
library;

/// 波次（journey_waves 行）：start_sec 起每 spawn_interval_ms 刷 count 只
/// monster_code，该波怪物属性乘 buff_mult——关卡刷怪全配置驱动。
/// loop=true=循环层：持续按间隔刷至怪量上限，不判完成、不消费 count。
class JourneyWaveModel {
  final int seq;
  final int startSec;
  final String monsterCode;
  final int count;
  final int spawnIntervalMs;
  final double buffMult;
  final bool loop;

  const JourneyWaveModel({
    required this.seq,
    required this.startSec,
    required this.monsterCode,
    required this.count,
    this.spawnIntervalMs = 1000,
    this.buffMult = 1.0,
    this.loop = false,
  });

  factory JourneyWaveModel.fromJson(Map<String, dynamic> json) {
    return JourneyWaveModel(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      startSec: (json['start_sec'] as num?)?.toInt() ?? 0,
      monsterCode: json['monster_code'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      spawnIntervalMs: (json['spawn_interval_ms'] as num?)?.toInt() ?? 1000,
      buffMult: (json['buff_mult'] as num?)?.toDouble() ?? 1.0,
      loop: json['loop'] == true,
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

