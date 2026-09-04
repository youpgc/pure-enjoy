import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../utils/cache_helper.dart';
import '../models/game_achievement_model.dart';
import '../models/game_dimension_model.dart';
import '../models/game_level_model.dart';
import '../models/game_mode_model.dart';
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

  /// 全部游戏模式
  final List<GameModeModel> modes;

  /// 快照时间（本地缓存时为写入时间）
  final DateTime? cachedAt;

  const GameConfigSnapshot({
    this.games = const <GameModel>[],
    this.dimensions = const <GameDimensionModel>[],
    this.levels = const <GameLevelModel>[],
    this.achievements = const <GameAchievementModel>[],
    this.rewardRules = const <GameRewardRuleModel>[],
    this.modes = const <GameModeModel>[],
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

  /// 取指定游戏的模式（按 sort_order 升序）。
  List<GameModeModel> modesOf(String gameId) {
    final list = modes.where((m) => m.gameId == gameId).toList()
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

  /// 取全局单日奖励上限；未配置时兜底 10 分。
  int get dailyLimit {
    for (final rule in globalRewardRules) {
      if (rule.ruleType == GameRewardRuleType.dailyLimit && rule.enabled) {
        return rule.points;
      }
    }
    return 10;
  }

  /// 取指定游戏的单日奖励上限；未配置该游戏专属规则时兜底为全局上限。
  ///
  /// 对应 `rule_type='daily_limit' and game_id = <gameId>` 的启用规则
  /// （SQL 已为 sheep/g2048/match3 各配 50 分，单游戏日上限，见参考文档 §7/§13 D8）。
  /// 全局规则 game_id 为 null，不会命中此过滤，故未配置的兜底为全局上限而非 10，
  /// 避免多游戏时过于苛刻。
  int dailyLimitPerGame(String gameId) {
    for (final rule in rewardRules) {
      if (rule.gameId == gameId &&
          rule.ruleType == GameRewardRuleType.dailyLimit &&
          rule.enabled) {
        return rule.points;
      }
    }
    return dailyLimit;
  }

  /// 序列化为本地缓存结构（时间以 UTC ISO 字符串存储）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'games': games.map((e) => e.toJson()).toList(),
        'dimensions': dimensions.map((e) => e.toJson()).toList(),
        'levels': levels.map((e) => e.toJson()).toList(),
        'achievements': achievements.map((e) => e.toJson()).toList(),
        'reward_rules': rewardRules.map((e) => e.toJson()).toList(),
        'modes': modes.map((e) => e.toJson()).toList(),
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
      modes: parseRows<GameModeModel>('modes', GameModeModel.fromJson),
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

  /// 上次成功拉取时间：内存缓存在 TTL 内直接复用，过期后重新拉取。
  /// 旧实现「有内存缓存就永远不刷新」导致后台新配的关卡/规则 App 端收不到
  /// （表现为：后台扩到 10 关，App 仍按旧 2 关推进，通关后没有下一关）。
  static const Duration _ttl = Duration(seconds: 30);
  DateTime? _lastFetchAt;

  /// 进程内缓存快照（未拉取过返回空快照；调用方应先 fetchConfig / loadCachedConfig）。
  GameConfigSnapshot get cachedConfig => _memory ?? const GameConfigSnapshot();

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

  /// 拉取最新配置；[force] 为 true 时跳过缓存直接请求（下拉刷新用）。
  ///
  /// 非 force 时若内存快照在 TTL 内直接复用，过期则重新拉取并回写；
  /// 任一张表失败时按空列表兜底并记日志，不影响其余配置渲染。
  Future<GameConfigSnapshot> fetchConfig({bool force = false}) async {
    final memory = _memory;
    final fresh = _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < _ttl;
    if (!force && memory != null && fresh) return memory;

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _fetchRows('games', order: 'sort_order.asc'),
      _fetchRows('game_dimensions', order: 'sort_order.asc'),
      _fetchRows('game_levels', order: 'sort_order.asc'),
      _fetchRows('game_achievements', order: 'sort_order.asc'),
      _fetchRows('game_reward_rules', order: 'sort_order.asc'),
      _fetchRows('game_modes', order: 'sort_order.asc'),
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
      modes: _toModels<GameModeModel>(results[5], GameModeModel.fromJson),
      cachedAt: DateTime.now(),
    );

    _memory = snapshot;
    _lastFetchAt = DateTime.now();
    // 回写本地缓存，供下次开屏秒渲染
    await CacheHelper.instance.saveMap(CacheHelper.keyGames, snapshot.toJson());
    return snapshot;
  }

  /// 清空配置缓存（后台改配置后可在下拉刷新时调用）。
  Future<void> clearCache() async {
    _memory = null;
    _lastFetchAt = null;
    await CacheHelper.instance.clear(CacheHelper.keyGames);
  }

  /// 查询启用行；失败返回空列表并记日志（配置表为全局表，不按用户过滤）。
  ///
  /// **分页拉全量**：PostgREST 服务端默认单次最多返回 1000 行（db-max-rows），
  /// `limit:null` 且无 Range 头会被静默截断（game_levels 1200 关只拿到前 1000，
  /// 选关/下一关/关序折算全部失真）。这里按 1000/页循环拉取直至不足一页。
  Future<List<dynamic>> _fetchRows(
    String table, {
    required String order,
  }) async {
    const pageSize = 1000;
    final all = <dynamic>[];
    var offset = 0;
    while (true) {
      final result = await ApiClient.get(
        table,
        filters: <String, String>{'enabled': 'eq.true'},
        order: order,
        limit: pageSize,
        offset: offset,
        note: 'games:$table',
      );
      if (!result.isSuccess) {
        debugPrint('[GameService] 拉取 $table 失败：${result.errorMessage}');
        // 首页失败返回空；后续页失败保留已拉到的部分（优于整体放弃）
        return offset == 0 ? <dynamic>[] : all;
      }
      final rows = (result.data as List<dynamic>?) ?? <dynamic>[];
      all.addAll(rows);
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return all;
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
