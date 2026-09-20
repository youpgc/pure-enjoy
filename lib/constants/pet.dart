/// 宠物系统结构枚举常量（单一真源）
///
/// 与 Supabase DDL 的 check 约束对齐（D:\workspace\sql\feature_pet_tables_20260916.sql）：
/// - pet_items.category      → [PetBagCategory]
/// - pet_items.ladder_key    → [PetLadderKey]
/// - pet_eggs.mode           → [PetEggMode]
/// - pet_eggs.status         → [PetEggStatus]
/// - pet_pets.status         → [PetPetStatus]
/// - pet_pets.gender         → [PetGender]
/// - pet_adventures.rescue_channel → [PetRescueChannel]
/// - pet_evo_stages.pick_mode      → [PetPickMode]
///
/// 铁律：本文件只放**结构枚举**（值域契约），任何数值/阈值/价格/概率
/// 均来自后台配置（pet_config / pet_items / pet_rarities 等），严禁在此硬编码。
library;

/// 背包四分区（equip 一期枚举占位、页签空时隐藏，P2 穿戴启用）
enum PetBagCategory {
  egg('egg', '蛋'),
  consumable('consumable', '消耗品'),
  tool('tool', '工具'),
  equip('equip', '装备');

  const PetBagCategory(this.code, this.label);

  /// 与 DDL check 约束一致的存储值
  final String code;
  final String label;

  static PetBagCategory? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 统一扩容阶梯（背包 / 养育格 / 寄养格三套共用 pet_items 阶梯道具行模型）
enum PetLadderKey {
  backpack('backpack', '背包'),
  rearing('rearing', '养育格'),
  foster('foster', '寄养格');

  const PetLadderKey(this.code, this.label);

  final String code;
  final String label;

  static PetLadderKey? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 蛋孵化模式（档位绑定：instant 即开 / wait 等待孵化，P2 启用 wait）
enum PetEggMode {
  instant('instant', '即开'),
  wait('wait', '等待孵化');

  const PetEggMode(this.code, this.label);

  final String code;
  final String label;

  static PetEggMode? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 蛋实例状态机
enum PetEggStatus {
  unopened('unopened', '未开启'),
  waiting('waiting', '等待中'),
  ready('ready', '可领取'),
  hatched('hatched', '已孵化');

  const PetEggStatus(this.code, this.label);

  final String code;
  final String label;

  static PetEggStatus? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 宠物个体状态（rearing 寄养冻结语义见 pure-enjoy-pet skill §5.6）
enum PetPetStatus {
  rearing('rearing', '养育中'),
  fostered('fostered', '寄养中'),
  adventuring('adventuring', '历险中'),
  breeding('breeding', '繁育中');

  const PetPetStatus(this.code, this.label);

  final String code;
  final String label;

  static PetPetStatus? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 宠物性别
enum PetGender {
  male('male', '♂'),
  female('female', '♀');

  const PetGender(this.code, this.label);

  final String code;
  final String label;

  static PetGender? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 历险救助通道（self 自救 → friend 好友救援（远期）→ npc 兜底；community 社区（远期））
enum PetRescueChannel {
  self_('self', '自救'),
  npc('npc', 'NPC 兜底'),
  friend('friend', '好友救援'),
  community('community', '社区救助');

  const PetRescueChannel(this.code, this.label);

  final String code;
  final String label;

  static PetRescueChannel? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 进化分支抉择模式（P2 启用；stage 为开放整数，不设枚举上限）
enum PetPickMode {
  userChoice('user_choice', '用户抉择'),
  weightedRandom('weighted_random', '加权随机');

  const PetPickMode(this.code, this.label);

  final String code;
  final String label;

  static PetPickMode? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 成长四维属性（键域契约：rpc_pet_allocate_attr 白名单 / 洗练重掷四维，
/// 见 feature_pet_attributes_20260917.sql；孵化基础属性不可洗练）
enum PetAttrKey {
  intellect('intellect', '智力'),
  stamina('stamina', '体力'),
  strength('strength', '力量'),
  agility('agility', '敏捷');

  const PetAttrKey(this.code, this.label);

  /// 与 DDL/RPC 校验一致的存储键
  final String code;
  final String label;

  static PetAttrKey? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 3D 资源包本地状态机（App 端自有状态，非 DDL 枚举；按系 family 独立流转）
///
/// 流转：missing → downloading → verifying → ready；
/// 校验失败/文件缺失 → corrupt（可重下）；下载异常 → error（可重试）。
enum PetAssetPackStatus {
  missing('missing', '未下载'),
  downloading('downloading', '下载中'),
  verifying('verifying', '校验中'),
  ready('ready', '已就绪'),
  corrupt('corrupt', '已损坏'),
  error('error', '下载失败');

  const PetAssetPackStatus(this.code, this.label);

  final String code;
  final String label;
}

/// ==================== S1 素材验收规范（命名即契约，来源《3D展现与交互实现方案》§3.1） ====================

/// 8 标准动画命名（全局统一；命名变更 = 破坏性变更，须走验收页校验）
const List<String> kPetStandardAnimations = <String>[
  'idle', 'eat', 'petted', 'happy', 'sad', 'sleep', 'walk', 'evolve',
];

/// 标准骨骼 rig 命名（每系共享一套）
const List<String> kPetStandardBones = <String>[
  'root', 'hips', 'spine', 'head', 'ear_L', 'ear_R', 'tail',
  'mount_head', 'mount_neck', 'mount_back',
];

/// 标准评级 variants（glTF material variants 命名）
const List<String> kPetStandardVariants = <String>['N', 'R', 'SR', 'SSR'];

/// 素材验收阈值（S1 POC 定版；仅约束资产标准，非业务数值，不违反"数值走后台配置"铁律）
class PetAssetThresholds {
  const PetAssetThresholds._();

  /// 单只 GLB 体积上限（Draco+KTX2 压缩后）
  static const int maxGlbBytes = 3 * 1024 * 1024;

  /// 单只三角面数上限
  static const int maxTriangleCount = 15000;

  /// 全景天空盒体积上限（4096×2048 等距柱状）
  static const int maxSkyboxBytes = 1536 * 1024;

  /// species code 文件名规范：`<family>_<rarity><序号>[_s<阶段>]`，如 cat_n1 / cat_ssr1_s2
  static final RegExp speciesCodePattern =
      RegExp(r'^[a-z]+_(n|r|sr|ssr)\d+(_s[0-9]+)?$');
}

