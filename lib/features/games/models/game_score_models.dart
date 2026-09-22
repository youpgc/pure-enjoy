/// 游戏成绩域模型（从 game_score_service.dart 拆出，逻辑零变更）。
///
/// 调用方经 game_score_service.dart 的 `export` 使用，无需改 import 路径。

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

/// 无尽模式单局明细（本地暂存，总结算时随会话主记录一次性上传）。
class GameEndlessRound {
  /// 局号（从 1 起）
  final int roundNo;

  /// 本局得分
  final int score;

  /// 本局步数（引擎未上报时为 null）
  final int? moves;

  /// 本局用时（毫秒）
  final int durationMs;

  const GameEndlessRound({
    required this.roundNo,
    required this.score,
    required this.durationMs,
    this.moves,
  });

  Map<String, dynamic> toRow({
    required String scoreId,
    required String userId,
    required String gameId,
    String? modeId,
  }) =>
      <String, dynamic>{
        'score_id': scoreId,
        'user_id': userId,
        'game_id': gameId,
        'mode_id': modeId,
        'round_no': roundNo,
        'score': score,
        'moves': moves,
        'duration_ms': durationMs,
      };
}
