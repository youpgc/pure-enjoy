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
    this.stackLimit,
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

  /// 单格堆叠上限：`pet_items.stack_limit` 为准，缺列时取后台
  /// `pet_config.stack_limit_default`；两者皆无 → null（UI 不展示上限，不猜默认值）
  final int? stackLimit;

  /// 道具效果类型（feed/clean/toy/rescue/...）
  String get effectType => effect['type'] as String? ?? '';

  bool get isEgg => category == PetBagCategory.egg.code;

  /// 是否已堆满（蛋按格占位、stack_limit=1，不参与满堆角标）
  bool get isStackFull =>
      !isEgg && stackLimit != null && quantity >= stackLimit!;

  /// 图标资源键（icon/<key> → key），非该格式原样返回，null 表示无图标
  String? get iconKey {
    final v = icon;
    if (v == null || v.isEmpty) return null;
    return v.startsWith('icon/') ? v.substring(5) : v;
  }

  factory PetBagItemModel.fromJson(
    Map<String, dynamic> json, {
    int? stackLimitDefault,
  }) {
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
      stackLimit: (item['stack_limit'] as num?)?.toInt() ?? stackLimitDefault,
    );
  }
}

/// 蛋实例（pet_eggs join pet_items；unopened / waiting / ready 三态）
///
/// 值域见 [PetEggStatus]：instant 蛋走 `rpc_pet_hatch_instant` 直接出宠；
/// wait 蛋须先 `rpc_pet_hatch_wait` 进入 waiting，到点变 ready 后再走
/// `rpc_pet_hatch_instant` 领取（服务端闸门 PET_EGG_NOT_READY）。
class PetEggModel {
  const PetEggModel({
    required this.id,
    required this.poolCode,
    required this.mode,
    required this.itemName,
    required this.status,
    this.bagItemId,
    this.readyAt,
  });

  final String id;
  final String poolCode;
  final String mode; // instant / wait
  final String itemName;

  /// pet_eggs.status（unopened / waiting / ready）
  final PetEggStatus? status;

  /// 对应背包行 id（孵化后该行删除；背包内精确匹配用）
  final String? bagItemId;

  /// 等待孵化到点时间（仅 waiting/ready 有值）
  final DateTime? readyAt;

  bool get isInstant => mode == PetEggMode.instant.code;

  bool get isWaiting => status == PetEggStatus.waiting;

  /// 可领取（wait 蛋倒计时归零，服务端已置 ready）
  bool get isReady => status == PetEggStatus.ready;

  /// 尚未开始孵化（unopened）——wait 模式此时需先发起计时
  bool get isUnopened => status != PetEggStatus.waiting && !isReady;

  /// 剩余等待时长（到点前逐秒刷新用；无到点时间返回 null）
  Duration? get remaining {
    final at = readyAt;
    if (at == null || !isWaiting) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  factory PetEggModel.fromJson(Map<String, dynamic> json) {
    final item = (json['item'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PetEggModel(
      id: json['id'] as String? ?? '',
      poolCode: json['pool_code'] as String? ?? '',
      mode: json['mode'] as String? ?? PetEggMode.instant.code,
      itemName: item['name'] as String? ?? '神秘蛋',
      status: PetEggStatus.fromCode(json['status'] as String?),
      bagItemId: json['bag_item_id'] as String?,
      readyAt: DateTime.tryParse(json['ready_at'] as String? ?? ''),
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
    this.attrRequirements = const [],
  });

  final String id;
  final String code;
  final String name;

  /// [{type:level,value:N}]（服务端 rpc_pet_adventure_start 亦校验）
  final List<Map<String, dynamic>> unlockConditions;

  /// [{attr,value}] 结算判据：不达标仍可出发，claim 时判 failed 并执行惩罚
  /// （feature_pet_attributes_20260917.sql rpc_pet_adventure_start / claim）
  final List<Map<String, dynamic>> attrRequirements;

  int? get requiredLevel {
    for (final c in unlockConditions) {
      if (c['type'] == 'level') return (c['value'] as num?)?.toInt();
    }
    return null;
  }

  factory PetSpotModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapList(dynamic raw) => raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
    return PetSpotModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unlockConditions: mapList(json['unlock_conditions']),
      attrRequirements: mapList(json['attr_requirements']),
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

  /// 分类页签归属：食物 / 清洁 / 玩具 / 救援 / 扩容（P1）+
  /// 宠物蛋 / 进化 / 加速 / 洗练 / 解锁（P2）
  ///
  /// 键域 = `pet_items.sub_type`（无 DDL CHECK，取值见种子
  /// `feature_pet_p2_seed_20260923.sql` §2）；未列出的 sub_type 归「其他」。
  String get categoryLabel {
    if (isExpansion) return '扩容';
    return switch (subType) {
      'food' => '食物',
      'clean' => '清洁',
      'toy' => '玩具',
      'rescue' => '救援',
      'random' => '宠物蛋',
      'evolution' => '进化',
      'accelerate' => '加速',
      'trait_wash' => '洗练',
      'unlock' => '解锁',
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
