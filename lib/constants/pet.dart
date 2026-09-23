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
/// - pet_wallet_records.source_type → [PetWalletSourceType]（DDL 为 not valid CHECK）
/// - pet_items.effect->>'type'     → [PetItemEffectType]
/// - pet_user_features.feature_key → [PetFeatureKey]
/// - pet_breed_logs.status         → [PetBreedLogStatus]
/// - pet_quests.type / difficulty / condition->>'type'
///                                 → [PetQuestType] / [PetQuestDifficulty] / [PetQuestConditionType]
/// - pet_achievements.tier / condition_type → [PetAchTier] / [PetAchConditionType]
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

// ============================================================
// P2 键域（2026-09-23 与 Admin src/constants/pet.ts、DDL 注释三端对齐）
// pet_* 配置表除 pet_items_ladder_shape_chk 外无 CHECK 约束，以下值域
// 纯靠三端枚举纪律兜底（铁律 12）：新增取值必须 DDL 注释 / App / Admin 同批提交。
// ============================================================

/// 金币钱包流水来源（pet_wallet_records.source_type）
///
/// CHECK 以 not valid 方式挂在 fix_pet_review_p1_20260921.sql §6（六类），
/// `pet_feature_spend` 由 feature_pet_p2_rpcs_20260923.sql 新增（金币档孵化加速花费）。
enum PetWalletSourceType {
  shopBuy('pet_shop_buy', '商城消费'),
  systemReward('pet_system_reward', '系统发放'),
  achievement('pet_achievement', '成就发放'),
  exchange('pet_exchange', '积分兑换'),
  adminGrant('pet_admin_grant', '客服调整'),
  adventurePenalty('pet_adventure_penalty', '历险失败惩罚'),
  featureSpend('pet_feature_spend', '功能消耗');

  const PetWalletSourceType(this.code, this.label);

  final String code;
  final String label;

  static PetWalletSourceType? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 道具效果类型（pet_items.effect->>'type'，服务端按此分流）
///
/// 消费点：rpc_pet_use_item 认 feed/clean/toy/heal/refine_point；
/// rescue 只允许用于历险自救（fix_pet_review_p1_20260921.sql §P1-1，
/// 判据为 sub_type='rescue' **或** effect.type='rescue' 二者之一）；
/// P2 三类各由专属 RPC 卡键（hatch_accel→rpc_pet_hatch_accelerate、
/// trait_wash→rpc_pet_wash_trait 且 category 必须 consumable、unlock→rpc_pet_unlock_feature）。
/// refine_reassign 是 2026-09-20 旧属性洗练语义（tool_refine 已改 refine_point），
/// 仅作历史数据兜底展示登记，新配置不得再写。
enum PetItemEffectType {
  feed('feed', '喂养'),
  clean('clean', '清洁'),
  toy('toy', '玩耍'),
  heal('heal', '疗伤'),
  rescue('rescue', '历险救助'),
  refinePoint('refine_point', '洗练点补给'),
  refineReassign('refine_reassign', '属性重掷（已下线）'),
  hatchAccel('hatch_accel', '孵化加速'),
  traitWash('trait_wash', '特性洗练'),
  unlock('unlock', '功能解锁');

  const PetItemEffectType(this.code, this.label);

  final String code;
  final String label;

  static PetItemEffectType? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 可解锁功能（pet_user_features.feature_key = 解锁道具 effect.feature）
///
/// batch_feed（批量喂养）后端尚无 RPC，故不列入值域。
enum PetFeatureKey {
  breeding('breeding', '繁育');

  const PetFeatureKey(this.code, this.label);

  final String code;
  final String label;

  static PetFeatureKey? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 孵化加速支付方式（rpc_pet_hatch_accelerate 的 p_mode）
enum PetAccelMode {
  item('item', '道具'),
  gold('gold', '金币');

  const PetAccelMode(this.code, this.label);

  final String code;
  final String label;

  static PetAccelMode? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 繁育单据状态（pet_breed_logs.status）
///
/// ongoing 孕期 → ready 可领蛋（bag_full 时停留在此，清包后可重调）→ claimed 已产蛋。
enum PetBreedLogStatus {
  ongoing('ongoing', '孕期'),
  ready('ready', '可领蛋'),
  claimed('claimed', '已领取');

  const PetBreedLogStatus(this.code, this.label);

  final String code;
  final String label;

  static PetBreedLogStatus? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 进化条件类型（pet_evo_stages.conditions[].type，四条全满足才放行）
///
/// 白名单外的 type 服务端直接抛 PET_EVOLVE_COND_INVALID；
/// level/intimacy/gold 读 value，item 读 item(=item_code) 或 item_id + cost。
enum PetEvoCondType {
  level('level', '等级达到'),
  intimacy('intimacy', '亲密度达到'),
  gold('gold', '消耗金币'),
  item('item', '消耗道具');

  const PetEvoCondType(this.code, this.label);

  final String code;
  final String label;

  static PetEvoCondType? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 任务周期类型（pet_quests.type；日/周两套实例靠此判别，周一同日不串改）
enum PetQuestType {
  daily('daily', '每日'),
  weekly('weekly', '每周');

  const PetQuestType(this.code, this.label);

  final String code;
  final String label;

  static PetQuestType? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 任务难度（pet_quests.difficulty；注意与成就 tier 是两组值域，勿混写）
enum PetQuestDifficulty {
  normal('normal', '普通'),
  advanced('advanced', '进阶'),
  hard('hard', '困难');

  const PetQuestDifficulty(this.code, this.label);

  final String code;
  final String label;

  static PetQuestDifficulty? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 成就档位（pet_achievements.tier；legendary 是唯一「传说蛋」相关档）
enum PetAchTier {
  normal('normal', '普通'),
  legendary('legendary', '传说');

  const PetAchTier(this.code, this.label);

  final String code;
  final String label;

  static PetAchTier? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 成就条件类型（rpc_pet_achievement_check 的 case 白名单，11 值）
///
/// 值域外的 condition_type 服务端不报错、进度恒 0，只能靠后台自检发现拼写错误。
/// 目标值读取优先级 condition_value.value → .target → 1；rarityOwned 另读 rarity 键。
enum PetAchConditionType {
  feedTotal('feed_total', '累计喂养次数'),
  interactTotal('interact_total', '累计互动次数'),
  hatchTotal('hatch_total', '累计孵化次数'),
  adventureTotal('adventure_total', '累计历险次数'),
  rescueTotal('rescue_total', '累计救助次数'),
  evolveTotal('evolve_total', '累计进化次数'),
  breedEggTotal('breed_egg_total', '累计繁育产蛋次数'),
  levelMax('level_max', '最高等级达到'),
  petsOwned('pets_owned', '拥有宠物数达到'),
  familiesOwned('families_owned', '拥有系别数达到'),
  rarityOwned('rarity_owned', '拥有指定评级宠物');

  const PetAchConditionType(this.code, this.label);

  final String code;
  final String label;

  static PetAchConditionType? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// 任务条件类型（服务端 _pet_quest_bump 的 bump 键，四值封闭）
///
/// 写第五种不会报错，但该任务进度恒为 0。
enum PetQuestConditionType {
  feed('feed', '喂养次数'),
  interact('interact', '互动次数'),
  adventure('adventure', '历险次数'),
  hatch('hatch', '孵化次数');

  const PetQuestConditionType(this.code, this.label);

  final String code;
  final String label;

  static PetQuestConditionType? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

