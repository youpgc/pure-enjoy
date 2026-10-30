/// 亲密度等级换算（等级制：不封顶、按等级拆分展示，20261021 用户拍板）。
///
/// intimacy 字段存**累计值**（服务端 `_pet_gain_intimacy` 已去 100 封顶持续
/// 累加），等级为纯展示换算：本级需求 = round(base × growth^(level-1))
/// （Lv1→2 需 base，Lv2→3 需 base×growth，以此类推）。base/growth 来自
/// summary config（intimacy_level_base / intimacy_level_growth）。
///
/// 缺键或非法（base≤0 / growth≤1）返回 null，调用方回退累计值平铺展示，
/// 不造默认值——与 petExpNeed 缺键返 null 同一口径。
library;

/// 返回 (当前等级, 当前级起点累计值, 本级需求, 级内已入)；曲线未配置返回 null
({int level, int levelStart, int need, int intoLevel})? petIntimacyLevel(
    int intimacy, Map<String, dynamic>? config) {
  final baseRaw = config?['intimacy_level_base'];
  final growthRaw = config?['intimacy_level_growth'];
  // 缺键/非法 → null，不造默认值
  if (baseRaw is! num || baseRaw <= 0) return null;
  // growth 必须 >1：≤1 会让本级需求不递增/递减，等级推导无法收敛
  if (growthRaw is! num || growthRaw <= 1) return null;
  final base = baseRaw.toDouble();
  final growth = growthRaw.toDouble();

  var level = 1;
  var start = 0; // 当前级起点（累计值）
  var need = base.round();
  var guard = 0;
  while (intimacy >= start + need && guard < 999) {
    // 需求指数增长到理论越界前停止（实际不可达,防御手工改库的 int 溢出）
    if (need > (1 << 62)) break;
    start += need;
    need = (need * growth).round();
    level++;
    guard++;
  }
  return (
    level: level,
    levelStart: start,
    need: need,
    intoLevel: intimacy - start
  );
}
