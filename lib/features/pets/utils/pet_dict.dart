/// 宠物字典缓存（20261030 开放值域文案沉淀 pet_dict_items 表）。
///
/// 进宠物模块时经 [PetRpc.fetchDicts] 一次拉取（rpc_pet_dicts 下发
/// family / item_sub_type / timeline_event 三组），此后取值走
/// 「服务端 label 优先 → 端内常量兜底 → 原码」三级，与场景主题名同模式。
/// 运营改字典表即生效，端内常量仅作拉取失败/未回落的兜底。
/// 消费面（20261030 定版）：family 已接入；item_sub_type 预留（App 归组
/// 走端内）；timeline_event 不接——App 时间线为纪念卡叙事口径（初见/
/// 新生命/游历纪念…），与 Admin 运营口径刻意不同，保持端内文案。
class PetDict {
  PetDict._();

  static Map<String, Map<String, String>> _dicts = const {};

  /// 是否已拉取过字典（未拉取时进模块触发一次预热）
  static bool get isEmpty => _dicts.isEmpty;

  /// rpc_pet_dicts 返回填充；非 Map 结构静默忽略（保端内兜底）
  static void fill(Object? raw) {
    if (raw is! Map<String, dynamic>) return;
    final parsed = <String, Map<String, String>>{};
    raw.forEach((type, group) {
      if (group is Map) {
        parsed[type] = group.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    });
    _dicts = parsed;
  }

  static String _lookup(String type, String code, Map<String, String> fallback) {
    final label = _dicts[type]?[code];
    if (label != null && label.isNotEmpty) return label;
    return fallback[code] ?? code;
  }

  /// 家系名（cat/dog/rabbit/mouse → 猫系…；20261030 收敛原三处副本）
  static String family(String code) =>
      _lookup('family', code, kFamilyLabels);

  /// 商城子类型名（Admin 运营口径全量；App 归组逻辑仍走端内）
  static String subType(String code) =>
      _lookup('item_sub_type', code, kSubTypeLabels);

  /// 端内兜底：家系（与字典种子同源）
  static const kFamilyLabels = <String, String>{
    'cat': '猫系',
    'dog': '犬系',
    'rabbit': '兔系',
    'mouse': '鼠系',
  };

  /// 端内兜底：商城子类型（与 Admin PET_ITEM_SUB_TYPE_LABELS 同源）
  static const kSubTypeLabels = <String, String>{
    'initial': '初始蛋',
    'random': '宠物蛋',
    'food': '食物',
    'clean': '清洁',
    'toy': '玩具',
    'heal': '医疗',
    'rescue': '救援',
    'evolution': '进化',
    'accelerate': '孵化加速',
    'exp_double': '经验加成',
    'trait_wash': '特性洗练',
    'refine_point': '洗练点补给',
    'expand': '扩容',
    'key': '钥匙',
    'rename': '更名',
    'scene': '场景',
    'unlock': '功能解锁',
  };
}
