import 'dart:math' as math;

/// 经验曲线（需求 §3.1「升级曲线后台可配」）。
///
/// 服务端 `_pet_add_progress` 的升级需求式：`need(level) = round(base × growth^(level-1))`，
/// 两参来自 `pet_config.level_exp_base / level_exp_growth`，由 `rpc_pet_summary`
/// 的 config 块同源下发（§17「两端同源」口径，Admin 改配置即生效）。
///
/// 任一键缺失或非法（旧版服务端 / 配置异常）返回 null，调用方回退旧的 /100
/// 展示，不阻塞不造默认值——与 `feed_full_hunger` 缺键回退同一口径。
int? petExpNeed(int level, Map<String, dynamic>? config) {
  if (config == null) return null;
  final base = config['level_exp_base'];
  final growth = config['level_exp_growth'];
  if (base is! num || growth is! num || base <= 0 || growth <= 1) return null;
  if (level < 1) level = 1;
  return (base * math.pow(growth.toDouble(), level - 1)).round();
}
