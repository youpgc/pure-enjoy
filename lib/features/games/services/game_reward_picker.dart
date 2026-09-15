import '../models/game_achievement_model.dart';
import '../models/game_reward_rule_model.dart';

/// 成就条件类型：首次通关（condition 缺省时的默认类型）
const String kAchievementTypeFirstClear = 'first_clear';

/// 成就条件类型：关卡里程碑（min_level_no）
const String kAchievementTypeLevel = 'level';

/// 成就条件类型：单局得分里程碑（dimension + gte）
const String kAchievementTypeScore = 'score';

/// 成就条件类型：模式段位徽章（v2 徽章化：mode_tier，不发积分仅解锁）
const String kAchievementTypeModeTier = 'mode_tier';

/// 成就条件类型：终身累计达成（metric + value，跨局累加）
const String kAchievementTypeCumulative = 'cumulative';

/// 全局注入维度：连续签到天数（跨游戏通用；结算时由 App 从积分模块读取注入）。
const String kDimensionStreakDays = 'streak_days';

/// match3 维度：本局「收集/破冰」完成数（`Match3Objective.collectedTotal`）。
const String kDimensionCollectDone = 'collect_done';

/// sheep 维度：本关层数（关卡 config.layers）。
const String kDimensionLayers = 'layers';

/// ── 成就条件词汇表（**唯一契约**）────────────────────────────────
/// 三方必须同口径：本文件（判定器）/ `gen/game_module_v2/06_seed_achievements.sql`（种子）
/// / `游戏模块配置参考文档.md` §7。新增 type / dimension / metric 必须三处同步。
///
/// `type`：
///   · `first_clear`  无键 ·············· 首次通关（账号终身一次）
///   · `level`        `min_level_no` ···· 单局通关至第 N 关（match3 用全局关序）
///   · `score`        `dimension` + (`gte`|`lte`) + 可选 `mode` ·· 单局某维度达到/不超过阈值
///   · `mode_tier`    `game`+`mode`+`tier`+`threshold{}` ········ 模式段位徽章
///   · `cumulative`   `metric` + `value` ······················· 终身累计
///
/// `dimension`（引擎结算上报值，见各 onFinished）：
///   · match3: score / duration_ms / moves / max_combo / max_single /
///             cleared_blocks / jelly_cleared / collect_done(收集·破冰完成数)
///   · g2048 : score / duration_ms / moves / merges
///   · sheep : duration_ms / mistakes / layers(本关层数)
///   · 全局注入: streak_days（连续签到天数，结算时由 App 补齐）
///
/// `metric`（cumulative）：play / clear / merge / clear_blocks

/// 成就/规则达成档位挑选器（纯函数，无状态、无 IO）。
///
/// 解决「里程碑分档被循环发放」问题：后台把关卡/得分里程碑按阈值切成 10 档
/// （如 min_level_no = 10/30/50/…/300，奖励 1..10 分），若沿用「所有满足
/// 阈值的记录都发奖」的朴素遍历，通关第 300 关会一次性命中全部 10 档
/// （1+2+…+10 = 55 分）；得分 131072 同理。成就奖励还 bypassDailyLimit
/// 不受单日上限约束，属于可无限放大的重复发放漏洞。
///
/// 需求口径（单局结算语义）：
///   - 单局只能拿到**本局对应档位**的那一条，即所有满足 `阈值 <= 本局取值`
///     的档位中阈值**最大**的一条；
///   - 低于本局档位的记录属于「非本局区间」，本局不计算、不发奖；
///   - 「首次通关」类成就为账号终身唯一，可叠加（全局 + 单游戏），已领取由
///     claim_key 唯一索引幂等拦截，不二次计算发放；
///   - 已领取的历史档位同样由唯一索引幂等拦截（回头补打低关不会重发高档）。
///
/// 因此单局最多产生：N 条 first_clear（仅首次）+ 1 条关卡里程碑
/// + 1 条得分里程碑 + 1 条成绩区间规则。

/// 读取成就条件类型，缺省视为 first_clear。
String achievementTypeOf(GameAchievementModel ach) =>
    ach.condition['type']?.toString() ?? kAchievementTypeFirstClear;

/// 判断成绩区间规则是否达成。
///
/// condition 形如 `{'dimension':'score','gte':1000,'lte':9999}`；
/// `gte` 缺失视为不通配（返回 false），`lte` 缺失视为无上界。
bool meetsScoreRange(
  GameRewardRuleModel rule,
  Map<String, num> values,
) {
  final cond = rule.condition;
  final dim = cond['dimension']?.toString();
  if (dim == null) return false;
  final v = values[dim];
  if (v == null) return false;
  final gte = cond['gte'];
  final lte = cond['lte'];
  if (gte is num && v < gte) return false;
  if (lte is num && v > lte) return false;
  return true;
}

/// 挑选本局「成绩区间」规则：所有命中规则中 `gte` 最高的一档（至多 1 条）。
///
/// 返回 null 表示本局成绩未落入任何已配置区间。
GameRewardRuleModel? pickTopScoreRangeRule(
  List<GameRewardRuleModel> rules,
  Map<String, num> values,
) {
  GameRewardRuleModel? best;
  num bestGte = -1;
  for (final rule in rules) {
    if (!meetsScoreRange(rule, values)) continue;
    final gte = rule.condition['gte'];
    final threshold = gte is num ? gte : 0;
    if (threshold > bestGte) {
      bestGte = threshold;
      best = rule;
    }
  }
  return best;
}

/// 挑选本局「关卡里程碑」成就：满足 `min_level_no <= [levelNo]` 的最高档（至多 1 条）。
///
/// [levelNo] 需传**折算后的全局关序**（match3 由 `game_reward_service` 的
/// _match3GlobalLevelIndex 按后台配置动态推导），与后台 min_level_no 同一口径。
GameAchievementModel? pickTopLevelAchievement(
  List<GameAchievementModel> achievements,
  int levelNo,
) {
  GameAchievementModel? best;
  num bestThreshold = -1;
  for (final ach in achievements) {
    if (achievementTypeOf(ach) != kAchievementTypeLevel) continue;
    final minLevel = ach.condition['min_level_no'];
    if (minLevel is! num) continue;
    if (minLevel > levelNo) continue;
    if (minLevel > bestThreshold) {
      bestThreshold = minLevel;
      best = ach;
    }
  }
  return best;
}

/// 挑选本局「得分里程碑」成就：**按维度分桶**，每个维度满足 `gte <= 本局取值`
/// 的最高档各一条（至多 1 条/维度）。
///
/// condition 形如 `{'type':'score','dimension':'score','gte':2048}`；
/// 可选 `'mode':'timed'` → **仅在该模式内判定**（无 mode 键 = 全模式通用）；
/// [values] 中无对应维度取值时该成就不参与挑选。
///
/// [modeCode]：本局实际模式编码。为 null（模式解析失败）时，**带 mode 限定的
/// 成就一律跳过**——宁可不解锁，也不能把「限时模式 4096 分」发到经典模式头上。
///
/// 为什么按维度分桶：score 维度族（单局得分/用时/步数/连击）是互不相关的
/// 单局里程碑，此前全局只取 rank 最高一条，会让低 rank 维度（速通/连击）
/// 被高 rank 的得分档永久遮蔽、终身无法解锁。
List<GameAchievementModel> pickTopScoreAchievements(
  List<GameAchievementModel> achievements,
  Map<String, num> values, {
  String? modeCode,
}) {
  final bestByDim = <String, GameAchievementModel>{};
  final bestRankByDim = <String, num>{};
  for (final ach in achievements) {
    if (achievementTypeOf(ach) != kAchievementTypeScore) continue;
    final dim = ach.condition['dimension']?.toString();
    if (dim == null) continue;
    final condMode = ach.condition['mode']?.toString();
    if (condMode != null && condMode != modeCode) continue;
    final gte = ach.condition['gte'];
    final lte = ach.condition['lte'];
    if (gte is! num && lte is! num) continue;
    final v = values[dim];
    if (v == null) continue;
    if (gte is num && v < gte) continue;
    if (lte is num && v > lte) continue;
    // 分桶键必须带上模式：同维度可同时存在「全模式通用」与「仅限某模式」两族
    // （如 score 通用档 + 破冰模式专用档），否则后一档会被前一族遮蔽。
    final bucket = condMode == null ? dim : '$dim@$condMode';
    final rank = gte is num ? gte : -(lte as num);
    if (rank > (bestRankByDim[bucket] ?? -double.maxFinite)) {
      bestRankByDim[bucket] = rank;
      bestByDim[bucket] = ach;
    }
  }
  return bestByDim.values.toList();
}

/// 挑选本局达成的「模式段位」最高档（v2 徽章化，至多 1 条）。
///
/// condition 形如 `{'type':'mode_tier','game':'g2048','mode':'classic','tier':1,
/// 'threshold':{'score':5145}}`（sheep 用 `{'level':14}`）。threshold 全部键
/// 在 [values] 中达标（`值 >= 阈值`）才算达成；返回 tier 最大的一条。
/// [modeCode] 为空时不按模式过滤（用于无法确定模式的数据兜底，正常不会发生）。
GameAchievementModel? pickTopModeTierAchievement(
  List<GameAchievementModel> achievements, {
  required String gameCode,
  String? modeCode,
  required Map<String, num> values,
}) {
  GameAchievementModel? best;
  num bestTier = -1;
  for (final ach in achievements) {
    if (achievementTypeOf(ach) != kAchievementTypeModeTier) continue;
    if (ach.condition['game']?.toString() != gameCode) continue;
    if (modeCode != null &&
        ach.condition['mode']?.toString() != modeCode) {
      continue;
    }
    final threshold = ach.condition['threshold'];
    if (threshold is! Map) continue;
    var ok = true;
    threshold.forEach((key, value) {
      final val = values[key.toString()];
      if (val == null || (value is num && val < value)) ok = false;
    });
    if (!ok) continue;
    final tier = ach.condition['tier'];
    final t = tier is num ? tier : 0;
    if (t > bestTier) {
      bestTier = t;
      best = ach;
    }
  }
  return best;
}

/// 挑选达标的「终身累计」成就：返回**全部**满足 `value <= 累计总量` 的档位。
///
/// condition 形如 `{'type':'cumulative','metric':'clear_blocks','value':8000}`；
/// [totals] 为 `metric → 终身累计值`（GameCumulativeService 提供）。
///
/// 为什么返回全部档位（与 level/score 的「本局最高档」不同）：累计指标是
/// 终身单调进度，单局可能一次跨越多档（如一局消除 9000 方块从 0 跨过
/// 2000/5000/8000），只发最高档会永久漏发中间档；未达标档由 claim_key
/// 幂等拦截，不会重复发放。
List<GameAchievementModel> pickCumulativeAchievements(
  List<GameAchievementModel> achievements,
  Map<String, int> totals,
) {
  final met = <GameAchievementModel>[];
  for (final ach in achievements) {
    if (achievementTypeOf(ach) != kAchievementTypeCumulative) continue;
    final metric = ach.condition['metric']?.toString();
    if (metric == null) continue;
    final value = ach.condition['value'];
    if (value is! num) continue;
    final total = totals[metric];
    if (total == null) continue;
    if (total >= value) met.add(ach);
  }
  return met;
}
