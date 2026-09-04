/// 游戏模式模型（对应 public.game_modes 表）
///
/// 模式为一等公民（经典/限时/挑战/无尽/计分/消除/...），由后台配置驱动，
/// App 端不硬编码——模式清单全部来自 [GameService] 下发的 game_modes 表。
/// 同一游戏的不同模式共享同一套玩法引擎，仅 [config]（尺寸/限时/步数/目标）不同。
class GameModeModel {
  /// 主键（uuid）
  final String id;

  /// 所属游戏 id
  final String gameId;

  /// 模式编码（如 classic/timed/challenge/endless/score/clear/...）
  final String code;

  /// 模式名称
  final String name;

  /// 模式图标标识（对应前端图标资源 key，如 mode_classic / mode_score）
  final String icon;

  /// 引擎子类型语义（如 2048 / 2048_timed / score / clear / collect / boss / merge）
  /// App 据此决定图标配色与（必要时）引擎分支。
  final String playKind;

  /// 排序号（升序）
  final int sortOrder;

  /// 是否启用
  final bool enabled;

  /// 模式默认配置（jsonb）：如默认尺寸/限时/步数等，关卡可覆盖
  final Map<String, dynamic> config;

  const GameModeModel({
    required this.id,
    required this.gameId,
    required this.code,
    required this.name,
    this.icon = '',
    this.playKind = '',
    this.sortOrder = 0,
    this.enabled = true,
    this.config = const <String, dynamic>{},
  });

  /// 从 Supabase 行解析。
  factory GameModeModel.fromJson(Map<String, dynamic> json) {
    return GameModeModel(
      id: json['id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      playKind: json['play_kind'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      config: (json['config'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// 序列化为 Supabase 行（时间统一 UTC 存储）。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'game_id': gameId,
      'code': code,
      'name': name,
      'icon': icon,
      'play_kind': playKind,
      'sort_order': sortOrder,
      'enabled': enabled,
      'config': config,
    };
  }

  /// 是否为无尽模式（无关卡、由 App 合成无尽局）。
  bool get isEndless => code == 'endless' || playKind == '2048_endless';
}
