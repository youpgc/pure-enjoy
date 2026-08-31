/// 游戏配置模型（对应 public.games 表）
///
/// 游戏目录由后台配置并下发，App 端只读：按 [engine] 决定渲染方式
/// （'widget'=纯 Flutter 实现，'flame'=Flame 引擎实现）。
///
/// 玩法规则由 App 端代码实现，云端只管「开关 / 排序 / 玩法参数」，
/// 故本模型不含 toJsonForUpdate —— App 端不修改游戏配置。
class GameModel {
  /// 主键（uuid）
  final String id;

  /// 游戏编码（唯一）：'sheep' / 'g2048' / 'match3'
  final String code;

  /// 展示名称
  final String name;

  /// 图标标识（App 端映射为 IconData）
  final String? icon;

  /// 游戏简介
  final String? description;

  /// 渲染引擎：'widget' | 'flame'
  final String engine;

  /// 是否启用（下线后 App 不展示）
  final bool enabled;

  /// 排序号（升序）
  final int sortOrder;

  /// 玩法参数（jsonb）：网格大小、层数等
  final Map<String, dynamic> config;

  /// 配置版本（App 可据此判断是否需要重拉）
  final int version;

  /// 是否允许选关：true 时游戏大厅点击该游戏弹出选关界面；
  /// false（默认）则直接进入第一个启用关卡，不弹选关。由后台配置下发。
  final bool levelSelectable;

  /// 选关模式（仅 [levelSelectable]=true 时生效）：
  ///   'gated' = 需通关后选关（未通关且非最新关卡上锁，已通关可重挑战）
  ///   'free'  = 直接选关挑战（无视前置关卡是否通关）
  /// 顺序通关（[levelSelectable]=false）时不参与逻辑。
  final String levelSelectMode;

  /// 创建时间（UTC）
  final DateTime? createdAt;

  /// 更新时间（UTC）
  final DateTime? updatedAt;

  const GameModel({
    required this.id,
    required this.code,
    required this.name,
    this.icon,
    this.description,
    this.engine = 'widget',
    this.enabled = true,
    this.sortOrder = 0,
    this.config = const <String, dynamic>{},
    this.version = 1,
    this.levelSelectable = false,
    this.levelSelectMode = 'gated',
    this.createdAt,
    this.updatedAt,
  });

  /// 从 Supabase 行解析；缺省字段给安全默认值，避免后端新增列时解析崩溃。
  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      description: json['description'] as String?,
      engine: json['engine'] as String? ?? 'widget',
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      config: (json['config'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      version: (json['version'] as num?)?.toInt() ?? 1,
      levelSelectable: json['level_selectable'] as bool? ?? false,
      levelSelectMode: (json['level_select_mode'] as String? ?? 'gated'),
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
      'code': code,
      'name': name,
      'icon': icon,
      'description': description,
      'engine': engine,
      'enabled': enabled,
      'sort_order': sortOrder,
      'config': config,
      'version': version,
      'level_selectable': levelSelectable,
      'level_select_mode': levelSelectMode,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  /// 复制并覆盖指定字段。
  GameModel copyWith({
    String? id,
    String? code,
    String? name,
    String? icon,
    String? description,
    String? engine,
    bool? enabled,
    int? sortOrder,
    Map<String, dynamic>? config,
    int? version,
    bool? levelSelectable,
    String? levelSelectMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      engine: engine ?? this.engine,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      config: config ?? this.config,
      version: version ?? this.version,
      levelSelectable: levelSelectable ?? this.levelSelectable,
      levelSelectMode: levelSelectMode ?? this.levelSelectMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否走 Flame 引擎渲染。
  bool get isFlameEngine => engine == 'flame';
}
