import '../../../constants/pet.dart';

/// 宠物业务模型（背包/蛋/任务/历险地/商城）
///
/// 字段与 PostgREST 查询 select 一一对应（见 PetRpc 各 fetch），禁止臆测。

/// 背包条目（pet_bag_items join pet_items）
class PetBagItemModel {
  const PetBagItemModel({
    required this.id,
    required this.quantity,
    required this.slotIndex,
    required this.itemId,
    required this.itemCode,
    required this.name,
    required this.category,
    this.subType,
    this.icon,
    this.effect = const {},
    this.stackLimit = 99,
  });

  final String id;
  final int quantity;
  final int slotIndex;
  final String itemId;
  final String itemCode;
  final String name;
  final String category; // egg / consumable / tool
  final String? subType; // food/clean/toy/rescue...
  final String? icon; // pet_items.icon，形如 icon/<key>
  final Map<String, dynamic> effect;
  final int stackLimit;

  /// 道具效果类型（feed/clean/toy/rescue/...）
  String get effectType => effect['type'] as String? ?? '';

  bool get isEgg => category == 'egg';

  /// 图标资源键（icon/<key> → key），非该格式原样返回，null 表示无图标
  String? get iconKey {
    final v = icon;
    if (v == null || v.isEmpty) return null;
    return v.startsWith('icon/') ? v.substring(5) : v;
  }

  factory PetBagItemModel.fromJson(Map<String, dynamic> json) {
    final item = (json['item'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PetBagItemModel(
      id: json['id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      itemId: item['id'] as String? ?? '',
      itemCode: item['item_code'] as String? ?? '',
      name: item['name'] as String? ?? '',
      category: item['category'] as String? ?? '',
      subType: item['sub_type'] as String?,
      icon: item['icon'] as String?,
      effect: item['effect'] is Map
          ? Map<String, dynamic>.from(item['effect'] as Map)
          : const {},
      stackLimit: (item['stack_limit'] as num?)?.toInt() ?? 99,
    );
  }
}

/// 蛋实例（pet_eggs join pet_items，仅未打开）
class PetEggModel {
  const PetEggModel({
    required this.id,
    required this.poolCode,
    required this.mode,
    required this.itemName,
    this.bagItemId,
  });

  final String id;
  final String poolCode;
  final String mode; // instant / wait
  final String itemName;

  /// 对应背包行 id（孵化后该行删除；背包内精确匹配用）
  final String? bagItemId;

  bool get isInstant => mode == 'instant';

  factory PetEggModel.fromJson(Map<String, dynamic> json) {
    final item = (json['item'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PetEggModel(
      id: json['id'] as String? ?? '',
      poolCode: json['pool_code'] as String? ?? '',
      mode: json['mode'] as String? ?? 'instant',
      itemName: item['name'] as String? ?? '神秘蛋',
      bagItemId: json['bag_item_id'] as String?,
    );
  }
}

/// 当日任务（pet_daily_quests join pet_quests）
class PetQuestModel {
  const PetQuestModel({
    required this.questId,
    required this.conditionType,
    required this.target,
    required this.progress,
    required this.claimed,
    this.rewardGold = 0,
    this.rewardPoints = 0,
  });

  final String questId;
  final String conditionType; // feed / interact / hatch / adventure
  final int target;
  final int progress;
  final bool claimed;
  final int rewardGold;
  final int rewardPoints;

  bool get done => progress >= target;

  /// 展示名（pet_quests 无 title 列，按条件类型生成）
  String get title => switch (conditionType) {
        'feed' => '喂养伙伴',
        'interact' => '互动陪伴',
        'hatch' => '孵化新星',
        'adventure' => '外出历险',
        _ => '日常任务',
      };

  factory PetQuestModel.fromJson(Map<String, dynamic> json) {
    final quest = (json['quest'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cond = quest['condition'] is Map
        ? Map<String, dynamic>.from(quest['condition'] as Map)
        : const <String, dynamic>{};
    final rw = quest['rewards'] is Map
        ? Map<String, dynamic>.from(quest['rewards'] as Map)
        : const <String, dynamic>{};
    return PetQuestModel(
      questId: quest['id'] as String? ?? '',
      conditionType: cond['type'] as String? ?? '',
      target: (json['target'] as num?)?.toInt() ?? 1,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      claimed: json['reward_claimed'] as bool? ?? false,
      rewardGold: (rw['gold'] as num?)?.toInt() ?? 0,
      rewardPoints: (rw['points'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 历险地（pet_adventure_spots，仅启用行）
class PetSpotModel {
  const PetSpotModel({
    required this.id,
    required this.code,
    required this.name,
    this.unlockConditions = const [],
  });

  final String id;
  final String code;
  final String name;

  /// [{type:level,value:N}]（服务端 rpc_pet_adventure_start 亦校验）
  final List<Map<String, dynamic>> unlockConditions;

  int? get requiredLevel {
    for (final c in unlockConditions) {
      if (c['type'] == 'level') return (c['value'] as num?)?.toInt();
    }
    return null;
  }

  factory PetSpotModel.fromJson(Map<String, dynamic> json) {
    final raw = json['unlock_conditions'];
    return PetSpotModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unlockConditions: raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [],
    );
  }
}

/// 商城道具（pet_items 在售行）
class PetShopItemModel {
  const PetShopItemModel({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.category,
    required this.priceCoin,
    this.subType,
    this.icon,
    this.pricePoints,
    this.pointsPurchasable = false,
    this.ladderKey,
    this.description,
  });

  final String id;
  final String itemCode;
  final String name;
  final String category;
  final String? subType; // food/clean/toy/rescue/expand...
  final String? icon; // pet_items.icon，形如 icon/<key>
  final int priceCoin;
  final int? pricePoints;
  final bool pointsPurchasable;
  final String? ladderKey; // 扩容阶梯道具（购买即生效）
  final String? description;

  /// 图标资源键（icon/<key> → key），非该格式原样返回，null 表示无图标
  String? get iconKey {
    final v = icon;
    if (v == null || v.isEmpty) return null;
    return v.startsWith('icon/') ? v.substring(5) : v;
  }

  bool get isExpansion => ladderKey != null;

  /// 分类页签归属：食物 / 清洁 / 玩具 / 救援 / 扩容
  String get categoryLabel {
    if (isExpansion) return '扩容';
    return switch (subType) {
      'food' => '食物',
      'clean' => '清洁',
      'toy' => '玩具',
      'rescue' => '救援',
      _ => '其他',
    };
  }

  factory PetShopItemModel.fromJson(Map<String, dynamic> json) {
    return PetShopItemModel(
      id: json['id'] as String? ?? '',
      itemCode: json['item_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subType: json['sub_type'] as String?,
      icon: json['icon'] as String?,
      priceCoin: (json['price_coin'] as num?)?.toInt() ?? 0,
      pricePoints: (json['price_points'] as num?)?.toInt(),
      pointsPurchasable: json['points_purchasable'] as bool? ?? false,
      ladderKey: json['ladder_key'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// 孵化结果（rpc_pet_hatch_instant 返回）
class PetHatchResultModel {
  const PetHatchResultModel({
    required this.petId,
    required this.showNo,
    required this.speciesCode,
    required this.name,
    required this.rarity,
    this.gender,
  });

  final String petId;
  final String showNo;
  final String speciesCode;
  final String name;
  final String rarity;
  final PetGender? gender;

  factory PetHatchResultModel.fromJson(Map<String, dynamic> json) {
    return PetHatchResultModel(
      petId: json['pet_id'] as String? ?? '',
      showNo: json['show_no'] as String? ?? '',
      speciesCode: json['species_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rarity: json['rarity'] as String? ?? '',
      gender: PetGender.fromCode(json['gender'] as String?),
    );
  }
}
