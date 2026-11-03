library;

/// 宠物签到域模型（宠物模块独享签到体系）
///
/// 字段与 rpc_pet_checkin_* 返回体一一对应，禁止臆测。
/// 自 pet_rpc_models 按域拆出（500 行硬底线），经 pet_rpc_models export
/// 门面转发——既有调用方零改动。

/// ---------- 宠物签到（宠物模块独享签到体系） ----------

/// 签到奖励格（金币 + 常规消耗品道具；运营在 Admin 月历模板配置，不发稀有道具）
class PetCheckinReward {
  const PetCheckinReward({this.gold = 0, this.items = const []});

  final int gold;

  /// [(item_code, count)]
  final List<(String, int)> items;

  factory PetCheckinReward.fromJson(dynamic raw) {
    if (raw is! Map) return const PetCheckinReward();
    final items = <(String, int)>[];
    final rawItems = raw['items'];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map && it['code'] is String) {
          items.add((it['code'] as String, (it['count'] as num?)?.toInt() ?? 1));
        }
      }
    }
    return PetCheckinReward(
      gold: (raw['gold'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }

  /// 文案摘要（"55 金币 + 猫条×1"；空奖励 → '休息一天'）
  String summary(String Function(String code) nameOf) {
    final parts = <String>[
      if (gold > 0) '$gold 金币',
      for (final (c, n) in items) '${nameOf(c)}×$n',
    ];
    return parts.isEmpty ? '休息一天' : parts.join(' + ');
  }
}

/// 月度签到状态（rpc_pet_checkin_status）
class PetCheckinStatusModel {
  const PetCheckinStatusModel({
    required this.monthKey,
    required this.days,
    required this.totalSigned,
    required this.makeupCount,
    required this.makeupLimit,
    required this.makeupCardCount,
    required this.signedDates,
  });

  final String monthKey;

  /// 当月奖励表快照（1~31 → 奖励；缺格 = 未配置，前端不造值）
  final Map<int, PetCheckinReward> days;
  final int totalSigned;

  /// 本月已补签次数 / 上限（操作月口径）
  final int makeupCount;
  final int makeupLimit;
  final int makeupCardCount;

  /// {'YYYY-MM-DD': 是否补签}
  final Map<String, bool> signedDates;


  factory PetCheckinStatusModel.fromJson(Map<String, dynamic> json) {
    final days = <int, PetCheckinReward>{};
    final rawDays = json['days'];
    if (rawDays is Map) {
      rawDays.forEach((k, v) {
        final d = int.tryParse(k.toString());
        if (d != null) days[d] = PetCheckinReward.fromJson(v);
      });
    }
    final signed = <String, bool>{};
    final rawSigned = json['signed_dates'];
    if (rawSigned is List) {
      for (final it in rawSigned) {
        if (it is Map && it['date'] is String) {
          signed[it['date'] as String] = it['makeup'] == true;
        }
      }
    }
    return PetCheckinStatusModel(
      monthKey: json['month_key']?.toString() ?? '',
      days: days,
      totalSigned: (json['total_signed'] as num?)?.toInt() ?? 0,
      makeupCount: (json['makeup_count'] as num?)?.toInt() ?? 0,
      makeupLimit: (json['makeup_limit'] as num?)?.toInt() ?? 4,
      makeupCardCount: (json['makeup_card_count'] as num?)?.toInt() ?? 0,
      signedDates: signed,
    );
  }


  /// 指定日是否已签（任意形式）
  bool isSigned(DateTime d) =>
      signedDates.containsKey(_key(d));

  /// 指定日是否为补签
  bool isMakeup(DateTime d) => signedDates[_key(d)] == true;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 签到 / 补签结果（rpc_pet_checkin_sign）
class PetCheckinSignResultModel {
  const PetCheckinSignResultModel({
    required this.date,
    required this.makeup,
    required this.gold,
    required this.items,
    required this.totalSigned,
  });

  final String date;
  final bool makeup;
  final int gold;

  /// [(item_code, count)]（含里程碑连带发放）
  final List<(String, int)> items;
  final int totalSigned;

  factory PetCheckinSignResultModel.fromJson(Map<String, dynamic> json) {
    final items = <(String, int)>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map && it['code'] is String) {
          items.add((it['code'] as String, (it['count'] as num?)?.toInt() ?? 1));
        }
      }
    }
    return PetCheckinSignResultModel(
      date: json['date']?.toString() ?? '',
      makeup: json['makeup'] == true,
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      items: items,
      totalSigned: (json['total_signed'] as num?)?.toInt() ?? 0,
    );
  }
}
