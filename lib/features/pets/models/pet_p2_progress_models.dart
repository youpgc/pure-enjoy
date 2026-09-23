import '../../../constants/pet.dart';
import 'pet_p2_models.dart';

/// 宠物 P2 成就与周任务模型
///
/// 字段与 `feature_pet_p2_rpcs_20260923.sql` §6/§7 两个 RPC 的返回键一一对应。
/// 关键口径：成就的 `target` 是**服务端归一后的顶层键**（value → target → 1，
/// 见 `_pet_ach_target`），客户端不得再回读 condition_value 自行推算；
/// 周任务的 quest_id 是 **pet_quests.id**（配置行 id），不是实例行 id。

/// 成就（rpc_pet_achievement_check 的 achievements 数组元素）
class PetAchievementModel {
  const PetAchievementModel({
    required this.id,
    required this.code,
    required this.title,
    required this.tier,
    required this.conditionType,
    required this.target,
    required this.progress,
    required this.completed,
    required this.claimed,
    required this.rewardGold,
    required this.rewardPoints,
    required this.rewardItems,
    this.icon,
    this.conditionValue,
  });

  final String id;
  final String code;
  final String title;
  final String? icon;
  final PetAchTier? tier;
  final PetAchConditionType? conditionType;
  final int target;
  final int progress;
  final bool completed;
  final bool claimed;
  final int rewardGold;
  final int rewardPoints;
  final List<PetRewardItemModel> rewardItems;

  /// 原始条件参数（rarity_owned 需读其 rarity 才能说清条件）
  final Map<String, dynamic> conditionValue;

  bool get claimable => completed && !claimed;

  double get ratio =>
      target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();

  String get conditionLabel {
    final type = conditionType;
    if (type == null) return '成就条件（后台配置项待校准）';
    if (type == PetAchConditionType.rarityOwned) {
      final rarity = conditionValue['rarity'] as String? ?? '';
      return rarity.isEmpty ? type.label : '${type.label} $rarity';
    }
    return type.label;
  }

  factory PetAchievementModel.fromJson(Map<String, dynamic> json) {
    final pkg = json['reward_package'] is Map
        ? Map<String, dynamic>.from(json['reward_package'] as Map)
        : const <String, dynamic>{};
    return PetAchievementModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String?,
      tier: PetAchTier.fromCode(json['tier'] as String?),
      conditionType:
          PetAchConditionType.fromCode(json['condition_type'] as String?),
      target: (json['target'] as num?)?.toInt() ?? 1,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      claimed: json['claimed'] as bool? ?? false,
      rewardGold: (pkg['gold'] as num?)?.toInt() ?? 0,
      rewardPoints: (pkg['points'] as num?)?.toInt() ?? 0,
      rewardItems: PetRewardItemModel.parseList(pkg['items']),
      conditionValue: json['condition_value'] is Map
          ? Map<String, dynamic>.from(json['condition_value'] as Map)
          : const {},
    );
  }
}

/// 成就领取结果（rpc_pet_achievement_claim）
class PetAchClaimResultModel {
  const PetAchClaimResultModel({
    required this.code,
    required this.title,
    required this.gold,
    required this.points,
    required this.items,
  });

  final String code;
  final String title;
  final int gold;
  final int points;
  final List<PetRewardItemModel> items;
}

/// 周任务（rpc_pet_weekly_quests_draw 的 quests 数组元素）
class PetWeeklyQuestModel {
  const PetWeeklyQuestModel({
    required this.questId,
    required this.code,
    required this.difficulty,
    required this.conditionType,
    required this.target,
    required this.progress,
    required this.claimed,
    required this.rewardGold,
    required this.rewardPoints,
    required this.rewardItems,
  });

  final String questId;
  final String code;
  final PetQuestDifficulty? difficulty;
  final PetQuestConditionType? conditionType;
  final int target;
  final int progress;
  final bool claimed;
  final int rewardGold;
  final int rewardPoints;
  final List<PetRewardItemModel> rewardItems;

  bool get done => progress >= target;
  bool get claimable => done && !claimed;

  String get difficultyLabel => difficulty?.label ?? '普通';
  String get conditionLabel => conditionType?.label ?? '本周任务';

  factory PetWeeklyQuestModel.fromJson(Map<String, dynamic> json) {
    final cond = json['condition'] is Map
        ? Map<String, dynamic>.from(json['condition'] as Map)
        : const <String, dynamic>{};
    final rw = json['rewards'] is Map
        ? Map<String, dynamic>.from(json['rewards'] as Map)
        : const <String, dynamic>{};
    return PetWeeklyQuestModel(
      questId: json['quest_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      difficulty: PetQuestDifficulty.fromCode(json['difficulty'] as String?),
      conditionType: PetQuestConditionType.fromCode(cond['type'] as String?),
      target: (json['target'] as num?)?.toInt() ?? 1,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      claimed: json['reward_claimed'] as bool? ?? false,
      rewardGold: (rw['gold'] as num?)?.toInt() ?? 0,
      rewardPoints: (rw['points'] as num?)?.toInt() ?? 0,
      rewardItems: PetRewardItemModel.parseList(rw['items']),
    );
  }
}

/// 周任务领取结果（rpc_pet_weekly_quests_claim）
class PetWeeklyClaimResultModel {
  const PetWeeklyClaimResultModel({
    required this.gold,
    required this.points,
    required this.items,
  });

  final int gold;
  final int points;
  final List<PetRewardItemModel> items;
}
