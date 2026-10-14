import 'package:flutter/foundation.dart';

import '../../../services/backend_api.dart';
import '../../../services/error_reporter.dart';
import '../../../utils/cache_helper.dart';
import '../models/game_score_model.dart';
import '../services/game_service.dart';

import '../models/game_score_models.dart';
export '../models/game_score_models.dart';

// 【文件拆分 2026-09-22】单文件超 500 行红线，域模型拆至 models/game_score_models.dart
// （逻辑零变更）；上述 export 保持调用方原有 import 路径不变。

/// 游戏成绩服务（change-server：数据面走自建后端 /games/**）
///
/// 职责：单次结算上报（成绩+发放明细同请求）、查询成绩记录、最佳成绩、已通关集合。
/// 状态值映射：App 语义 'cleared' → 后端 'completed'（failed/aborted 同名）。
/// 结算幂等：客户端 settleToken 作为 scoreId 主键，重试同键服务端只回详情不重复发放。
class GameScoreService {
  GameScoreService._();

  /// 单例
  static final GameScoreService instance = GameScoreService._();

  /// 内存缓存：最佳成绩（避免看板重复请求）
  List<GameBestScore>? _memoryBest;

  /// 账号切换时清空最佳成绩内存缓存（2026-09-14 审查修复）：
  /// 缓存按用户统计，切号不清会导致新账号看到旧账号的最佳成绩。
  void resetForAccountSwitch() {
    _memoryBest = null;
  }

  /// 单次结算：落成绩（含无尽轮次）+ 服务端权威发放（方案 B 编排在后端）。
  ///
  /// [valuesByCode] 为「维度编码 → 取值」；[cumulativeTotals] 为累计指标总值
  /// （cumulative 成就判定数据源，方案 A 口径）；[endlessRounds] 仅无尽会话传入。
  /// [scoreId] 传结算唯一标识（settleToken），重试同键幂等。
  /// 返回结算明细；失败返回 null（调用方进错误态重试）。
  Future<GameSettleOutcome?> settle({
    required String gameCode,
    required String settleToken,
    String? levelId,
    required String modeId,
    required bool cleared,
    String? statusOverride,
    required int durationMs,
    required bool rewardsAllowed,
    Map<String, num> valuesByCode = const <String, num>{},
    Map<String, int> cumulativeTotals = const <String, int>{},
    List<GameEndlessRound> endlessRounds = const <GameEndlessRound>[],
  }) async {
    final status = statusOverride ?? (cleared ? 'cleared' : 'failed');
    final body = <String, dynamic>{
      'score_id': settleToken,
      'mode_id': modeId,
      'level_id': levelId,
      'status': status == 'cleared' ? 'completed' : status,
      'duration_ms': durationMs,
      'rewards_allowed': rewardsAllowed,
      'values': <Map<String, dynamic>>[
        for (final e in valuesByCode.entries)
          {'dimension_code': e.key, 'value': e.value},
      ],
      if (cumulativeTotals.isNotEmpty)
        'cumulative': <String, num>{for (final e in cumulativeTotals.entries) e.key: e.value},
      if (endlessRounds.isNotEmpty)
        'rounds': <Map<String, dynamic>>[
          for (final r in endlessRounds)
            {
              'round_no': r.roundNo,
              'score': r.score,
              'moves': r.moves,
              'duration_ms': r.durationMs,
            },
        ],
    };
    final result = await BackendApi.post('/games/$gameCode/settle', body: body);
    if (!result.success) {
      debugPrint('[GameScoreService] 结算上报失败：${result.error}');
      ErrorReporter.reportMessage(
        '游戏结算上报失败：${result.error}（game=$gameCode, status=$status）',
        module: 'games',
      );
      return null;
    }
    final data = result.data;
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final score = map['score'];
    return GameSettleOutcome(
      scoreId: score is Map<String, dynamic> ? score['id']?.toString() : null,
      rewards: _mapList(map['rewards']),
      achievements: _mapList(map['achievements']),
    );
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) => [
        for (final row in (raw as List<dynamic>?) ?? <dynamic>[])
          if (row is Map<String, dynamic>) row,
      ];

  /// 查询当前用户在某游戏下已通关的关卡 id 集合（后端 completed 去重集合）。
  Future<Set<String>> fetchClearedLevelIds(String gameId) async {
    final gameCode = _codeOf(gameId);
    if (gameCode == null) return <String>{};
    final result =
        await BackendApi.get('/games/$gameCode/cleared-level-ids');
    if (!result.success) {
      debugPrint('[GameScoreService] 已通关关卡查询失败：${result.error}');
      return <String>{};
    }
    return <String>{
      for (final v in (result.data as List<dynamic>?) ?? <dynamic>[])
        if (v != null) v.toString(),
    };
  }

  /// 查询最佳成绩（后端按维度 aggregate 聚合，行结构与原 RPC 一致）。
  ///
  /// SWR 语义（2026-09-07）：非 force 时先返回持久缓存（调用方秒渲染），
  /// 但本方法**始终发起网络请求**更新缓存。失败时返回持久缓存兜底。
  Future<List<GameBestScore>> fetchBestScores({
    String? gameId,
    bool force = false,
  }) async {
    final gameCode = gameId == null ? null : _codeOf(gameId);
    final result = await BackendApi.get(
      '/games/best-scores',
      query: gameCode == null ? null : {'gameCode': gameCode},
    );
    if (!result.success) {
      debugPrint('[GameScoreService] 最佳成绩查询失败：${result.error}');
      ErrorReporter.reportMessage(
        '最佳成绩查询失败：${result.error}（game=$gameId）',
        module: 'games',
        level: 'warning',
      );
      return loadCachedBestScores();
    }
    final list = [
      for (final row in (result.data as List<dynamic>?) ?? <dynamic>[])
        if (row is Map<String, dynamic>) GameBestScore.fromJson(row),
    ];
    if (gameId == null) {
      _memoryBest = list;
      await CacheHelper.instance
          .saveList(CacheHelper.keyGameScores, list.map((e) => e.toJson()).toList());
    }
    return list;
  }

  /// 读取本地缓存的最佳成绩（开屏秒渲染，避免闪空）。
  Future<List<GameBestScore>> loadCachedBestScores() async {
    if (_memoryBest != null) return _memoryBest!;
    final rows = await CacheHelper.instance.loadList(CacheHelper.keyGameScores);
    final list = rows
        .whereType<Map<String, dynamic>>()
        .map(GameBestScore.fromJson)
        .toList();
    _memoryBest = list;
    return list;
  }

  /// 查询某游戏的成绩记录（按游玩时间倒序，含维度值）。
  ///
  /// [limit] 为 null 时取全量；[offset] 用于分页滚动加载。后端分页按
  /// page/pageSize 语义，此处把 offset 折算为页号（pageSize 与请求页大小一致）。
  Future<List<GameScoreModel>> fetchScoreHistory(
    String gameId, {
    int? limit = 50,
    int offset = 0,
  }) async {
    final rows = await _fetchScoreRows(gameId, limit: limit, offset: offset);
    String? scoreDimId;
    for (final d in GameService.instance.cachedConfig.dimensionsOf(gameId)) {
      if (d.code == 'score') {
        scoreDimId = d.id;
        break;
      }
    }
    return rows
        .map((r) => GameScoreModel.fromJson(r, scoreDimId: scoreDimId))
        .toList();
  }

  /// 查询某游戏全部成绩记录（含各维度取值），供「各模式最佳成绩」等本地聚合。
  Future<List<GameScoreEntry>> fetchScoresWithValues(String gameId) async {
    final dims = GameService.instance.cachedConfig.dimensionsOf(gameId);
    final rows = await _fetchScoreRows(gameId, limit: null, offset: 0);
    final list = <GameScoreEntry>[];
    for (final raw in rows) {
      final score = GameScoreModel.fromJson(raw);
      final values = <String, num>{};
      final vals = (raw['game_score_values'] as List<dynamic>?) ?? <dynamic>[];
      for (final v in vals) {
        if (v is! Map<String, dynamic>) continue;
        final dimId = v['dimension_id']?.toString();
        final dim = dims.where((d) => d.id == dimId).firstOrNull;
        final numVal = (v['value'] as num?) ?? 0;
        if (dim != null) {
          values[dim.code] = numVal;
        } else if (dimId != null) {
          values[dimId] = numVal;
        }
      }
      list.add(GameScoreEntry(score: score, values: values, dimensions: dims));
    }
    return list;
  }

  /// 成绩行拉取（后端 /games/scores 多状态过滤 + 嵌入维度值）。
  ///
  /// 行结构转换为模型消费的 PostgREST 嵌入形状（values → game_score_values）。
  /// [limit] 为 null 时按 500/页循环拉全量（后端分页有界）。
  Future<List<Map<String, dynamic>>> _fetchScoreRows(
    String gameId, {
    int? limit,
    required int offset,
  }) async {
    final gameCode = _codeOf(gameId);
    if (gameCode == null) return <Map<String, dynamic>>[];
    const statuses = 'completed,failed'; // 看板不展示「放弃」记录（aborted 仅后台可见）
    final pageSize = limit ?? 500;
    final page = offset ~/ pageSize + 1;
    final result = await BackendApi.get('/games/scores', query: <String, String>{
      'gameCode': gameCode,
      'statuses': statuses,
      'page': '$page',
      'pageSize': '$pageSize',
    });
    if (!result.success) {
      debugPrint('[GameScoreService] 成绩记录查询失败：${result.error}');
      ErrorReporter.reportMessage(
        '成绩记录查询失败：${result.error}（game=$gameId, page=$page）',
        module: 'games',
        level: 'warning',
      );
      return <Map<String, dynamic>>[];
    }
    final rows = <Map<String, dynamic>>[
      for (final row in result.list)
        if (row is Map<String, dynamic>)
          <String, dynamic>{...row, 'game_score_values': row['values']},
    ];
    // 全量模式：不足一页即到尾；否则继续补拉（罕见路径，串行）
    if (limit != null || rows.length < pageSize) return rows;
    var all = rows;
    var nextPage = page + 1;
    while (true) {
      final more = await BackendApi.get('/games/scores',
          query: <String, String>{
            'gameCode': gameCode,
            'statuses': statuses,
            'page': '$nextPage',
            'pageSize': '$pageSize',
          });
      final moreRows = <Map<String, dynamic>>[
        for (final row in more.list)
          if (row is Map<String, dynamic>)
            <String, dynamic>{...row, 'game_score_values': row['values']},
      ];
      if (moreRows.isEmpty) break;
      all = [...all, ...moreRows];
      if (moreRows.length < pageSize) break;
      nextPage += 1;
    }
    return all;
  }

  /// 由快照反查游戏编码（后端端点按 gameCode 寻址）。
  String? _codeOf(String gameId) {
    for (final g in GameService.instance.cachedConfig.games) {
      if (g.id == gameId) return g.code;
    }
    return null;
  }

  /// 清空成绩缓存（切换账号或下拉刷新用）。
  Future<void> clearCache() async {
    _memoryBest = null;
    await CacheHelper.instance.clear(CacheHelper.keyGameScores);
  }
}

/// 单次结算结果（成绩 id + 服务端发放明细原行）。
class GameSettleOutcome {
  final String? scoreId;
  final List<Map<String, dynamic>> rewards;
  final List<Map<String, dynamic>> achievements;

  const GameSettleOutcome({
    this.scoreId,
    this.rewards = const <Map<String, dynamic>>[],
    this.achievements = const <Map<String, dynamic>>[],
  });
}
