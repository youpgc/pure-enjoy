/// 关卡配置模型（对应 public.game_levels 表）
///
/// 关卡的布局与通关条件由后台配置下发，App 端只读并按 [config] 渲染关卡。
/// [target] 描述通关判定条件（按维度阈值），具体语义由各游戏实现解释。
class GameLevelModel {
  /// 主键（uuid）
  final String id;

  /// 所属游戏 id
  final String gameId;

  /// 关卡序号（同游戏内唯一）
  final int levelNo;

  /// 关卡名称
  final String name;

  /// 关卡布局 / 难度参数（jsonb）
  final Map<String, dynamic> config;

  /// 通关条件（jsonb）：按维度阈值判定，如 {'score': {'gte': 1000}}
  final Map<String, dynamic> target;

  /// 是否启用
  final bool enabled;

  /// 是否计入「每日首次通关奖励」。
  /// 仅当 true 时通关该关才触发每日首通奖励（首关过简单时不开启，由后台指定）。
  final bool countForDailyClear;

  /// 通关该关获得的积分；0 表示无通关奖励（结算时告知，不展示无效行）。
  final int rewardPoints;

  /// 是否可重复通关获取奖励。
  /// true = 每次通关均可获得（受单日上限约束）；false = 仅首次通关获得（终身一次）。
  final bool rewardRepeatable;

  /// 排序号（升序）
  final int sortOrder;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  /// 更新时间（UTC）
  final DateTime? updatedAt;

  const GameLevelModel({
    required this.id,
    required this.gameId,
    required this.levelNo,
    required this.name,
    this.config = const <String, dynamic>{},
    this.target = const <String, dynamic>{},
    this.enabled = true,
    this.countForDailyClear = false,
    this.rewardPoints = 0,
    this.rewardRepeatable = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// 从 Supabase 行解析。
  factory GameLevelModel.fromJson(Map<String, dynamic> json) {
    return GameLevelModel(
      id: json['id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      levelNo: (json['level_no'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      config: (json['config'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      target: (json['target'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      enabled: json['enabled'] as bool? ?? true,
      countForDailyClear:
          json['count_for_daily_clear'] as bool? ?? false,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      rewardRepeatable: json['reward_repeatable'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// 序列化为 Supabase 行（时间统一 UTC 存储）。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'game_id': gameId,
      'level_no': levelNo,
      'name': name,
      'config': config,
      'target': target,
      'enabled': enabled,
      'count_for_daily_clear': countForDailyClear,
      'reward_points': rewardPoints,
      'reward_repeatable': rewardRepeatable,
      'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameLevelModel copyWith({
    String? id,
    String? gameId,
    int? levelNo,
    String? name,
    Map<String, dynamic>? config,
    Map<String, dynamic>? target,
    bool? enabled,
    bool? countForDailyClear,
    int? rewardPoints,
    bool? rewardRepeatable,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameLevelModel(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      levelNo: levelNo ?? this.levelNo,
      name: name ?? this.name,
      config: config ?? this.config,
      target: target ?? this.target,
      enabled: enabled ?? this.enabled,
      countForDailyClear: countForDailyClear ?? this.countForDailyClear,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      rewardRepeatable: rewardRepeatable ?? this.rewardRepeatable,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
