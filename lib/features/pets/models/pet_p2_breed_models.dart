import '../../../constants/pet.dart';

/// 宠物 P2 繁育模型（单据 / 结配结果 / 领蛋结果 / 功能开通）
///
/// 字段与 `feature_pet_p2_rpcs_20260923.sql` 的返回键、pet_breed_logs 直查
/// select 一一对应，禁止臆测。

/// 繁育单据（pet_breed_logs 直查本人行）
///
/// **不嵌 pet_pets**（双同名表 FK 别名不可靠）：亲代展示名由 UI 用
/// PetPetDetailModel 按 id 回填。
class PetBreedOrderModel {
  const PetBreedOrderModel({
    required this.id,
    required this.status,
    required this.petAId,
    required this.petBId,
    this.startedAt,
    this.readyAt,
    this.eggId,
  });

  final String id;
  final PetBreedLogStatus? status;
  final String petAId;
  final String petBId;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final String? eggId;

  bool get isOngoing => status == PetBreedLogStatus.ongoing;
  bool get isReady => status == PetBreedLogStatus.ready;

  factory PetBreedOrderModel.fromJson(Map<String, dynamic> json) {
    return PetBreedOrderModel(
      id: json['id'] as String? ?? '',
      status: PetBreedLogStatus.fromCode(json['status'] as String?),
      petAId: json['pet_a_id'] as String? ?? '',
      petBId: json['pet_b_id'] as String? ?? '',
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      readyAt: DateTime.tryParse(json['ready_at'] as String? ?? ''),
      eggId: json['egg_id'] as String?,
    );
  }
}

/// 结配结果（rpc_pet_breed_start）
class PetBreedStartResultModel {
  const PetBreedStartResultModel({
    required this.logId,
    required this.gestationHours,
    required this.feeGold,
    this.readyAt,
    this.nextBreedAt,
  });

  final String logId;
  final DateTime? readyAt;
  final int gestationHours;
  final int feeGold;

  /// 亲代下次可繁育时间（服务端 24h CD）
  final DateTime? nextBreedAt;
}

/// 领蛋结果（rpc_pet_breed_claim）
class PetBreedClaimResultModel {
  const PetBreedClaimResultModel({
    required this.logId,
    required this.eggName,
    required this.poolCode,
    required this.rarity,
    this.eggId,
    this.eggItemId,
    this.nextBreedAt,
    this.bagFull = false,
    this.capacity = 0,
    this.used = 0,
  });

  final String logId;
  final String? eggId;
  final String? eggItemId;
  final String eggName;
  final String poolCode;
  final String rarity;
  final DateTime? nextBreedAt;

  /// **P2 唯一的软失败分支**（不抛异常）：背包已满，亲代已释放、单据停在 ready，
  /// 清包后重新调用即可（服务端幂等不回退）。
  final bool bagFull;
  final int capacity;
  final int used;
}

/// 用户已开通功能（pet_user_features 本人行，决定繁育入口是否可用）
class PetFeatureModel {
  const PetFeatureModel({required this.featureKey, this.unlockedAt});

  final String featureKey;
  final DateTime? unlockedAt;

  PetFeatureKey? get key => PetFeatureKey.fromCode(featureKey);

  factory PetFeatureModel.fromJson(Map<String, dynamic> json) {
    return PetFeatureModel(
      featureKey: json['feature_key'] as String? ?? '',
      unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? ''),
    );
  }
}
