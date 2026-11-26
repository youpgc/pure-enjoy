/// revived 条件复用的成就编码（首次还魂），与 game_achievements 种子一致。
const String kJourneyReviveAchievementCode = 'journey_revive_first';

/// 统一解锁规则（journey_unlock_entries 行）：一行一「目标 × 条件 × 定价」。
/// target_kind：ability（妖王能力，仅展示）、slot（武器维度槽）、
/// weapon（特效法宝）、passive（被动法宝）。
/// condition_value 为文本：achievement 存成就编码、boss_killed 存妖王编码，
/// 其他条件存数值字符串；none 表示纯功德直购。
class JourneyUnlockEntryModel {
  final String code;
  final String targetKind;
  final String targetCode;
  final String conditionType;
  final String conditionValue;
  final int meritCost;
  final bool enabled;
  final String remark;

  const JourneyUnlockEntryModel({
    required this.code,
    required this.targetKind,
    required this.targetCode,
    required this.conditionType,
    this.conditionValue = '',
    this.meritCost = 0,
    this.enabled = true,
    this.remark = '',
  });

  factory JourneyUnlockEntryModel.fromJson(Map<String, dynamic> json) {
    return JourneyUnlockEntryModel(
      code: json['code'] as String? ?? '',
      targetKind: json['target_kind'] as String? ?? '',
      targetCode: json['target_code'] as String? ?? '',
      conditionType: json['condition_type'] as String? ?? 'none',
      conditionValue: json['condition_value'] as String? ?? '',
      meritCost: (json['merit_cost'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      remark: json['remark'] as String? ?? '',
    );
  }

  /// 统一条目键：目标类型 + 目标编码，与进度行 unlocked_entries 同格式。
  String get entryKey => '$targetKind:$targetCode';
}

/// 条件判定所需的进度快照；bossKills 为妖王码 → 击杀数。
class JourneyUnlockConditionContext {
  final int farthestLevelNo;
  final int totalKills;
  final int totalMeritEarned;
  final Set<String> unlockedAchievements;
  final Map<String, int> bossKills;

  const JourneyUnlockConditionContext({
    this.farthestLevelNo = 0,
    this.totalKills = 0,
    this.totalMeritEarned = 0,
    this.unlockedAchievements = const <String>{},
    this.bossKills = const <String, int>{},
  });
}

/// 数值阈值必须是正整数；配错时条件不成立，避免误判达成。
int? _positiveThreshold(String raw) {
  final value = int.tryParse(raw.trim());
  return value != null && value > 0 ? value : null;
}

/// 解锁条件统一判定：扣费服务与图鉴展示共用，避免两端口径漂移。
bool journeyUnlockConditionMet(
  JourneyUnlockEntryModel entry,
  JourneyUnlockConditionContext ctx,
) {
  switch (entry.conditionType) {
    case 'none':
      return true;
    case 'level_cleared':
      final threshold = _positiveThreshold(entry.conditionValue);
      return threshold != null && ctx.farthestLevelNo >= threshold;
    case 'total_kills':
      final threshold = _positiveThreshold(entry.conditionValue);
      return threshold != null && ctx.totalKills >= threshold;
    case 'merit_earned':
      final threshold = _positiveThreshold(entry.conditionValue);
      return threshold != null && ctx.totalMeritEarned >= threshold;
    case 'achievement':
      return entry.conditionValue.isNotEmpty &&
          ctx.unlockedAchievements.contains(entry.conditionValue);
    case 'revived':
      return ctx.unlockedAchievements.contains(kJourneyReviveAchievementCode);
    case 'boss_killed':
      return (ctx.bossKills[entry.conditionValue] ?? 0) > 0;
    default:
      return false;
  }
}
