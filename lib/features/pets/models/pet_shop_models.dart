import '../../../constants/pet.dart';

/// 宠物商城域模型（在售道具 / 孵化结果 / 腾位选项 / 购买结果）
///
/// 字段与 PostgREST 查询 select 一一对应（见 PetRpc 各 fetch），禁止臆测。
/// 自 pet_rpc_models 按域拆出（500 行硬底线），经 pet_rpc_models export
/// 门面转发——既有 import pet_rpc_models.dart 的调用方零改动。

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
    this.ladderStep,
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

  /// 阶梯步号（扩容道具专用；商城「只展示当前可购档」过滤依据，
  /// summary/shop items 2026-10-21 起下发）
  final int? ladderStep;
  final String? description;

  /// 图标资源键（icon/<key> → key），非该格式原样返回，null 表示无图标
  String? get iconKey {
    final v = icon;
    if (v == null || v.isEmpty) return null;
    return v.startsWith('icon/') ? v.substring(5) : v;
  }

  bool get isExpansion => ladderKey != null;

  /// 商城分类栏的**全部**分类（左侧栏按此顺序出项）。
  ///
  /// 与 [categoryLabel] 的返回值一一对应，**新增分类必须两处同补**（同文件相邻
  /// 位置），否则会出现点了没有商品的分类、或有商品却进不去任何分类。
  static const List<String> categoryLabels = [
    '宠物蛋',
    '消耗品',
    '扩容',
    '进化',
    '加速',
    '洗练',
    '解锁',
    '其他',
  ];

  /// 分类页签归属：消耗品（食物/医疗/清洁/玩具/救援合并展示，2026-11-03）+
  /// 扩容 + 宠物蛋 / 进化 / 加速 / 洗练 / 解锁
  ///
  /// 键域 = `pet_items.sub_type`（无 DDL CHECK，取值见种子
  /// `feature_pet_p2_seed_20260923.sql` §2）；未列出的 sub_type 归「其他」。
  /// refine 与 trait_wash 同归洗练；exp_double 与孵化加速同归加速。
  String get categoryLabel {
    if (isExpansion) return '扩容';
    return switch (subType) {
      'food' ||
      'heal' ||
      'clean' ||
      'toy' ||
      'rescue' =>
        '消耗品',
      'random' => '宠物蛋',
      'evolution' => '进化',
      'accelerate' => '加速',
      'exp_double' => '加速',
      'trait_wash' => '洗练',
      'refine' => '洗练',
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
      ladderStep: (json['ladder_step'] as num?)?.toInt(),
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

/// 商城满格腾位选项（rpc_pet_shop_buy 返回 status='bag_full' 时的 next_expand；
/// null = 已达扩容上限、无可购的下一级）
class PetBagFullExpandModel {
  const PetBagFullExpandModel({
    required this.itemId,
    required this.itemCode,
    required this.name,
    required this.priceCoin,
  });

  final String itemId;
  final String itemCode;
  final String name;
  final int priceCoin;

  factory PetBagFullExpandModel.fromJson(Map<String, dynamic> json) {
    return PetBagFullExpandModel(
      itemId: json['item_id'] as String? ?? '',
      itemCode: json['item_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceCoin: (json['price_coin'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 商城购买结果（rpc_pet_shop_buy）
///
/// - status='ok'：已扣款入包；
/// - status='bag_full'：容量预检未过、**未扣款**，携带腾位所需信息——按需求
///   §5.4 走腾位流程（有下一级扩容 → 引导购买后重试；无 → 引导清理背包）。
///   此前服务层仅透传 'bag_full' 字符串、丢弃腾位载荷，决策链在服务层断链
///   （审计批 20261012 修复）。
class PetShopBuyResultModel {
  const PetShopBuyResultModel({
    required this.status,
    this.capacity,
    this.used,
    this.rowsNeeded,
    this.nextExpand,
  });

  final String status; // 'ok' | 'bag_full'
  final int? capacity;
  final int? used;
  final int? rowsNeeded;
  final PetBagFullExpandModel? nextExpand;

  bool get isBagFull => status == 'bag_full';

  factory PetShopBuyResultModel.fromJson(Map<String, dynamic> json) {
    final expand = json['next_expand'];
    return PetShopBuyResultModel(
      status: json['status'] as String? ?? 'ok',
      capacity: (json['capacity'] as num?)?.toInt(),
      used: (json['used'] as num?)?.toInt(),
      rowsNeeded: (json['rows_needed'] as num?)?.toInt(),
      nextExpand: expand is Map
          ? PetBagFullExpandModel.fromJson(
              Map<String, dynamic>.from(expand))
          : null,
    );
  }
}
