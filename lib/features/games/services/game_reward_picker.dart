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

/// 挑选本局「得分里程碑」成就：满足 `gte <= 本局取值` 的最高档（至多 1 条）。
///
/// condition 形如 `{'type':'score','dimension':'score','gte':2048}`；
/// [values] 中无对应维度取值时该成就不参与挑选。
GameAchievementModel? pickTopScoreAchievement(
  List<GameAchievementModel> achievements,
  Map<String, num> values,
) {
  GameAchievementModel? best;
  num bestRank = -double.maxFinite.toInt();
  for (final ach in achievements) {
    if (achievementTypeOf(ach) != kAchievementTypeScore) continue;
    final dim = ach.condition['dimension']?.toString();
    if (dim == null) continue;
    final gte = ach.condition['gte'];
    final lte = ach.condition['lte'];
    if (gte is! num && lte is! num) continue;
    final v = values[dim];
    if (v == null) continue;
    if (gte is num && v < gte) continue;
    if (lte is num && v > lte) continue;
    final rank = gte is num ? gte : -(lte as num);
    if (rank > bestRank) {
      bestRank = rank;
      best = ach;
    }
  }
  return best;
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
