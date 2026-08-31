import 'game_dimension_model.dart';

/// 游玩 / 成绩主记录模型（对应 public.game_scores 表）
///
/// 一次游玩产生一条主记录，各维度取值落在 [GameScoreValueModel]（一对多），
/// 因为维度由后台配置、数量不固定，故不硬编码列。
class GameScoreModel {
  /// 主键（uuid）
  final String id;

  /// 用户业务 ID（U…，对应 users.id）
  final String userId;

  /// 游戏 id
  final String gameId;

  /// 关卡 id（无关卡玩法可为 null）
  final String? levelId;

  /// 结果：'cleared'（通关） | 'failed'（失败） | 'aborted'（中途退出）
  final String status;

  /// 本次游玩耗时（毫秒）
  final int? durationMs;

  /// 游玩结束时间（UTC 存储，北京时区展示）
  final DateTime? playedAt;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  const GameScoreModel({
    required this.id,
    required this.userId,
    required this.gameId,
    this.levelId,
    this.status = 'cleared',
    this.durationMs,
    this.playedAt,
    this.createdAt,
  });

  /// 是否通关。
  bool get isCleared => status == 'cleared';

  /// 从 Supabase 行解析。
  factory GameScoreModel.fromJson(Map<String, dynamic> json) {
    return GameScoreModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      levelId: json['level_id'] as String?,
      status: json['status'] as String? ?? 'cleared',
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      playedAt: json['played_at'] != null
          ? DateTime.tryParse(json['played_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// 序列化为 Supabase 行（时间统一 UTC 存储）。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'game_id': gameId,
      'level_id': levelId,
      'status': status,
      'duration_ms': durationMs,
      'played_at': (playedAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  /// 更新时仅可改动的列（其余为写入即固定）。
  Map<String, dynamic> toJsonForUpdate() {
    return <String, dynamic>{
      'status': status,
      'duration_ms': durationMs,
    };
  }

  /// 复制并覆盖指定字段。
  GameScoreModel copyWith({
    String? id,
    String? userId,
    String? gameId,
    String? levelId,
    String? status,
    int? durationMs,
    DateTime? playedAt,
    DateTime? createdAt,
  }) {
    return GameScoreModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      levelId: levelId ?? this.levelId,
      status: status ?? this.status,
      durationMs: durationMs ?? this.durationMs,
      playedAt: playedAt ?? this.playedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 成绩维度值模型（对应 public.game_score_values 表）
///
/// 一条成绩记录在某个维度上的取值（如「分数=2048」「用时=92000ms」）。
/// [value] 用 num 兼容整数分数、毫秒时长与小数。
class GameScoreValueModel {
  /// 主键（uuid）
  final String id;

  /// 所属成绩记录 id
  final String scoreId;

  /// 维度 id
  final String dimensionId;

  /// 取值
  final num value;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  const GameScoreValueModel({
    required this.id,
    required this.scoreId,
    required this.dimensionId,
    required this.value,
    this.createdAt,
  });

  /// 从 Supabase 行解析。
  factory GameScoreValueModel.fromJson(Map<String, dynamic> json) {
    return GameScoreValueModel(
      id: json['id'] as String? ?? '',
      scoreId: json['score_id'] as String? ?? '',
      dimensionId: json['dimension_id'] as String? ?? '',
      value: (json['value'] as num?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// 序列化为 Supabase 行（时间统一 UTC 存储）。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'score_id': scoreId,
      'dimension_id': dimensionId,
      'value': value,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameScoreValueModel copyWith({
    String? id,
    String? scoreId,
    String? dimensionId,
    num? value,
    DateTime? createdAt,
  }) {
    return GameScoreValueModel(
      id: id ?? this.id,
      scoreId: scoreId ?? this.scoreId,
      dimensionId: dimensionId ?? this.dimensionId,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 成绩看板展示项：一条成绩 + 其全部维度取值（按维度定义排序）。
///
/// 由 service 层组装，供看板 UI 直接渲染，避免 UI 层重复关联逻辑。
class GameScoreEntry {
  /// 成绩主记录
  final GameScoreModel score;

  /// 各维度取值（键为维度编码，便于 UI 按 code 直接取用）
  final Map<String, num> values;

  /// 该游戏的维度定义（按 sort_order 升序）
  final List<GameDimensionModel> dimensions;

  const GameScoreEntry({
    required this.score,
    required this.values,
    required this.dimensions,
  });

  /// 取指定维度编码的取值，缺失返回 null。
  num? valueOf(String dimensionCode) => values[dimensionCode];
}
