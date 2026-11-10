import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../../../../../services/error_reporter.dart';
import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import 'journey_config_snapshot.dart';
import 'journey_seed.dart';

// 快照类型独立定义；本文件继续导出，消费方导入路径不变。
export 'journey_config_snapshot.dart';

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
      _fetchRows('journey_talent_branches',
          order: 'character_code.asc,seq.asc'),
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
      _fetchRows('journey_drops', order: 'table_code.asc'),
      // 炼化配方/图鉴解锁：weapon_id 需经法宝表映射为 code（断裂行丢弃）
      _fetchRows('journey_evo_recipes', order: 'seq.asc'),
      _fetchRows('journey_relic_unlocks', order: 'seq.asc'),
      _fetchRows('journey_pickups', order: 'code.asc'),
      // 每日游历地图（表未部署时返回 null，消费侧回落内置种子；只取启用行）
      _fetchRows('journey_daily_maps',
          order: 'sort.asc',
          filters: <String, String>{'enabled': 'eq.true'}),
      // 无尽妖潮波次（后台可配，上限 99；表未部署返回 null 走内置公式）
      _fetchRows('journey_endless_waves', order: 'wave_no.asc'),
      // 法宝数值参数（后台可配；weapon_id 需经法宝表映射为 code，断裂行丢弃）
      _fetchRows('journey_weapon_params', order: 'weapon_id.asc'),
      // 妖王能力参数（后台可配；monster_id 需经怪物表映射为 code，断裂行丢弃）
      _fetchRows('journey_monster_params', order: 'monster_id.asc'),
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
    // 角色：客户端过滤禁用行（enabled 列后台开关；列未部署时解析缺省
    // true 不丢行，比 SQL filter 更抗表结构就绪时序）
    final characters = (results[2] ?? const <Map<String, dynamic>>[])
        .map(JourneyCharacterModel.fromJson)
        .where((c) => c.enabled)
        .toList();
    final weapons = (results[3] ?? const <Map<String, dynamic>>[])
        .map(JourneyWeaponModel.fromJson)
        .toList();
    final talentBranches = (results[4] ?? const <Map<String, dynamic>>[])
        .map(JourneyTalentBranchModel.fromJson)
        .toList();
    // 全局参数单行表：行缺失或列缺失均回落模拟值（不阻塞配置就绪判定）
    final globalsRow = (results[5] ?? const <Map<String, dynamic>>[]).isEmpty
        ? null
        : (results[5] as List<Map<String, dynamic>>).first;
    final monsterCap =
        (globalsRow?['monster_cap'] as num?)?.toInt() ?? 120;
    // 还魂复活功德基准价（journey_globals 全列拉取，直接取行键）
    final reviveMeritBase = (globalsRow?['revive_merit_base'] as num?)?.toInt() ?? 60;
    // 开局铺场只数（journey_globals.initial_pack_size，0=关闭；缺省 24）
    final initialPackSize = (globalsRow?['initial_pack_size'] as num?)?.toInt() ?? 24;
    final spawnDenRatio = (globalsRow?['spawn_den_ratio'] as num?)?.toDouble() ?? 0.70;
    // 妖王天赋点掉率（0~1；缺省回落 0.10）
    final talentDropRate = (globalsRow?['talent_drop_rate'] as num?)?.toDouble() ?? 0.10;
    // 角色等级上限（缺省回落 99）
    final charLevelCap = (globalsRow?['char_level_cap'] as num?)?.toInt() ?? 99;
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
    // 掉落表（第 11 张聚合表）
    final drops = (results[10] ?? const <Map<String, dynamic>>[])
        .map(JourneyDropModel.fromJson)
        .toList();
    // 炼化配方/图鉴解锁：weapon_id → code（经远端法宝行映射；断裂行丢弃）
    final evoRecipes = <JourneyEvoRecipeModel>[];
    for (final row in results[11] ?? const <Map<String, dynamic>>[]) {
      final code = weaponIdToCode[row['weapon_id'] as String?];
      final passive = weaponIdToCode[row['required_passive_id'] as String?];
      if (code == null || passive == null) continue;
      evoRecipes.add(JourneyEvoRecipeModel.fromJson(<String, dynamic>{
        'seq': row['seq'],
        'weapon_code': code,
        'required_passive_code': passive,
        'required_passive_lv': row['required_passive_lv'],
        'result_code': row['result_code'],
        'result_name': row['result_name'],
        'evo_mult': row['evo_mult'],
      }));
    }
    final relicUnlocks = <JourneyRelicUnlockModel>[];
    for (final row in results[12] ?? const <Map<String, dynamic>>[]) {
      final code = weaponIdToCode[row['weapon_id'] as String?];
      if (code == null) continue;
      relicUnlocks.add(JourneyRelicUnlockModel.fromJson(<String, dynamic>{
        'seq': row['seq'],
        'weapon_code': code,
        'achievement_code': row['achievement_code'],
        'merit_cost': row['merit_cost'],
      }));
    }
    // 拾取物配置（第 14 张聚合表）
    final pickupConfigs = (results[13] ?? const <Map<String, dynamic>>[])
        .map(JourneyPickupConfigModel.fromJson)
        .toList();
    // 每日游历地图（第 15 张聚合表，后台可配）
    final dailyMaps = (results[14] ?? const <Map<String, dynamic>>[])
        .map(JourneyDailyMapModel.fromJson)
        .toList();
    // 无尽妖潮波次（第 16 张聚合表，后台可配）
    final endlessWaves = (results[15] ?? const <Map<String, dynamic>>[])
        .map(JourneyEndlessWaveModel.fromJson)
        .toList();
    // 法宝数值参数（第 17 张聚合表）：weapon_id → code 聚合为
    // {weaponCode: {paramCode: value}}；映射断裂行丢弃
    final weaponParams = <String, Map<String, double>>{};
    for (final row in results[16] ?? const <Map<String, dynamic>>[]) {
      final code = weaponIdToCode[row['weapon_id'] as String?];
      final paramCode = row['code'] as String?;
      final value = (row['value_num'] as num?)?.toDouble();
      if (code == null || paramCode == null || value == null) continue;
      (weaponParams[code] ??= <String, double>{})[paramCode] = value;
    }
    // 妖王能力参数（第 18 张聚合表）：monster_id → code 聚合为
    // {monsterCode: {paramCode: value}}；映射断裂行丢弃
    final monsterIdToCode = <String, String>{
      for (final row in results[6] ?? const <Map<String, dynamic>>[])
        if (row['id'] is String && row['code'] is String)
          row['id'] as String: row['code'] as String,
    };
    final monsterParams = <String, Map<String, double>>{};
    for (final row in results[17] ?? const <Map<String, dynamic>>[]) {
      final code = monsterIdToCode[row['monster_id'] as String?];
      final paramCode = row['code'] as String?;
      final value = (row['value_num'] as num?)?.toDouble();
      if (code == null || paramCode == null || value == null) continue;
      (monsterParams[code] ??= <String, double>{})[paramCode] = value;
    }

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
        // 天赋分支表缺失时不产生「无枝可点」死局：回落内置分支
        talentBranches: talentBranches.isEmpty
            ? buildJourneyTalentBranchSeed().map(JourneyTalentBranchModel.fromJson).toList()
            : talentBranches,
        monsters: monsters,
        slotDefs: slotDefs,
        weaponLevels: weaponLevels,
        drops: drops,
        evoRecipes: evoRecipes,
        relicUnlocks: relicUnlocks,
        pickupConfigs: pickupConfigs,
        dailyMaps: dailyMaps,
        endlessWaves: endlessWaves,
        weaponParams: weaponParams,
        monsterParams: monsterParams,
        globalsRaw: globalsRow,
        reviveMeritBase: reviveMeritBase,
        gameId: journeyGameId ?? '',
        scoreDimIds: scoreDimIds,
        monsterCap: monsterCap,
        initialPackSize: initialPackSize,
        spawnDenRatio: spawnDenRatio,
        talentDropRate: talentDropRate,
        charLevelCap: charLevelCap,
        fromSeed: false,
      );
      return _memory!;
    }

    // 远端未就绪：内置兜底（SQL 种子的镜像），低噪音上报一次
    if (!_seedReported) {
      _seedReported = true;
      ErrorReporter.reportMessage('西行配置表未就绪，使用内置兜底配置',
          module: 'games.journey', level: 'info');
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
      talentBranches: buildJourneyTalentBranchSeed()
          .map(JourneyTalentBranchModel.fromJson).toList(),
      drops: kJourneyDropSeed.map(JourneyDropModel.fromJson).toList(),
      evoRecipes:
          kJourneyEvoRecipeSeed.map(JourneyEvoRecipeModel.fromJson).toList(),
      relicUnlocks:
          kJourneyRelicUnlockSeed.map(JourneyRelicUnlockModel.fromJson).toList(),
      pickupConfigs: kJourneyPickupConfigSeed
          .map(JourneyPickupConfigModel.fromJson)
          .toList(),
      reviveMeritBase: kJourneyReviveMeritBase,
      initialPackSize: kJourneyInitialPackSize,
      spawnDenRatio: kJourneySpawnDenRatio,
      talentDropRate: kJourneyTalentDropRate,
      charLevelCap: kJourneyCharLevelCap,
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
