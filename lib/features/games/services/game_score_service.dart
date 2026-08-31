import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/cache_helper.dart';
import '../models/game_score_model.dart';

/// 最佳成绩项
///
/// 对应 RPC `get_game_best_scores` 的一行：某游戏某维度的最佳取值与达成时间。
class GameBestScore {
  /// 游戏 id
  final String gameId;

  /// 游戏编码
  final String gameCode;

  /// 游戏名称
  final String gameName;

  /// 维度 id
  final String dimensionId;

  /// 维度编码
  final String dimensionCode;

  /// 维度名称
  final String dimensionName;

  /// 单位
  final String? unit;

  /// 聚合方式：'max' | 'min' | 'sum' | 'latest'
  final String aggregate;

  /// 是否主维度
  final bool isPrimary;

  /// 排序号
  final int sortOrder;

  /// 最佳取值
  final num bestValue;

  /// 达成时间（UTC）
  final DateTime? achievedAt;

  const GameBestScore({
    required this.gameId,
    required this.gameCode,
    required this.gameName,
    required this.dimensionId,
    required this.dimensionCode,
    required this.dimensionName,
    this.unit,
    this.aggregate = 'max',
    this.isPrimary = false,
    this.sortOrder = 0,
    this.bestValue = 0,
    this.achievedAt,
  });

  /// 是否「越小越好」（用时类）。
  bool get isLowerBetter => aggregate == 'min';

  /// 是否时间类（展示需格式化 mm:ss）。
  bool get isDuration => dimensionCode == 'duration_ms';

  /// 从 RPC 返回行解析。
  factory GameBestScore.fromJson(Map<String, dynamic> json) {
    return GameBestScore(
      gameId: json['game_id'] as String? ?? '',
      gameCode: json['game_code'] as String? ?? '',
      gameName: json['game_name'] as String? ?? '',
      dimensionId: json['dimension_id'] as String? ?? '',
      dimensionCode: json['dimension_code'] as String? ?? '',
      dimensionName: json['dimension_name'] as String? ?? '',
      unit: json['unit'] as String?,
      aggregate: json['aggregate'] as String? ?? 'max',
      isPrimary: json['is_primary'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      bestValue: (json['best_value'] as num?) ?? 0,
      achievedAt: json['achieved_at'] != null
          ? DateTime.tryParse(json['achieved_at'].toString())
          : null,
    );
  }

  /// 序列化（本地缓存用）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'game_id': gameId,
        'game_code': gameCode,
        'game_name': gameName,
        'dimension_id': dimensionId,
        'dimension_code': dimensionCode,
        'dimension_name': dimensionName,
        'unit': unit,
        'aggregate': aggregate,
        'is_primary': isPrimary,
        'sort_order': sortOrder,
        'best_value': bestValue,
        'achieved_at': achievedAt?.toUtc().toIso8601String(),
      };
}

/// 游戏成绩服务
///
/// 职责：上报游玩成绩、查询成绩记录、查询最佳成绩（经 RPC 服务端聚合）。
/// 所有读写走 [ApiClient]；用户过滤一律用 [AuthService.instance.currentUserId]
/// 直接匹配业务 ID 列（game_scores.user_id 存业务 ID，非 UUID）。
class GameScoreService {
  GameScoreService._();

  /// 单例
  static final GameScoreService instance = GameScoreService._();

  /// 内存缓存：最佳成绩（避免看板重复请求）
  List<GameBestScore>? _memoryBest;

  /// 上报一次游玩成绩。
  ///
  /// [values] 为「维度 id → 取值」，按配置维度传入（如分数、用时）。
  /// [statusOverride] 可显式指定状态（'cleared' / 'failed' / 'aborted'）；
  /// 缺省按 [cleared] 派生（true→cleared，false→failed）。
  /// 先插主记录再插各维度取值；维度取值并行写入，任一失败仅记日志不阻断主流程。
  ///
  /// 返回成绩 id；未登录或主记录插入失败返回 null。
  Future<String?> submitScore({
    required String gameId,
    String? levelId,
    required bool cleared,
    String? statusOverride,
    required int durationMs,
    Map<String, num> values = const <String, num>{},
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;

    final scoreId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final result = await ApiClient.post(
      'game_scores',
      <String, dynamic>{
        'id': scoreId,
        'user_id': userId,
        'game_id': gameId,
        'level_id': levelId,
        'status': statusOverride ?? (cleared ? 'cleared' : 'failed'),
        'duration_ms': durationMs,
        'played_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      },
      returnRepresentation: false,
      note: 'games:submit_score',
    );

    if (!result.isSuccess) {
      debugPrint('[GameScoreService] 成绩上报失败：${result.errorMessage}');
      return null;
    }

    // 维度取值：ApiClient.post 只接受单条 Map，故逐条并行写入（维度通常 2-3 个）
    if (values.isNotEmpty) {
      await Future.wait<void>(values.entries.map((entry) async {
        final rowResult = await ApiClient.post(
          'game_score_values',
          <String, dynamic>{
            'id': const Uuid().v4(),
            'score_id': scoreId,
            'dimension_id': entry.key,
            'value': entry.value,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          returnRepresentation: false,
          note: 'games:submit_score_value',
        );
        if (!rowResult.isSuccess) {
          debugPrint(
              '[GameScoreService] 维度 ${entry.key} 写入失败：${rowResult.errorMessage}');
        }
      }));
    }

    // 成绩变动后最佳成绩可能变化，清掉缓存促下次重拉
    _memoryBest = null;
    await CacheHelper.instance.clear(CacheHelper.keyGameScores);
    return scoreId;
  }

  /// 查询当前用户在某游戏下已通关的关卡 id 集合。
  ///
  /// 供「需通关后选关(gated)」模式判断锁状态：已通关关卡可重挑战，
  /// 最新未通关关卡（frontier）可解锁，其余上锁。未登录返回空集合。
  Future<Set<String>> fetchClearedLevelIds(String gameId) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return <String>{};

    final result = await ApiClient.get(
      'game_scores',
      filters: <String, String>{
        'user_id': 'eq.$userId',
        'game_id': 'eq.$gameId',
        'status': 'eq.cleared',
      },
      order: 'played_at.desc',
      limit: null,
      note: 'games:cleared_levels',
    );
    if (!result.isSuccess) {
      debugPrint('[GameScoreService] 已通关关卡查询失败：${result.errorMessage}');
      return <String>{};
    }
    final rows = (result.data as List<dynamic>?) ?? <dynamic>[];
    final set = <String>{};
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        final lv = row['level_id'] as String?;
        if (lv != null) set.add(lv);
      }
    }
    return set;
  }

  /// 查询最佳成绩（服务端聚合）。
  ///
  /// [gameId] 为 null 时返回全部游戏最佳成绩（总看板用）；
  /// 否则只返回该游戏（单游戏看板用）。失败时回退本地缓存。
  Future<List<GameBestScore>> fetchBestScores({
    String? gameId,
    bool force = false,
  }) async {
    if (!force && gameId == null && _memoryBest != null) return _memoryBest!;

    final result = await ApiClient.rpc(
      'get_game_best_scores',
      params: <String, dynamic>{'p_game_id': gameId},
      note: 'games:best_scores',
    );

    if (!result.isSuccess) {
      debugPrint('[GameScoreService] 最佳成绩查询失败：${result.errorMessage}');
      return loadCachedBestScores();
    }

    final rows = (result.data as List<dynamic>?) ?? <dynamic>[];
    final list = rows
        .whereType<Map<String, dynamic>>()
        .map(GameBestScore.fromJson)
        .toList();

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

  /// 查询某游戏的成绩记录（按游玩时间倒序）。
  ///
  /// [limit] 为 null 时取全量（默认 10 会截断，看板场景须显式传值）。
  Future<List<GameScoreModel>> fetchScoreHistory(
    String gameId, {
    int? limit = 50,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return <GameScoreModel>[];

    final result = await ApiClient.get(
      'game_scores',
      filters: <String, String>{
        'user_id': 'eq.$userId',
        'game_id': 'eq.$gameId',
      },
      order: 'played_at.desc',
      limit: limit,
      note: 'games:score_history',
    );

    if (!result.isSuccess) {
      debugPrint('[GameScoreService] 成绩记录查询失败：${result.errorMessage}');
      return <GameScoreModel>[];
    }

    final rows = (result.data as List<dynamic>?) ?? <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(GameScoreModel.fromJson)
        .toList();
  }

  /// 清空成绩缓存（切换账号或下拉刷新用）。
  Future<void> clearCache() async {
    _memoryBest = null;
    await CacheHelper.instance.clear(CacheHelper.keyGameScores);
  }
}
