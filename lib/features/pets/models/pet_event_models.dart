/// 随机事件（需求 §3.6）——roll 载荷与选择结算结果
///
/// 服务端契约见 `feature_pet_random_events_20261008.sql`：
/// - roll 返回 `{fired:false}` 或 `{fired:true, id, code, context, title, text, options:[...]}`；
///   options 各项 `{label, rewards:{gold,points,exp,mood,intimacy,hunger,item_code,item_count}}`，
///   奖惩在 roll 时原样下发（§17#1 公示原则：所见即所得）；
/// - choose 返回结算明细（gold/points/exp/mood/intimacy/hunger/item_* + bag_full）。
class PetEventModel {
  const PetEventModel({
    required this.id,
    required this.code,
    required this.context,
    required this.title,
    required this.text,
    required this.options,
  });

  final String id;
  final String code;
  final String context;
  final String title;
  final String text;
  final List<PetEventOptionModel> options;

  static PetEventModel? fromJson(Map<String, dynamic> json) {
    if (json['fired'] != true) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final optionsRaw = json['options'];
    final options = optionsRaw is List
        ? optionsRaw
            .whereType<Map>()
            .toList()
            .asMap()
            .entries
            .map((e) => PetEventOptionModel.fromJson(
                e.value.cast<String, dynamic>(), e.key))
            .toList()
        : const <PetEventOptionModel>[];
    return PetEventModel(
      id: id,
      code: json['code']?.toString() ?? '',
      context: json['context']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      options: options,
    );
  }

  @override
  String toString() => 'PetEventModel($code, $title, ${options.length}项)';
}

/// 单个选项：文案 + 公示奖惩包（choose 时服务端按同包结算）
class PetEventOptionModel {
  const PetEventOptionModel({
    required this.index,
    required this.label,
    required this.rewards,
  });

  final int index;
  final String label;

  /// 公示奖惩原包（键与 SQL content schema 一致，缺省键 = 无该项）
  final Map<String, dynamic> rewards;

  factory PetEventOptionModel.fromJson(Map<String, dynamic> json, int index) {
    final raw = json['rewards'];
    return PetEventOptionModel(
      index: index,
      label: json['label']?.toString() ?? '',
      rewards:
          raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{},
    );
  }
}

/// choose 结算结果（字段与服务端返回一一对应；App 据此拼奖励到账提示）
class PetEventChooseResultModel {
  const PetEventChooseResultModel({
    required this.optionLabel,
    required this.gold,
    required this.points,
    required this.exp,
    required this.mood,
    required this.intimacy,
    required this.hunger,
    required this.itemCode,
    required this.itemCount,
    required this.bagFull,
  });

  final String optionLabel;
  final int gold;
  final int points;
  final int exp;
  final int mood;
  final int intimacy;
  final int hunger;
  final String? itemCode;
  final int itemCount;

  /// 道具奖励因背包满未发放（与每日任务发奖同口径：不中断、如实提示）
  final bool bagFull;

  static PetEventChooseResultModel fromJson(Map<String, dynamic> json) {
    int r(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PetEventChooseResultModel(
      optionLabel: json['option_label']?.toString() ?? '',
      gold: r('gold'),
      points: r('points'),
      exp: r('exp'),
      mood: r('mood'),
      intimacy: r('intimacy'),
      hunger: r('hunger'),
      itemCode: (json['item_code'] as String?)?.isEmpty == true
          ? null
          : json['item_code'] as String?,
      itemCount: r('item_count'),
      bagFull: json['bag_full'] == true,
    );
  }

  /// 到账明细文案（跳过 0 值项；顺序稳定便于测试）
  List<String> get grantedLines {
    final lines = <String>[];
    void add(String text, bool cond) {
      if (cond) lines.add(text);
    }

    add('金币 +$gold', gold > 0);
    add('积分 +$points', points > 0);
    add('经验 +$exp', exp > 0);
    add('心情 +$mood', mood > 0);
    add('亲密 +$intimacy', intimacy > 0);
    add('饱食 $hunger', hunger != 0);
    if (itemCode != null) {
      add(bagFull ? '道具未发放（背包已满）' : '道具 ×$itemCount', true);
    }
    return lines;
  }

  @override
  String toString() =>
      'PetEventChooseResultModel($optionLabel, ${grantedLines.join("/")})';
}

/// 事件 context 值域（与服务端代码枚举同源；两端一致由 SQL 自检保证）
const kPetEventContextHomeOpen = 'home_open';
const kPetEventContextActionDone = 'action_done';
