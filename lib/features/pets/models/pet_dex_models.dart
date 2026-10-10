/// 宠物图鉴（§2026-10-09 收集功能）——rpc_pet_dex 载荷
///
/// 收集语义：owned = 历史拥有过（含已放生，软删除不熄灭）；
/// 范围 = enabled 形态（三系开闸前仅猫系，开闸自动扩容，无需发版）。
class PetDexModel {
  const PetDexModel({
    required this.total,
    required this.ownedTotal,
    required this.families,
  });

  final int total;
  final int ownedTotal;
  final List<PetDexFamily> families;

  static PetDexModel fromJson(Map<String, dynamic> json) {
    final fams = json['families'];
    return PetDexModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      ownedTotal: (json['owned_total'] as num?)?.toInt() ?? 0,
      families: fams is List
          ? fams
              .whereType<Map>()
              .map((e) => PetDexFamily.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const <PetDexFamily>[],
    );
  }
}

class PetDexFamily {
  const PetDexFamily({required this.family, required this.chains});

  /// cat / dog / rabbit / mouse（服务端按字母序返回，展示序客户端定）
  final String family;
  final List<PetDexChain> chains;

  static PetDexFamily fromJson(Map<String, dynamic> json) {
    final ch = json['chains'];
    return PetDexFamily(
      family: json['family']?.toString() ?? '',
      chains: ch is List
          ? ch
              .whereType<Map>()
              .map((e) => PetDexChain.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const <PetDexChain>[],
    );
  }
}

class PetDexChain {
  const PetDexChain({
    required this.chain,
    required this.rarity,
    required this.ownedN,
    required this.n,
    required this.stages,
  });

  final String chain;
  final String rarity;
  final int ownedN;
  final int n;
  final List<PetDexStage> stages;

  static PetDexChain fromJson(Map<String, dynamic> json) {
    final st = json['stages'];
    return PetDexChain(
      chain: json['chain']?.toString() ?? '',
      rarity: json['rarity']?.toString() ?? '',
      ownedN: (json['owned_n'] as num?)?.toInt() ?? 0,
      n: (json['n'] as num?)?.toInt() ?? 0,
      stages: st is List
          ? st
              .whereType<Map>()
              .map((e) => PetDexStage.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const <PetDexStage>[],
    );
  }
}

class PetDexStage {
  const PetDexStage({
    required this.stage,
    required this.speciesCode,
    required this.name,
    required this.owned,
    this.firstAt,
  });

  final int stage;
  final String speciesCode;
  final String name;
  final bool owned;

  /// 首次获得时间（未获得为 null）
  final DateTime? firstAt;

  static PetDexStage fromJson(Map<String, dynamic> json) {
    return PetDexStage(
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      speciesCode: json['species_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      owned: json['owned'] == true,
      firstAt: DateTime.tryParse(json['first_at']?.toString() ?? ''),
    );
  }
}
