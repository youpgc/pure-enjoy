import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../../../../../services/error_reporter.dart';
import '../models/journey_models.dart';
import 'journey_config_builder.dart';
import 'journey_config_scope.dart';
import 'journey_config_snapshot.dart';

// 快照类型与页面分组独立定义；本文件继续导出，消费方导入路径不变。
export 'journey_config_scope.dart';
export 'journey_config_snapshot.dart';

/// 西行·配置服务：按页面分组按需拉取，远端配置优先，失败回落内置兜底。
///
/// 每个页面只声明自己渲染/交互需要的表（[JourneyConfigScope]），服务按表
/// 缓存远端行，重复进入不重复请求，跨页面累积成同一份配置快照。基础组
/// （games + regions）为局外页面共用，战斗页在进入时补齐剩余全部表。
/// 关卡走既有 game_levels 链（games.code='journey' → game_levels，西行
/// 属性在 config jsonb）；其余为 journey_* 只读配置表。
class JourneyConfigService {
  JourneyConfigService._();

  static final JourneyConfigService instance = JourneyConfigService._();

  /// 表名 → 已成功加载的远端行；未加载或拉取失败的表不写入缓存，
  /// 由组装侧按域回落内置种子，下一次进入页面时重新尝试。
  final JourneyConfigRows _rows = <String, List<Map<String, dynamic>>>{};

  String _gameId = '';
  JourneyConfigSnapshot? _memory;

  /// 在途拉取：并发进入不同页面时共享同一轮补表，避免请求风暴。
  Future<void>? _inFlight;
  bool _seedReported = false;

  JourneyConfigSnapshot? get cached => _memory;

  /// 全量配置（战斗页进关前调用；其余页面请用 [ensure] 按范围加载）。
  Future<JourneyConfigSnapshot> fetch({bool force = false}) =>
      ensure(JourneyConfigScope.battle, force: force);

  /// 确保 [scope] 所需的表都已加载，返回累积后的配置快照。
  /// 同表只拉一次；在途请求由所有调用方共享，force 时清空重拉。
  Future<JourneyConfigSnapshot> ensure(
    JourneyConfigScope scope, {
    bool force = false,
  }) async {
    if (force) {
      final running = _inFlight;
      if (running != null) await running;
      _rows.clear();
      _memory = null;
      _gameId = '';
    }
    final wanted = expandConfigDependencies(scope.tables);
    // 单次 ensure 内每张表最多尝试一次：失败表留给下一次进入页面重拉，
    // 既不会自锁死循环，也不在一次加载里反复发请求。
    final attempted = <JourneyConfigTable>{};
    while (true) {
      final running = _inFlight;
      if (running != null) await running;
      final missing = wanted
          .where(
              (t) => !_rows.containsKey(t.tableName) && !attempted.contains(t))
          .toSet();
      if (missing.isEmpty) break;
      attempted.addAll(missing);
      final future = _fetchMissing(missing);
      _inFlight = future;
      try {
        await future;
      } finally {
        if (identical(_inFlight, future)) _inFlight = null;
      }
    }
    final memory = _memory;
    if (memory != null) return memory;
    _rebuild();
    return _memory!;
  }

  /// 拉取一组缺失表：games 是依赖 gameId 的表的前置，单独先取；
  /// 其余并行。写入行缓存后由累积数据重建快照。
  Future<void> _fetchMissing(Set<JourneyConfigTable> missing) async {
    const games = JourneyConfigTable.games;
    if (missing.contains(games) && !_rows.containsKey(games.tableName)) {
      final gameRows = await _fetchRows(games);
      if (gameRows != null) {
        _rows[games.tableName] = gameRows;
        final id = gameRows.isEmpty ? null : gameRows.first['id'] as String?;
        if (id != null && id.isNotEmpty) _gameId = id;
      }
    }

    final rest = missing
        .where((t) => t != games && !_rows.containsKey(t.tableName))
        .toList(growable: false);
    await Future.wait<void>(rest.map((table) async {
      // games 行缺失时不拉全表关卡/维度（会混入其他游戏数据），也不写
      // 缓存，等 games 就绪后随下一次加载补齐。
      if (table.needsGameId && _gameId.isEmpty) return;
      final rows = await _fetchRows(table);
      if (rows != null) _rows[table.tableName] = rows;
    }));
    _rebuild();
  }

  void _rebuild() {
    try {
      final built = buildJourneyConfigSnapshot(_rows, _gameId);
      _memory = built.snapshot;
      if (built.fromSeed && !_seedReported) {
        _seedReported = true;
        ErrorReporter.reportMessage('西行配置表未就绪，使用内置兜底配置',
            module: 'games.journey', level: 'info');
      }
    } catch (e, st) {
      _memory = buildJourneySeedSnapshot();
      ErrorReporter.report(e, st, module: 'games.journey');
    }
  }

  Future<List<Map<String, dynamic>>?> _fetchRows(
      JourneyConfigTable table) async {
    return _fetchRowsByName(
      table.tableName,
      order: table.order,
      filters: table.filters(_gameId),
      select: table.select,
    );
  }

  /// 单页拉取（各表行数远小于 1000，无需分页）；失败返回 null 走兜底。
  Future<List<Map<String, dynamic>>?> _fetchRowsByName(
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

    final results = await Future.wait<
        List<Map<String, dynamic>>?>(<Future<List<Map<String, dynamic>>?>>[
      _fetchRowsByName('journey_waves',
          order: 'seq.asc',
          filters: <String, String>{'level_id': 'eq.$levelId'}),
      _fetchRowsByName('journey_heat_zones',
          filters: <String, String>{'level_id': 'eq.$levelId'}),
      _fetchRowsByName('journey_map_objects',
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
