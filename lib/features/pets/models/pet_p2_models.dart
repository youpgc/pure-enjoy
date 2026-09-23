import '../../../constants/pet.dart';

/// 宠物 P2 模型（养成线：进化 / 特性 / 孵化等待 / 功能解锁 / 概率公示）
///
/// 字段与 `feature_pet_p2_rpcs_20260923.sql` 的 RPC 返回键、以及 PetRpcP2 各
/// 直查 select 一一对应，禁止臆测；nullable 一律是服务端真实可空分支
/// （如 trait_id=null 表示这次没掷出特性，属正常结果不是错误）。
/// 繁育见 `pet_p2_breed_models.dart`，成就与周任务见 `pet_p2_progress_models.dart`
/// （三份拆分：合并后超 500 行硬底线）。

/// P2 门槛参数（`pet_config.reserved` 的 hatch / trait / breeding / weekly 四块）
///
/// `rpc_pet_summary` 的 config 快照不含 reserved（热函数未随 P2 改动），
/// UI 要展示门槛时走 [PetRpcP2.fetchReserved] 轻量直查一次。
/// **未配置一律 null**：客户端不写默认值（铁律 2），UI 隐藏该行而不是猜。
class PetReservedModel {
  const PetReservedModel(this.raw);

  final Map<String, dynamic> raw;

  static const _empty = <String, dynamic>{};

  int? _int(String top, String key) =>
      ((raw[top] as Map?) ?? _empty)[key] is num
          ? (((raw[top] as Map?) ?? _empty)[key] as num).toInt()
          : null;

  /// 道具加速缺省分钟数（道具自带 effect.minutes 优先）
  int? get accelMinutes => _int('hatch', 'accel_minutes');

  /// 金币加速花费（0 = 免费立即到点，仍显示按钮）
  int? get accelGold => _int('hatch', 'accel_gold');

  /// 结配亲密度门槛
  int? get breedIntimacyMin => _int('breeding', 'intimacy_min');

  /// 孕期小时数
  int? get breedGestationHours => _int('breeding', 'gestation_hours');

  /// 结配手续费金币（0 = 免费）
  int? get breedFeeGold => _int('breeding', 'fee_gold');

  factory PetReservedModel.fromJson(Map<String, dynamic> json) {
    final r = json['reserved'];
    return PetReservedModel(
        r is Map ? Map<String, dynamic>.from(r) : const {});
  }
}

/// 奖励道具行（reward_package.items / rewards.items = [{code,count}]）
class PetRewardItemModel {
  const PetRewardItemModel({required this.code, required this.count});

  final String code;
  final int count;

  /// 道具展示名（由调用方按 item_code 匹配目录后回填，未命中为 null）
  static List<PetRewardItemModel> parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => PetRewardItemModel(
              code: e['code'] as String? ?? '',
              count: (e['count'] as num?)?.toInt() ?? 1,
            ))
        .where((e) => e.code.isNotEmpty)
        .toList();
  }
}

/// 宠物个体明细（pet_pets 直查，补 rpc_pet_summary 未下发的 species_id / 特性）
///
/// 进化要 species_id（判链）、洗练与特性展示要 trait_*，两者都不在总览里，
/// 故单独直查（RLS：users read own pets）。
class PetPetDetailModel {
  const PetPetDetailModel({
    required this.id,
    required this.showNo,
    required this.speciesId,
    required this.speciesCode,
    required this.name,
    required this.family,
    required this.rarityCode,
    required this.stage,
    required this.level,
    required this.intimacy,
    this.chainId,
    this.traitId,
    this.traitCode,
    this.traitName,
    this.gender,
    this.status,
  });

  final String id;
  final String showNo;
  final String speciesId;

  /// 目标种属（stage>0 时形如 cat_ssr1_s1，用于判「是否已到终阶」）
  final String speciesCode;
  final String name;
  final String family;
  final String rarityCode;
  final int stage;
  final int level;
  final int intimacy;

  /// 所属进化链（种属未挂链 → null，服务端报 PET_EVOLVE_CHAIN_MISSING）
  final String? chainId;
  final String? traitId;
  final String? traitCode;
  final String? traitName;
  final PetGender? gender;
  final PetPetStatus? status;

  bool get rearing => status == null || status == PetPetStatus.rearing;

  /// 展示用：无特性时的占位由 UI 决定，这里只给事实
  String get genderLabel => gender == PetGender.female ? '♀' : '♂';

  factory PetPetDetailModel.fromJson(Map<String, dynamic> json) {
    final sp = (json['species'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tr = (json['trait'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PetPetDetailModel(
      id: json['id'] as String? ?? '',
      showNo: json['show_no'] as String? ?? '',
      speciesId: sp['id'] as String? ?? json['species_id'] as String? ?? '',
      speciesCode: sp['species_code'] as String? ?? '',
      name: sp['name_cn'] as String? ?? '',
      family: sp['family'] as String? ?? '',
      rarityCode: sp['rarity_code'] as String? ?? '',
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      intimacy: (json['intimacy'] as num?)?.toInt() ?? 0,
      chainId: sp['evolution_chain_id'] as String?,
      traitId: json['trait_id'] as String?,
      traitCode: tr['code'] as String?,
      traitName: tr['name'] as String?,
      gender: PetGender.fromCode(json['gender'] as String?),
      status: PetPetStatus.fromCode(json['status'] as String?),
    );
  }
}

/// 进化阶段候选（pet_evo_stages join 目标种属）
class PetEvoStageOptionModel {
  const PetEvoStageOptionModel({
    required this.speciesId,
    required this.speciesCode,
    required this.name,
    required this.rarityCode,
    required this.stage,
    required this.pickMode,
    required this.branchWeight,
    required this.conditions,
    this.enabled = true,
  });

  final String speciesId;
  final String speciesCode;
  final String name;
  final String rarityCode;
  final int stage;
  final PetPickMode? pickMode;
  final num branchWeight;

  /// [{type,value}] 或 [{type:item,item,cost}]——键域见 [PetEvoCondType]
  final List<Map<String, dynamic>> conditions;

  /// 目标种属未开闸（灰度未覆盖）→ 服务端报 PET_EVOLVE_SPECIES_DISABLED
  final bool enabled;

  /// 条件人话描述（金币/道具/等级/亲密），供 UI 直接展示，不另立文案表
  List<String> get conditionLabels {
    final out = <String>[];
    for (final c in conditions) {
      final type = PetEvoCondType.fromCode(c['type'] as String?);
      switch (type) {
        case PetEvoCondType.level:
          out.add('等级 ${(c['value'] as num?)?.toInt() ?? 0}');
        case PetEvoCondType.intimacy:
          out.add('亲密 ${(c['value'] as num?)?.toInt() ?? 0}');
        case PetEvoCondType.gold:
          out.add('金币 ${(c['value'] as num?)?.toInt() ?? 0}');
        case PetEvoCondType.item:
          // 服务端两种写法都接受：item=item_code，或 item_id=道具 uuid；
          // 后者客户端没有目录映射时不能渲染成空串（'道具  ×1'）
          final code = (c['item'] as String?)?.trim() ?? '';
          final cost = (c['cost'] as num?)?.toInt() ?? 1;
          out.add(code.isEmpty ? '指定道具 ×$cost' : '道具 $code ×$cost');
        case null:
          out.add('${c['type'] ?? '?'}（未支持的条件类型）');
      }
    }
    return out;
  }

  factory PetEvoStageOptionModel.fromJson(Map<String, dynamic> json) {
    final sp = (json['species'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<Map<String, dynamic>> mapList(dynamic raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];
    return PetEvoStageOptionModel(
      speciesId: sp['id'] as String? ?? '',
      speciesCode: sp['species_code'] as String? ?? '',
      name: sp['name_cn'] as String? ?? '',
      rarityCode: sp['rarity_code'] as String? ?? '',
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      pickMode: PetPickMode.fromCode(json['pick_mode'] as String?),
      branchWeight: (json['branch_weight'] as num?) ?? 1,
      conditions: mapList(json['conditions']),
      enabled: sp['enabled'] as bool? ?? true,
    );
  }
}

/// 进化结果（rpc_pet_evolve）
class PetEvolveResultModel {
  const PetEvolveResultModel({
    required this.petId,
    required this.stage,
    required this.speciesCode,
    required this.name,
    required this.rarity,
    required this.fromSpeciesCode,
    required this.goldSpent,
    required this.items,
    this.traitId,
  });

  final String petId;
  final int stage;
  final String speciesCode;
  final String name;
  final String rarity;
  final String fromSpeciesCode;
  final int goldSpent;

  /// 服务端返回 item-uuid → 消耗数量（jsonb object，不是数组）
  final Map<String, int> items;
  final String? traitId;

  factory PetEvolveResultModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PetEvolveResultModel(
      petId: json['pet_id'] as String? ?? '',
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      speciesCode: json['species_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rarity: json['rarity'] as String? ?? '',
      fromSpeciesCode: json['from_species_code'] as String? ?? '',
      goldSpent: (json['gold_spent'] as num?)?.toInt() ?? 0,
      items: rawItems is Map
          ? rawItems.map(
              (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0))
          : const {},
      traitId: json['trait_id'] as String?,
    );
  }
}

/// 特性洗练结果（rpc_pet_wash_trait）
class PetWashTraitResultModel {
  const PetWashTraitResultModel({
    required this.petId,
    required this.changed,
    this.traitId,
    this.traitCode,
    this.traitName,
    this.oldTraitCode,
  });

  final String petId;

  /// 新特性为空是**合法结果**（概率未命中或池空），不是失败
  final String? traitId;
  final String? traitCode;
  final String? traitName;
  final String? oldTraitCode;
  final bool changed;

  String get newTraitLabel => traitName ?? '无特性';
}

/// 孵化等待/加速结果（rpc_pet_hatch_wait / rpc_pet_hatch_accelerate）
class PetHatchWaitResultModel {
  const PetHatchWaitResultModel({
    required this.eggId,
    required this.status,
    required this.remainingSeconds,
    this.readyAt,
    this.waitHours,
    this.mode,
  });

  final String eggId;

  /// waiting / ready
  final String status;
  final int remainingSeconds;
  final DateTime? readyAt;

  /// 仅首次进入等待态时下发（幂等分支不带）
  final int? waitHours;

  /// 加速调用回显 p_mode（item/gold）
  final String? mode;

  bool get isReady => status == PetEggStatus.ready.code;

  factory PetHatchWaitResultModel.fromJson(Map<String, dynamic> json) {
    return PetHatchWaitResultModel(
      eggId: json['egg_id'] as String? ?? '',
      status: json['status'] as String? ?? PetEggStatus.waiting.code,
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
      readyAt: DateTime.tryParse(json['ready_at'] as String? ?? ''),
      waitHours: (json['wait_hours'] as num?)?.toInt(),
      mode: json['mode'] as String?,
    );
  }
}

/// 功能解锁结果（rpc_pet_unlock_feature）
class PetUnlockResultModel {
  const PetUnlockResultModel({required this.featureKey, required this.itemCode});

  final String featureKey;
  final String itemCode;

  PetFeatureKey? get feature => PetFeatureKey.fromCode(featureKey);
}

/// 蛋池概率（pet_egg_pools 已发布最高 config_version 行，App 公示与判定同源）
///
/// 公示页只展示服务端已配置的权重，**客户端不做任何概率补默认值**——
/// 未配置的项（如 gender.male 缺省）显示为 null 并由 UI 隐藏该行，
/// 避免把猜测值当成对外承诺的抽中率。
class PetEggOddsModel {
  const PetEggOddsModel({
    required this.poolCode,
    required this.configVersion,
    required this.families,
    required this.rarities,
    this.maleChance,
  });

  final String poolCode;
  final int configVersion;

  /// {cat: 1.0}——服务端按**累计**与 random() 比较，故值和为 1
  final Map<String, num> families;

  /// {N: 1.0}
  final Map<String, num> rarities;

  /// weights.gender.male；female = 1 - male（未配置 → null）
  final double? maleChance;

  List<String> get familyLines => families.entries
      .map((e) => '${_familyLabel(e.key)} ${(e.value * 100).toStringAsFixed(0)}%')
      .toList();

  List<String> get rarityLines => rarities.entries
      .map((e) => '${e.key} ${(e.value * 100).toStringAsFixed(0)}%')
      .toList();

  /// 性别比展示行（未配置返回 null，UI 隐藏）
  String? get genderLine {
    final m = maleChance;
    if (m == null) return null;
    final pct = (m * 100).round();
    return '♂ $pct% / ♀ ${100 - pct}%';
  }

  static String _familyLabel(String code) => switch (code) {
        'cat' => '猫系',
        'dog' => '犬系',
        'rabbit' => '兔系',
        'mouse' => '鼠系',
        _ => code,
      };

  factory PetEggOddsModel.fromJson(Map<String, dynamic> json) {
    final w = json['weights'] is Map
        ? Map<String, dynamic>.from(json['weights'] as Map)
        : const <String, dynamic>{};
    Map<String, num> numMap(dynamic raw) {
      if (raw is! Map) return const {};
      return {
        for (final e in raw.entries)
          if (e.value is num) e.key as String: e.value as num,
      };
    }

    return PetEggOddsModel(
      poolCode: json['pool_code'] as String? ?? '',
      configVersion: (json['config_version'] as num?)?.toInt() ?? 0,
      families: numMap(w['families']),
      rarities: numMap(w['rarity']),
      maleChance: (numMap(w['gender'])['male'] as num?)?.toDouble(),
    );
  }
}

