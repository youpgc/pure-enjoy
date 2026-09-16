import '../../../constants/pet.dart';

/// 宠物系统模型层
///
/// 数据源：`rpc_pet_summary()`（jsonb 单对象，经 ApiResponse.raw 承载）。
/// 字段与 D:\workspace\sql\feature_pet_rpcs_20260916.sql 中
/// rpc_pet_summary 的 jsonb_build_object 返回结构一一对应，禁止臆测字段。

/// 金币钱包概要
class PetWalletModel {
  const PetWalletModel({
    required this.goldBalance,
    required this.totalEarned,
    required this.totalSpent,
  });

  final int goldBalance;
  final int totalEarned;
  final int totalSpent;

  factory PetWalletModel.fromJson(Map<String, dynamic> json) {
    return PetWalletModel(
      goldBalance: (json['gold_balance'] as num?)?.toInt() ?? 0,
      totalEarned: (json['total_earned'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 三套容量概要（背包 / 养育格 / 寄养格）
class PetCapacitiesModel {
  const PetCapacitiesModel({
    required this.backpack,
    required this.rearing,
    required this.foster,
  });

  final int backpack;
  final int rearing;
  final int foster;

  factory PetCapacitiesModel.fromJson(Map<String, dynamic> json) {
    return PetCapacitiesModel(
      backpack: (json['backpack'] as num?)?.toInt() ?? 0,
      rearing: (json['rearing'] as num?)?.toInt() ?? 0,
      foster: (json['foster'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 宠物个体简要信息（列表/状态卡展示用）
class PetBriefModel {
  const PetBriefModel({
    required this.id,
    required this.showNo,
    required this.name,
    required this.speciesCode,
    required this.family,
    required this.rarity,
    required this.stage,
    required this.gender,
    required this.level,
    required this.exp,
    required this.hunger,
    required this.mood,
    required this.intimacy,
    required this.status,
    this.render3d,
    this.render2d,
  });

  final String id;
  final String showNo;
  final String name;
  final String speciesCode;
  final String family;
  final String rarity;
  final int stage;
  final PetGender? gender;
  final int level;
  final int exp;
  final int hunger;
  final int mood;
  final int intimacy;
  final PetPetStatus? status;

  /// 种属渲染配置块（pet_species.render3d / render2d，B3 渲染层消费）
  final Map<String, dynamic>? render3d;
  final Map<String, dynamic>? render2d;

  factory PetBriefModel.fromJson(Map<String, dynamic> json) {
    return PetBriefModel(
      id: json['id'] as String? ?? '',
      showNo: json['show_no'] as String? ?? '',
      name: json['name'] as String? ?? '',
      speciesCode: json['species_code'] as String? ?? '',
      family: json['family'] as String? ?? '',
      rarity: json['rarity'] as String? ?? '',
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      gender: PetGender.fromCode(json['gender'] as String?),
      level: (json['level'] as num?)?.toInt() ?? 0,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      hunger: (json['hunger'] as num?)?.toInt() ?? 0,
      mood: (json['mood'] as num?)?.toInt() ?? 0,
      intimacy: (json['intimacy'] as num?)?.toInt() ?? 0,
      status: PetPetStatus.fromCode(json['status'] as String?),
      render3d: json['render3d'] is Map
          ? Map<String, dynamic>.from(json['render3d'] as Map)
          : null,
      render2d: json['render2d'] is Map
          ? Map<String, dynamic>.from(json['render2d'] as Map)
          : null,
    );
  }
}

/// 进行中历险概要（状态卡/主页提醒用）
class PetAdventureBriefModel {
  const PetAdventureBriefModel({
    required this.id,
    required this.petId,
    required this.spotId,
    required this.tier,
    required this.endAt,
    required this.status,
    this.rescueDeadline,
  });

  final String id;
  final String petId;
  final String spotId;
  final int tier;
  final DateTime? endAt;
  final String status;
  final DateTime? rescueDeadline;

  factory PetAdventureBriefModel.fromJson(Map<String, dynamic> json) {
    return PetAdventureBriefModel(
      id: json['id'] as String? ?? '',
      petId: json['pet_id'] as String? ?? '',
      spotId: json['spot_id'] as String? ?? '',
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      endAt: DateTime.tryParse(json['end_at'] as String? ?? ''),
      status: json['status'] as String? ?? '',
      rescueDeadline:
          DateTime.tryParse(json['rescue_deadline'] as String? ?? ''),
    );
  }
}

/// 宠物系统总览（rpc_pet_summary 返回的完整结构）
class PetSummaryModel {
  const PetSummaryModel({
    required this.petEnabled,
    required this.wallet,
    this.capacities,
    required this.bagUsed,
    required this.pets,
    required this.eggsReadyInstant,
    this.ongoingAdventure,
    this.config = const {},
  });

  /// 宠物系统总开关（pet_config.pet_enabled，关闭时三处入口全部隐藏）
  final bool petEnabled;
  final PetWalletModel wallet;
  final PetCapacitiesModel? capacities;
  final int bagUsed;
  final List<PetBriefModel> pets;

  /// 可即开孵化的蛋数量（status='unopened' 且 mode='instant'）
  final int eggsReadyInstant;
  final PetAdventureBriefModel? ongoingAdventure;

  /// 全局配置块（free_feed_daily / points_per_gold 等，B3+ 按需消费；数值零硬编码）
  final Map<String, dynamic> config;

  /// 养育中的第一只宠物（状态卡主展示对象；单只上限内通常即唯一）
  PetBriefModel? get primaryPet {
    for (final p in pets) {
      if (p.status == PetPetStatus.rearing) return p;
    }
    return pets.isEmpty ? null : pets.first;
  }

  factory PetSummaryModel.fromJson(Map<String, dynamic> json) {
    final configJson = json['config'];
    final petsRaw = json['pets'];
    final advRaw = json['ongoing_adventure'];
    final capRaw = json['capacities'];
    return PetSummaryModel(
      petEnabled: json['pet_enabled'] as bool? ?? false,
      wallet: PetWalletModel.fromJson(
        (json['wallet'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      capacities: capRaw is Map
          ? PetCapacitiesModel.fromJson(capRaw.cast<String, dynamic>())
          : null,
      bagUsed: (json['bag_used'] as num?)?.toInt() ?? 0,
      pets: petsRaw is List
          ? petsRaw
              .whereType<Map>()
              .map((e) => PetBriefModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const <PetBriefModel>[],
      eggsReadyInstant: (json['eggs_ready_instant'] as num?)?.toInt() ?? 0,
      ongoingAdventure: advRaw is Map
          ? PetAdventureBriefModel.fromJson(advRaw.cast<String, dynamic>())
          : null,
      config:
          configJson is Map ? Map<String, dynamic>.from(configJson) : const {},
    );
  }
}
