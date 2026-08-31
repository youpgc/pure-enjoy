/// 成就定义模型（对应 public.game_achievements 表）
///
/// 成就由后台配置下发；[gameId] 为 null 表示跨游戏全局成就。
/// [condition] 描述达成条件（维度阈值 / 累计次数 / 特殊标记），由 App 端各游戏实现解释。
class GameAchievementModel {
  /// 主键（uuid）
  final String id;

  /// 所属游戏 id（null = 全局成就）
  final String? gameId;

  /// 成就编码（唯一）
  final String code;

  /// 成就名称
  final String name;

  /// 成就描述
  final String? description;

  /// 图标标识
  final String? icon;

  /// 达成条件（jsonb）
  final Map<String, dynamic> condition;

  /// 达成奖励积分
  final int rewardPoints;

  /// 是否启用
  final bool enabled;

  /// 排序号（升序）
  final int sortOrder;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  /// 更新时间（UTC）
  final DateTime? updatedAt;

  const GameAchievementModel({
    required this.id,
    this.gameId,
    required this.code,
    required this.name,
    this.description,
    this.icon,
    this.condition = const <String, dynamic>{},
    this.rewardPoints = 0,
    this.enabled = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// 从 Supabase 行解析。
  factory GameAchievementModel.fromJson(Map<String, dynamic> json) {
    return GameAchievementModel(
      id: json['id'] as String? ?? '',
      gameId: json['game_id'] as String?,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      condition:
          (json['condition'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
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
      'code': code,
      'name': name,
      'description': description,
      'icon': icon,
      'condition': condition,
      'reward_points': rewardPoints,
      'enabled': enabled,
      'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameAchievementModel copyWith({
    String? id,
    String? gameId,
    String? code,
    String? name,
    String? description,
    String? icon,
    Map<String, dynamic>? condition,
    int? rewardPoints,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameAchievementModel(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      condition: condition ?? this.condition,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 用户成就模型（对应 public.user_game_achievements 表）
///
/// 表上有 (user_id, achievement_id) 唯一索引，是「同一成就只发一次奖」的
/// 数据库兜底；App 端插入失败（唯一冲突）即视为已解锁，不重复发奖。
class UserGameAchievementModel {
  /// 主键（uuid）
  final String id;

  /// 用户业务 ID（U…）
  final String userId;

  /// 成就 id
  final String achievementId;

  /// 解锁时间（UTC）
  final DateTime? unlockedAt;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  const UserGameAchievementModel({
    required this.id,
    required this.userId,
    required this.achievementId,
    this.unlockedAt,
    this.createdAt,
  });

  /// 从 Supabase 行解析。
  factory UserGameAchievementModel.fromJson(Map<String, dynamic> json) {
    return UserGameAchievementModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      achievementId: json['achievement_id'] as String? ?? '',
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
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
      'achievement_id': achievementId,
      'unlocked_at': (unlockedAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  UserGameAchievementModel copyWith({
    String? id,
    String? userId,
    String? achievementId,
    DateTime? unlockedAt,
    DateTime? createdAt,
  }) {
    return UserGameAchievementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      achievementId: achievementId ?? this.achievementId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
