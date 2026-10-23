import 'dart:math' as math;

/// 经验曲线（需求 §3.1「升级曲线后台可配」）。
///
/// 两级取值，**查表优先**：
/// 1. `pet_config.level_exp_table`（jsonb，键=当前等级，值=升下一级所需）——
///    定版节奏表（常规 365 天 / 满配约 91 天 / 每级耗时严格前快后慢）由
///    服务端 `fix_pet_level_exp_table_20261023.sql` 写入，Admin 可调；
/// 2. 缺键/缺表回退公式 `need(level) = round(base × growth^(level-1))`，
///    两参来自 `pet_config.level_exp_base / level_exp_growth`。
///
/// 两路均由 `rpc_pet_summary` 的 config 块同源下发（§17「两端同源」口径，
/// Admin 改配置即生效）。任一配置缺失或非法返回 null，调用方回退旧的 /100
/// 展示，不阻塞不造默认值——与 `feed_full_hunger` 缺键回退同一口径。
int? petExpNeed(int level, Map<String, dynamic>? config) {
  if (config == null) return null;
  final table = config['level_exp_table'];
  if (table is Map) {
    final v = table['$level'];
    // 表值须为正整数：非法表项不采信，走公式回退
    if (v is num && v > 0) return v.toInt();
  }
  final base = config['level_exp_base'];
  final growth = config['level_exp_growth'];
  // growth == 1（平坦曲线）是合法配置：need 恒等于 base，必须照算——
  // 拒绝它会让 App 回退 /100，与 base≠100 的服务端曲线再次不同源
  if (base is! num || growth is! num || base <= 0 || growth <= 0) return null;
  if (level < 1) level = 1;
  return (base * math.pow(growth.toDouble(), level - 1)).round();
}

/// 是否已达等级上限（pet_config.level_max，服务端同源冻结 exp）。
/// 缺键（旧版服务端）视为未达上限——不造默认值，回退普通展示。
bool petExpMaxed(int level, Map<String, dynamic>? config) {
  if (config == null) return false;
  final max = config['level_max'];
  return max is num && max > 0 && level >= max;
}
