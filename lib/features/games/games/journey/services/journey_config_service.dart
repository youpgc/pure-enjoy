import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../../../../../services/error_reporter.dart';
import '../models/journey_models.dart';
import 'journey_seed.dart';

/// 西行·配置快照（一次聚合全部 journey_* 静态配置）。
class JourneyConfigSnapshot {
  final List<JourneyRegionModel> regions;
  final List<JourneyLevelModel> levels;
  final List<JourneyCharacterModel> characters;
  final List<JourneyWeaponModel> weapons;
  final List<JourneyTalentModel> talents;

  /// 怪物池（journey_monsters 远端配置；空=引擎回落内置种子池）。
  final List<JourneyMonsterModel> monsters;

  /// 武器维度槽定义（journey_weapon_slots；空=引擎回落内置兜底）。
  final List<JourneySlotDefModel> slotDefs;

  /// 法宝分级（journey_weapon_levels，按法宝 code 分组，lv 升序）；
  /// 空=引擎回落内置基准数值。
  final Map<String, List<JourneyWeaponLevelModel>> weaponLevels;

  /// 西行游戏 id（games.code='journey'；成绩上报用，空=未就绪不上报）。
  final String gameId;

  /// 成绩维度 id（game_dimensions，code→id：farthest_level/run_kills/
  /// run_merit）；成绩上报 values 键，空=未配置不上报。
  final Map<String, String> scoreDimIds;

  /// 同屏怪物实体上限（journey_globals.monster_cap，运营可在后台调整）。
  final int monsterCap;

  /// true = 全部来自内置兜底（journey_* 表未部署或拉取失败）。
  final bool fromSeed;

  const JourneyConfigSnapshot({
    required this.regions,
    required this.levels,
    required this.characters,
    required this.weapons,
    required this.talents,
    this.monsters = const <JourneyMonsterModel>[],
    this.slotDefs = const <JourneySlotDefModel>[],
    this.weaponLevels = const <String, List<JourneyWeaponLevelModel>>{},
    this.gameId = '',
    this.scoreDimIds = const <String, String>{},
    this.monsterCap = 120,
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

  List<JourneyLevelModel> levelsOfRegion(String regionCode) =>
      levels.where((l) => l.regionCode == regionCode).toList()
        ..sort((a, b) => a.levelNo.compareTo(b.levelNo));
}

/// 西行·配置服务：远端配置优先，失败回落内置兜底。
///
/// 关卡走既有 game_levels 链（games.code='journey' → game_levels，西行
/// 属性在 config jsonb）；其余走 journey_* 扩展配置表（区域/角色/法宝/
/// 天赋/全局参数）。均为全局只读表（App 不写），失败静默兜底并上报，
/// 与 GameService 的失败兜底口径一致。
class JourneyConfigService {
  JourneyConfigService._();

  static final JourneyConfigService instance = JourneyConfigService._();

  JourneyConfigSnapshot? _memory;
  bool _seedReported = false;

  JourneyConfigSnapshot? get cached => _memory;

  Future<JourneyConfigSnapshot> fetch({bool force = false}) async {
    final memory = _memory;
    if (!force && memory != null) return memory;

    // 关卡统一走既有 game_levels 链（按西行 game_id 过滤）；西行专属属性
    // 在 game_levels.config jsonb。先取西行 game id，再并行拉其余配置表。
    final gameRows = await _fetchRows(
      'games',
      order: 'code.asc',
      filters: <String, String>{'code': 'eq.journey'},
      select: 'id,code',
    );
    final journeyGameId =
        (gameRows != null && gameRows.isNotEmpty) ? gameRows.first['id'] as String? : null;

    final results = await Future.wait<List<Map<String, dynamic>>?>(
        <Future<List<Map<String, dynamic>>?>>[
      _fetchRows('journey_regions', order: 'seq.asc'),
      // games 行缺失（整合 SQL 未执行）时不拉 game_levels——全表是其他
      // 游戏的关卡，混入会造成错误快照；返回 null 走内置兜底。
      journeyGameId == null
          ? Future<List<Map<String, dynamic>>?>.value(null)
          : _fetchRows(
              'game_levels',
              order: 'level_no.asc',
              filters: <String, String>{'game_id': 'eq.$journeyGameId'},
              select:
                  'id,level_no,name,config,enabled,difficulty',
            ),
      _fetchRows('journey_characters', order: 'unlock_level_no.asc'),
      _fetchRows('journey_weapons', order: 'code.asc'),
      _fetchRows('journey_talents', order: 'seq.asc'),
      _fetchRows('journey_globals', order: 'code.asc'),
      _fetchRows('journey_monsters', order: 'code.asc'),
      _fetchRows('journey_weapon_slots', order: 'sort_order.asc'),
      // 法宝分级：weapon_id 需经法宝表映射为 code（消费侧按 code 取级）
      journeyGameId == null
          ? Future<List<Map<String, dynamic>>?>.value(null)
          : _fetchRows('journey_weapon_levels', order: 'lv.asc'),
      // 成绩维度（结算上报 game_scores 的 values 键）
      journeyGameId == null
          ? Future<List<Map<String, dynamic>>?>.value(null)
          : _fetchRows('game_dimensions',
              order: 'sort_order.asc',
              filters: <String, String>{'game_id': 'eq.$journeyGameId'},
              select: 'id,code'),
    ]);

    final regionRows = results[0] ?? const <Map<String, dynamic>>[];
    final regions =
        regionRows.map(JourneyRegionModel.fromJson).toList();
    // 关卡行（game_levels）：name=难名；西行专属属性在 config jsonb
    // （region_code/level_kind/boss_fights/first_clear_merit/
    // duration_target_sec=无妖难坚持时长）；未开放难不进列表。
    final levels = (results[1] ?? const <Map<String, dynamic>>[])
        .where((row) => row['enabled'] != false)
        .map((row) {
      final config = (row['config'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      return JourneyLevelModel.fromJson(<String, dynamic>{
        'id': row['id'],
        'level_no': row['level_no'],
        'title': row['name'],
        'region_code': config['region_code'],
        'level_kind': config['level_kind'],
        'boss_fights': config['boss_fights'],
        'first_clear_merit': config['first_clear_merit'],
        'duration_target_sec': config['duration_target_sec'],
        'difficulty': row['difficulty'],
      });
    }).toList();
    final characters = (results[2] ?? const <Map<String, dynamic>>[])
        .map(JourneyCharacterModel.fromJson)
        .toList();
    final weapons = (results[3] ?? const <Map<String, dynamic>>[])
        .map(JourneyWeaponModel.fromJson)
        .toList();
    final talents = (results[4] ?? const <Map<String, dynamic>>[])
        .map(JourneyTalentModel.fromJson)
        .toList();
    // 全局参数单行表：行缺失或列缺失均回落模拟值（不阻塞配置就绪判定）
    final globalsRow = (results[5] ?? const <Map<String, dynamic>>[]).isEmpty
        ? null
        : (results[5] as List<Map<String, dynamic>>).first;
    final monsterCap =
        (globalsRow?['monster_cap'] as num?)?.toInt() ?? 120;
    // 怪物池远端配置（关卡刷怪/妖王归属的数据源）；空→引擎回落内置种子池
    final monsters = (results[6] ?? const <Map<String, dynamic>>[])
        .map(JourneyMonsterModel.fromJson)
        .toList();
    // 武器维度槽定义（第 8 张聚合表）
    final slotDefs = (results[7] ?? const <Map<String, dynamic>>[])
        .map(JourneySlotDefModel.fromJson)
        .toList();
    // 法宝分级：weapon_id → code（经远端法宝行映射；映射断裂行丢弃）
    final weaponIdToCode = <String, String>{
      for (final row in results[3] ?? const <Map<String, dynamic>>[])
        if (row['id'] is String && row['code'] is String)
          row['id'] as String: row['code'] as String,
    };
    final weaponLevels = <String, List<JourneyWeaponLevelModel>>{};
    for (final row in results[8] ?? const <Map<String, dynamic>>[]) {
      final code = weaponIdToCode[row['weapon_id'] as String?];
      if (code == null) continue;
      (weaponLevels[code] ??= <JourneyWeaponLevelModel>[])
          .add(JourneyWeaponLevelModel.fromJson(row));
    }
    // 成绩维度 id（code → id）
    final scoreDimIds = <String, String>{
      for (final row in results[9] ?? const <Map<String, dynamic>>[])
        if (row['id'] is String && row['code'] is String)
          row['code'] as String: row['id'] as String,
    };

    final remoteReady = regions.isNotEmpty && levels.isNotEmpty;
    if (remoteReady) {
      _memory = JourneyConfigSnapshot(
        regions: regions,
        levels: levels,
        // 角色表缺失时不产生「无可用角色」死局：回落内置角色
        characters: characters.isEmpty
            ? kJourneyCharacterSeed.map(JourneyCharacterModel.fromJson).toList()
            : characters,
        weapons: weapons,
        talents: talents,
        monsters: monsters,
        slotDefs: slotDefs,
        weaponLevels: weaponLevels,
        gameId: journeyGameId ?? '',
        scoreDimIds: scoreDimIds,
        monsterCap: monsterCap,
        fromSeed: false,
      );
      return _memory!;
    }

    // 远端未就绪：内置兜底（SQL 种子的镜像），低噪音上报一次
    if (!_seedReported) {
      _seedReported = true;
      ErrorReporter.reportMessage(
        '西行配置表未就绪，使用内置兜底配置',
        module: 'games.journey',
        level: 'info',
      );
    }
    _memory = _buildSeedSnapshot();
    return _memory!;
  }

  JourneyConfigSnapshot _buildSeedSnapshot() {
    return JourneyConfigSnapshot(
      regions: kJourneyRegionSeed.map(JourneyRegionModel.fromJson).toList(),
      levels: kJourneyLevelSeed.map(JourneyLevelModel.fromJson).toList(),
      characters:
          kJourneyCharacterSeed.map(JourneyCharacterModel.fromJson).toList(),
      weapons: kJourneyWeaponSeed.map(JourneyWeaponModel.fromJson).toList(),
      talents: buildJourneyTalentSeed().map(JourneyTalentModel.fromJson).toList(),
      fromSeed: true,
    );
  }

  /// 单页拉取（各表行数远小于 1000，无需分页）；失败返回 null 走兜底。
  Future<List<Map<String, dynamic>>?> _fetchRows(
    String table, {
    String? order,
    Map<String, String>? filters,
    String? select,
  }) async {
    try {
      final result = await ApiClient.get(
        table,
        filters: filters,
        select: select,
        order: order ?? 'id.asc',
        limit: 1000,
      );
      if (result.isSuccess) return result.data;
      return null;
    } catch (e, st) {
      if (kDebugMode) debugPrint('journey config $table 拉取失败: $e');
      ErrorReporter.report(e, st, module: 'games.journey');
      return null;
    }
  }

  // ---- 单关运行时配置（波次/热区/参照物；按 level_id 按需拉取）----

  final Map<String, JourneyLevelRuntime> _runtimeCache =
      <String, JourneyLevelRuntime>{};

  /// 进关时拉取该关运行时配置（关卡从属表 FK 挂 game_levels.id）。
  /// 拉取失败/无配置返回空 runtime → 引擎走内置兜底刷怪，不阻塞进关。
  Future<JourneyLevelRuntime> fetchLevelRuntime(String levelId) async {
    if (levelId.isEmpty) return const JourneyLevelRuntime();
    final cached = _runtimeCache[levelId];
    if (cached != null) return cached;

    final results = await Future.wait<List<Map<String, dynamic>>?>(
        <Future<List<Map<String, dynamic>>?>>[
      _fetchRows('journey_waves',
          order: 'seq.asc',
          filters: <String, String>{'level_id': 'eq.$levelId'}),
      _fetchRows('journey_heat_zones',
          filters: <String, String>{'level_id': 'eq.$levelId'}),
      _fetchRows('journey_map_objects',
          filters: <String, String>{'level_id': 'eq.$levelId'}),
    ]);

    // 波次里引用的怪种必须在怪物池中存在（映射断裂行丢弃，不进引擎）
    final monsters = _memory?.monsters ?? const <JourneyMonsterModel>[];
    final knownCodes = <String>{for (final m in monsters) m.code};
    final waves = (results[0] ?? const <Map<String, dynamic>>[])
        .map(JourneyWaveModel.fromJson)
        .where((w) {
      final ok = w.monsterCode.isNotEmpty &&
          (knownCodes.isEmpty || knownCodes.contains(w.monsterCode));
      if (!ok && kDebugMode) {
        debugPrint('journey wave 怪种映射缺失: ${w.monsterCode}');
      }
      return ok;
    }).toList();

    final runtime = JourneyLevelRuntime(
      waves: waves,
      heatZones: (results[1] ?? const <Map<String, dynamic>>[])
          .map(JourneyHeatZoneModel.fromJson)
          .toList(),
      mapObjects: (results[2] ?? const <Map<String, dynamic>>[])
          .map(JourneyMapObjectModel.fromJson)
          .toList(),
    );
    _runtimeCache[levelId] = runtime;
    return runtime;
  }
}
