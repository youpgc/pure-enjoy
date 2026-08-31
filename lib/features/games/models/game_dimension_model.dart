/// 成绩维度模型（对应 public.game_dimensions 表）
///
/// 定义一款游戏「按什么维度计成绩」（分数 / 用时 / 关卡 / 步数），由后台配置。
/// 它同时驱动两处：成绩看板的展示列，与「成绩区间奖励」的判定依据。
///
/// [aggregate] 决定最佳成绩的聚合方式：max（越大越好，如分数）、min（越小越好，如用时）、
/// sum（累计）、latest（取最近一次）。
class GameDimensionModel {
  /// 主键（uuid）
  final String id;

  /// 所属游戏 id
  final String gameId;

  /// 维度编码：'score' / 'duration_ms' / 'level' / 'moves'
  final String code;

  /// 展示名称：分数 / 用时 / 关卡 / 步数
  final String name;

  /// 单位：分 / ms / 关 / 步
  final String? unit;

  /// 值类型：'int' | 'duration_ms'
  final String valueType;

  /// 聚合方式：'max' | 'min' | 'sum' | 'latest'
  final String aggregate;

  /// 排序号（升序）
  final int sortOrder;

  /// 是否主维度（看板默认排序 / 卡片主展示）
  final bool isPrimary;

  /// 是否启用
  final bool enabled;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  /// 更新时间（UTC）
  final DateTime? updatedAt;

  const GameDimensionModel({
    required this.id,
    required this.gameId,
    required this.code,
    required this.name,
    this.unit,
    this.valueType = 'int',
    this.aggregate = 'max',
    this.sortOrder = 0,
    this.isPrimary = false,
    this.enabled = true,
    this.createdAt,
    this.updatedAt,
  });

  /// 从 Supabase 行解析。
  factory GameDimensionModel.fromJson(Map<String, dynamic> json) {
    return GameDimensionModel(
      id: json['id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String?,
      valueType: json['value_type'] as String? ?? 'int',
      aggregate: json['aggregate'] as String? ?? 'max',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
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
      'unit': unit,
      'value_type': valueType,
      'aggregate': aggregate,
      'sort_order': sortOrder,
      'is_primary': isPrimary,
      'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameDimensionModel copyWith({
    String? id,
    String? gameId,
    String? code,
    String? name,
    String? unit,
    String? valueType,
    String? aggregate,
    int? sortOrder,
    bool? isPrimary,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameDimensionModel(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      code: code ?? this.code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      valueType: valueType ?? this.valueType,
      aggregate: aggregate ?? this.aggregate,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否「越小越好」（用时类维度）。
  bool get isLowerBetter => aggregate == 'min';

  /// 是否时间类维度（展示时需格式化为 mm:ss）。
  bool get isDuration => valueType == 'duration_ms';
}
