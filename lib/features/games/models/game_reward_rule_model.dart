/// 积分奖励规则类型（对应 public.game_reward_rules.rule_type）
///
/// 与后台 constants 保持一致，新增类型须同步后台配置页选项。
abstract final class GameRewardRuleType {
  /// 每日首次通关（跨游戏共享，单日仅 1 次）
  static const String dailyFirstClear = 'daily_first_clear';

  /// 成就达成奖励
  static const String achievement = 'achievement';

  /// 成绩区间首次达成（每游戏每档位 1 次）
  static const String scoreRange = 'score_range';

  /// 单日游戏奖励上限（全局唯一，初始 10 分）
  static const String dailyLimit = 'daily_limit';

  /// 全部合法类型（用于本地兜底校验）。
  static const List<String> values = <String>[
    dailyFirstClear,
    achievement,
    scoreRange,
    dailyLimit,
  ];
}

/// 积分奖励规则模型（对应 public.game_reward_rules 表）
///
/// 由后台配置下发；[gameId] 为 null 表示全局规则（如单日上限）。
/// [condition] 描述区间 / 阈值条件，由 App 端奖励服务解释。
class GameRewardRuleModel {
  /// 主键（uuid）
  final String id;

  /// 所属游戏 id（null = 全局规则）
  final String? gameId;

  /// 规则类型，见 [GameRewardRuleType]
  final String ruleType;

  /// 规则名称
  final String? name;

  /// 条件（jsonb）：区间 / 阈值
  final Map<String, dynamic> condition;

  /// 奖励积分（daily_limit 规则下表示上限值）
  final int points;

  /// 是否启用
  final bool enabled;

  /// 排序号（升序）
  final int sortOrder;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  /// 更新时间（UTC）
  final DateTime? updatedAt;

  const GameRewardRuleModel({
    required this.id,
    this.gameId,
    required this.ruleType,
    this.name,
    this.condition = const <String, dynamic>{},
    this.points = 0,
    this.enabled = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// 从 Supabase 行解析。
  factory GameRewardRuleModel.fromJson(Map<String, dynamic> json) {
    return GameRewardRuleModel(
      id: json['id'] as String? ?? '',
      gameId: json['game_id'] as String?,
      ruleType: json['rule_type'] as String? ?? '',
      name: json['name'] as String?,
      condition:
          (json['condition'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      points: (json['points'] as num?)?.toInt() ?? 0,
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
      'rule_type': ruleType,
      'name': name,
      'condition': condition,
      'points': points,
      'enabled': enabled,
      'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameRewardRuleModel copyWith({
    String? id,
    String? gameId,
    String? ruleType,
    String? name,
    Map<String, dynamic>? condition,
    int? points,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameRewardRuleModel(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      ruleType: ruleType ?? this.ruleType,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      points: points ?? this.points,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 奖励领取流水模型（对应 public.game_reward_claims 表）
///
/// **防刷 A 方案的落地支点**：表上有 (user_id, claim_key) 唯一索引，
/// 同一奖励同一用户只能领取一次；App 端插入命中唯一冲突即视为已领，不再发奖。
///
/// claim_key 约定（北京日期 yyyy-mm-dd）：
/// - `daily_first_clear:{yyyy-mm-dd}`  每日首次通关
/// - `score_range:{gameCode}:{ruleId}` 成绩区间首次达成
/// - `achievement:{achievementCode}`   成就达成
class GameRewardClaimModel {
  /// 主键（uuid）
  final String id;

  /// 用户业务 ID（U…）
  final String userId;

  /// 游戏 id（全局规则可为 null）
  final String? gameId;

  /// 触发的规则 id
  final String? ruleId;

  /// 领取键（同用户唯一）
  final String claimKey;

  /// 本次发放积分
  final int points;

  /// 领取时间（UTC）
  final DateTime? claimedAt;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  const GameRewardClaimModel({
    required this.id,
    required this.userId,
    this.gameId,
    this.ruleId,
    required this.claimKey,
    required this.points,
    this.claimedAt,
    this.createdAt,
  });

  /// 从 Supabase 行解析。
  factory GameRewardClaimModel.fromJson(Map<String, dynamic> json) {
    return GameRewardClaimModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      gameId: json['game_id'] as String?,
      ruleId: json['rule_id'] as String?,
      claimKey: json['claim_key'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      claimedAt: json['claimed_at'] != null
          ? DateTime.tryParse(json['claimed_at'].toString())
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
      'rule_id': ruleId,
      'claim_key': claimKey,
      'points': points,
      'claimed_at': (claimedAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameRewardClaimModel copyWith({
    String? id,
    String? userId,
    String? gameId,
    String? ruleId,
    String? claimKey,
    int? points,
    DateTime? claimedAt,
    DateTime? createdAt,
  }) {
    return GameRewardClaimModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      ruleId: ruleId ?? this.ruleId,
      claimKey: claimKey ?? this.claimKey,
      points: points ?? this.points,
      claimedAt: claimedAt ?? this.claimedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
