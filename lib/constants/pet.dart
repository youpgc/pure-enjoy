/// 宠物系统结构枚举单一真源
///
/// 与 Supabase DDL 的 check 约束对齐（D:\workspace\sql\feature_pet_tables_20260916.sql）：
/// - pet_items.category      → [PetBagCategory]
/// - pet_items.ladder_key    → [PetLadderKey]
/// - pet_eggs.mode           → [PetEggMode]
/// - pet_eggs.status         → [PetEggStatus]
/// - pet_pets.status         → [PetPetStatus]
/// - pet_pets.gender         → [PetGender]
/// - pet_adventures.status       → [PetAdventureStatus]
/// - pet_adventures.rescue_channel → [PetRescueChannel]
/// - pet_evo_stages.pick_mode      → [PetPickMode]
///
/// 铁律：本文件只放**结构枚举**（值域契约），任何数值/阈值/价格/概率
/// 均来自后台配置（pet_config / pet_items / pet_rarities 等），严禁在此硬编码。
///
/// 说明：[PetEggMode]/[PetEggStatus]/[PetLadderKey]/[PetRescueChannel]/[PetPickMode]
/// 当前无页面消费者（对应繁育/蛋背包/扩容购买/社区救助/进化抉择均在 P1/P2 分期），
/// 按三端 ENUM 对齐铁律作为值域契约保留登记，不视为死代码。
/// 3D 素材验收常量（标准动画/骨骼/variants/阈值/资源包状态机）已随
/// 3D 一期下线清理（2026-09-21），后期迭代重写渲染层时再行补回。
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

/// 历险实例状态机（值域 = 线上 pet_adventures_status_check 定版：
/// feature_pet_attributes_20260917.sql 在 recall 批基础上补入 failed）
///
/// 流转：ongoing →（归来 claim 达标）claimed /（不达标结算）failed；
///   ongoing →（归来遇险）awaiting_rescue →（自救或 NPC 兜底）claimed；
///   ongoing →（主动召回，无奖励）recalled；done 为 DDL 预留终态（当前 RPC 不写入）。
enum PetAdventureStatus {
  ongoing('ongoing', '进行中'),
  awaitingRescue('awaiting_rescue', '待救助'),
  failed('failed', '结算失败'),
  done('done', '已结束'),
  claimed('claimed', '已领取'),
  recalled('recalled', '已召回');

  const PetAdventureStatus(this.code, this.label);

  final String code;
  final String label;

  static PetAdventureStatus? fromCode(String? code) {
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

