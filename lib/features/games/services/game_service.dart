import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../utils/cache_helper.dart';
import '../models/game_achievement_model.dart';
import '../models/game_dimension_model.dart';
import '../models/game_level_model.dart';
import '../models/game_model.dart';
import '../models/game_reward_rule_model.dart';

/// 游戏中心配置快照
///
/// 一次拉取并缓存游戏目录、成绩维度、关卡、成就与奖励规则，
/// 供大厅、各游戏页与成绩看板复用，避免同一配置被重复请求。
class GameConfigSnapshot {
  /// 启用的游戏（按 sort_order 升序）
  final List<GameModel> games;

  /// 全部成绩维度
  final List<GameDimensionModel> dimensions;

  /// 全部关卡
  final List<GameLevelModel> levels;

  /// 全部成就
  final List<GameAchievementModel> achievements;

  /// 全部奖励规则
  final List<GameRewardRuleModel> rewardRules;

  /// 快照时间（本地缓存时为写入时间）
  final DateTime? cachedAt;

  const GameConfigSnapshot({
    this.games = const <GameModel>[],
    this.dimensions = const <GameDimensionModel>[],
    this.levels = const <GameLevelModel>[],
    this.achievements = const <GameAchievementModel>[],
    this.rewardRules = const <GameRewardRuleModel>[],
    this.cachedAt,
  });

  /// 是否为空（用于判断是否有可渲染内容）。
  bool get isEmpty => games.isEmpty;

  /// 取指定游戏的成绩维度（按 sort_order 升序）。
  List<GameDimensionModel> dimensionsOf(String gameId) {
    final list = dimensions.where((d) => d.gameId == gameId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// 取指定游戏的关卡（按 sort_order 升序）。
  List<GameLevelModel> levelsOf(String gameId) {
    final list = levels.where((l) => l.gameId == gameId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// 取指定游戏的成就（按 sort_order 升序）。
  List<GameAchievementModel> achievementsOf(String gameId) {
    final list = achievements.where((a) => a.gameId == gameId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// 取全局奖励规则（game_id 为 null）。
  List<GameRewardRuleModel> get globalRewardRules =>
      rewardRules.where((r) => r.gameId == null).toList();

  /// 取单日奖励上限；未配置时兜底 10 分。
  int get dailyLimit {
    for (final rule in globalRewardRules) {
      if (rule.ruleType == GameRewardRuleType.dailyLimit && rule.enabled) {
        return rule.points;
      }
    }
    return 10;
  }

  /// 序列化为本地缓存结构（时间以 UTC ISO 字符串存储）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'games': games.map((e) => e.toJson()).toList(),
        'dimensions': dimensions.map((e) => e.toJson()).toList(),
        'levels': levels.map((e) => e.toJson()).toList(),
        'achievements': achievements.map((e) => e.toJson()).toList(),
        'reward_rules': rewardRules.map((e) => e.toJson()).toList(),
        'cached_at': (cachedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  /// 从本地缓存结构还原；任一段缺失按空处理，避免旧缓存结构变更导致崩溃。
  factory GameConfigSnapshot.fromJson(Map<String, dynamic> json) {
    List<T> parseRows<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }

    final cachedAtRaw = json['cached_at']?.toString();
    return GameConfigSnapshot(
      games: parseRows<GameModel>('games', GameModel.fromJson),
      dimensions:
          parseRows<GameDimensionModel>('dimensions', GameDimensionModel.fromJson),
      levels: parseRows<GameLevelModel>('levels', GameLevelModel.fromJson),
      achievements: parseRows<GameAchievementModel>(
          'achievements', GameAchievementModel.fromJson),
      rewardRules: parseRows<GameRewardRuleModel>(
          'reward_rules', GameRewardRuleModel.fromJson),
      cachedAt:
          cachedAtRaw != null ? DateTime.tryParse(cachedAtRaw) : null,
    );
  }
}

/// 游戏中心配置服务
///
/// 职责：拉取并缓存「游戏目录 / 成绩维度 / 关卡 / 成就 / 奖励规则」。
/// 采用与积分页一致的「缓存优先 + 后台校正」策略：
/// 开屏先读本地缓存秒渲染（防闪空页），再静默拉取最新配置并回写缓存。
///
/// 全部读取走 [ApiClient]；配置表为全局表（非用户数据），无需按用户过滤。
class GameService {
  GameService._();

  /// 单例
  static final GameService instance = GameService._();

  /// 内存快照（进程内复用，避免同一开屏重复解析缓存）
  GameConfigSnapshot? _memory;

  /// 读取本地缓存快照（供开屏秒渲染；无缓存返回 null）。
  Future<GameConfigSnapshot?> loadCachedConfig() async {
    if (_memory != null) return _memory;
    final cached = await CacheHelper.instance.loadMap(CacheHelper.keyGames);
    if (cached == null) return null;
    final snapshot = GameConfigSnapshot.fromJson(cached);
    if (snapshot.isEmpty) return null;
    _memory = snapshot;
    return snapshot;
  }

  /// 拉取最新配置；[force] 为 true 时跳过内存缓存直接请求（下拉刷新用）。
  ///
  /// 任一张表失败时按空列表兜底并记日志，不影响其余配置渲染。
  Future<GameConfigSnapshot> fetchConfig({bool force = false}) async {
    if (!force && _memory != null) return _memory!;

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _fetchRows('games', order: 'sort_order.asc'),
      _fetchRows('game_dimensions', order: 'sort_order.asc'),
      _fetchRows('game_levels', order: 'sort_order.asc'),
      _fetchRows('game_achievements', order: 'sort_order.asc'),
      _fetchRows('game_reward_rules', order: 'sort_order.asc'),
    ]);

    final snapshot = GameConfigSnapshot(
      games: _toModels<GameModel>(results[0], GameModel.fromJson),
      dimensions:
          _toModels<GameDimensionModel>(results[1], GameDimensionModel.fromJson),
      levels: _toModels<GameLevelModel>(results[2], GameLevelModel.fromJson),
      achievements: _toModels<GameAchievementModel>(
          results[3], GameAchievementModel.fromJson),
      rewardRules: _toModels<GameRewardRuleModel>(
          results[4], GameRewardRuleModel.fromJson),
      cachedAt: DateTime.now(),
    );

    _memory = snapshot;
    // 回写本地缓存，供下次开屏秒渲染
    await CacheHelper.instance.saveMap(CacheHelper.keyGames, snapshot.toJson());
    return snapshot;
  }

  /// 清空配置缓存（后台改配置后可在下拉刷新时调用）。
  Future<void> clearCache() async {
    _memory = null;
    await CacheHelper.instance.clear(CacheHelper.keyGames);
  }

  /// 查询启用行；失败返回空列表并记日志（配置表为全局表，不按用户过滤）。
  Future<List<dynamic>> _fetchRows(
    String table, {
    required String order,
  }) async {
    final result = await ApiClient.get(
      table,
      filters: <String, String>{'enabled': 'eq.true'},
      order: order,
      limit: null, // 配置表行数有限，取全量（避免默认 limit=10 截断）
      note: 'games:$table',
    );
    if (!result.isSuccess) {
      debugPrint('[GameService] 拉取 $table 失败：${result.errorMessage}');
      return <dynamic>[];
    }
    return (result.data as List<dynamic>?) ?? <dynamic>[];
  }

  /// 将原始行列表转为模型列表（跳过结构异常行，避免单行脏数据导致整页崩溃）。
  List<T> _toModels<T>(
    dynamic rows,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (rows is! List) return <T>[];
    final list = <T>[];
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        list.add(fromJson(row));
      }
    }
    return list;
  }
}
