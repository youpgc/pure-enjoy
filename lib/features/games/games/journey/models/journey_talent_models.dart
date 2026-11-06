/// 西行·五行天赋分支与流水模型（v4 分支树制）。
///
/// 每角色一棵五行树：5 系 × 16 层 = 80 层 + 第 81 点加强点。每系拆
/// 3 分支（属性内容不同）：core 本源枝 8 层（系核心属性）/ growth
/// 生息枝 5 层（第二属性）/ sig 化形枝 3 层（标志强化）。点亮双消耗
/// （1 天赋点 + cost_base×层号 功德）；相生 1:1 循环锁 + 相克制衡在
/// App 端判定（见 progress_talent）。流水参照宠物钱包 append-only
/// 口径，余额快照放 balance_after。模型只含 App 消费列，fromJson
/// 缺省字段给安全默认值（后端新增列不崩）。
library;

/// 天赋分支（journey_talent_branches 行）：每角色每系一条分支。
class JourneyTalentBranchModel {
  final String id;

  /// 归属角色（tang/wukong/bajie/shaseng）。
  final String characterCode;
  final String element; // metal/wood/water/fire/earth

  /// 分支类型：core 本源枝 / growth 生息枝 / sig 化形枝。
  final String branchType;
  final String branchCode; // {char}_{element}_{branch}
  final int seq;
  final String name;
  final String attrKey;

  /// 每层效果数值（远端 numeric 列，App 按 num 承载）。
  final num valuePerLevel;
  final int maxLv;
  final int costBase;

  /// 每层效果说明（运营配置；空则 App 按 attr_key 标签兜底拼接）。
  final String effectDesc;

  const JourneyTalentBranchModel({
    required this.id,
    this.characterCode = '',
    required this.element,
    required this.branchType,
    required this.branchCode,
    this.seq = 0,
    required this.name,
    required this.attrKey,
    this.valuePerLevel = 1,
    this.maxLv = 8,
    this.costBase = 50,
    this.effectDesc = '',
  });

  factory JourneyTalentBranchModel.fromJson(Map<String, dynamic> json) {
    return JourneyTalentBranchModel(
      id: json['id'] as String? ?? '',
      characterCode: json['character_code'] as String? ?? '',
      element: json['element'] as String? ?? 'metal',
      branchType: json['branch_type'] as String? ?? 'core',
      branchCode: json['branch_code'] as String? ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      attrKey: json['attr_key'] as String? ?? '',
      valuePerLevel: json['value_per_level'] as num? ?? 1,
      maxLv: (json['max_lv'] as num?)?.toInt() ?? 8,
      costBase: (json['cost_base'] as num?)?.toInt() ?? 50,
      effectDesc: json['effect_desc'] as String? ?? '',
    );
  }
}

// ---- 五行天赋树 v4 常量 ----

/// 天赋树挂载的角色清单（与 journey_characters 种子一致，展示顺序；
/// 含非取经扩展角色——种子树自动生成，远端行可覆盖定制）。
const List<String> kJourneyTalentChars = <String>[
  'tang',
  'wukong',
  'bajie',
  'shaseng',
  'nezha',
  'honghaier',
  'tieshan',
  'laojun',
  'jinjiao',
];

/// 五行系序（天赋页 Tab 与相生判定顺序）。
const List<String> kJourneyTalentElements = <String>[
  'metal',
  'wood',
  'water',
  'fire',
  'earth',
];

/// 分支类型序（页内展示顺序：本源 → 生息 → 化形）。
const List<String> kJourneyTalentBranchTypes = <String>[
  'core',
  'growth',
  'sig',
];

/// 各分支层数上限（8+5+3=16/系；5 系×16=80 + 加强点 1 = 81 点树）。
const Map<String, int> kJourneyBranchMaxLv = <String, int>{
  'core': 8,
  'growth': 5,
  'sig': 3,
};

/// 加强点在 talent_levels[char] 中的键。
const String kJourneyTalentEnhanceKey = 'enhance';

/// 分支编码组装（{char}_{element}_{branch}）。
String journeyBranchCode(String char, String element, String branch) =>
    '${char}_${element}_$branch';

/// 五行属性中文标签（attr_key → 文案；配置缺省时兜底拼接用）。
const Map<String, String> kJourneyTalentAttrLabels = <String, String>{
  'attack': '攻击力',
  'max_hp': '生命上限',
  'attack_speed': '环绕转速',
  'damage_amp': '武器伤害',
  'armor': '护甲',
  'crit_damage': '暴击伤害',
  'crit_rate': '暴击率',
  'regen': '自动回复',
  'exp_gain': '经验获取',
  'pickup_range': '拾取范围',
};

/// 分支每层效果数值兜底（远端分支行缺失时按 element+branch 取值；
/// 与 SQL 种子一致）。
const Map<String, Map<String, num>> kJourneyBranchFallbackValue =
    <String, Map<String, num>>{
  'core': <String, num>{
    'metal': 0.03,
    'wood': 8,
    'water': 0.02,
    'fire': 0.03,
    'earth': 0.5,
  },
  'growth': <String, num>{
    'metal': 0.05,
    'wood': 0.3,
    'water': 0.04,
    'fire': 0.015,
    'earth': 8,
  },
  'sig': <String, num>{
    'metal': 1,
    'wood': 1,
    'water': 1,
    'fire': 1,
    'earth': 1,
  },
};

/// 角色特殊能力常量表：char → (能力名, 一句描述)。
/// 加强点（五系修满 80 层后第 81 点）点亮即解锁（引擎钩子按角色标记生效）。
const Map<String, (String, String)> kJourneyCharAbilities =
    <String, (String, String)>{
  'tang': (
    '金身佛光',
    '每 10 秒回复 8% 最大生命，每局首次致命伤免死并回复 30% 生命',
  ),
  'wukong': (
    '身外身法',
    '每击杀 30 只触发 10 秒：临时 +1 分身扇叶且环绕转速 +30%',
  ),
  'bajie': (
    '铜皮铁骨',
    '受击后 3 秒内减伤 30%，且命中击退强度 +50%',
  ),
  'shaseng': (
    '伏魔重击',
    '每 20 秒蓄力，下一次命中造成 3 倍伤害并定身 260px 内怪物 1 秒',
  ),
};

/// 功德流水（append-only；journey_merit_records 行/本地镜像）。
class JourneyMeritRecordModel {
  final String id;
  final int delta;

  /// 入账后余额快照（append-only 口径）。
  final int balanceAfter;
  final String sourceType; // run_settle / talent_spend / character_unlock
  final String refType;
  final String refId;
  final String remark;
  final DateTime? createdAt;

  const JourneyMeritRecordModel({
    required this.id,
    required this.delta,
    required this.balanceAfter,
    required this.sourceType,
    this.refType = '',
    this.refId = '',
    this.remark = '',
    this.createdAt,
  });

  factory JourneyMeritRecordModel.fromJson(Map<String, dynamic> json) {
    return JourneyMeritRecordModel(
      id: json['id'] as String? ?? '',
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      sourceType: json['source_type'] as String? ?? '',
      refType: json['ref_type'] as String? ?? '',
      refId: json['ref_id'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'delta': delta,
        'balance_after': balanceAfter,
        'source_type': sourceType,
        'ref_type': refType,
        'ref_id': refId,
        'remark': remark,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// 对局记录（journey_runs 行/本地镜像）。
/// kind=对局模式：mainline=主线难 / endless=无尽妖潮 / daily=西行游历
/// （远端 journey_runs 无 kind 列，仅本地镜像区分展示）。
class JourneyRunRecordModel {
  final String id;
  final int levelNo;
  final int kills;
  final int meritGained;
  final int durationMs;
  final bool cleared;
  final DateTime? createdAt;
  final String kind;

  /// 关卡展示标题（「第 N 难 · 关卡名称」；虚拟关=模式名/地图名；
  /// 旧记录为空时展示层按 levelNo/kind 兜底）。
  final String levelTitle;

  const JourneyRunRecordModel({
    required this.id,
    required this.levelNo,
    required this.kills,
    required this.meritGained,
    this.durationMs = 0,
    this.cleared = false,
    this.createdAt,
    this.kind = 'mainline',
    this.levelTitle = '',
  });

  factory JourneyRunRecordModel.fromJson(Map<String, dynamic> json) {
    return JourneyRunRecordModel(
      id: json['id'] as String? ?? '',
      levelNo: (json['level_no'] as num?)?.toInt() ?? 0,
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      meritGained: (json['merit_gained'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      cleared: json['cleared'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      kind: json['kind'] as String? ?? 'mainline',
      levelTitle: json['level_title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'level_no': levelNo,
        'kills': kills,
        'merit_gained': meritGained,
        'duration_ms': durationMs,
        'cleared': cleared,
        'created_at': createdAt?.toIso8601String(),
        'kind': kind,
        'level_title': levelTitle,
      };
}
