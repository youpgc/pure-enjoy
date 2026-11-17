/// 西行·角色成长与妖王血量内置兜底值。
///
/// 运营数值由管理后台在 journey_globals 编辑保存；本文件只在列未部署或
/// 行未填值时提供保底，保证对局可玩且强度有界。
///
/// 攻击生态闭环曲线（三端对齐，固定公式：基础值 →加百分比，加法合流）：
/// - 角色：基础攻击（journey_characters.base_attack）起步，每级
///   +[kJourneyLevelAttackPerLv]（12），三选一攻击卡 +[kJourneyUpgradeAttack]
///   （50）累计 ≤[kJourneyAttackUpgradeCap]（500）；
/// - 普通怪/精英：接触伤害随局内强度乘区 ×(0.85+mult×0.2)（buff_mult_cap=6
///   时最高 ×2.05）；
/// - 妖王：接触伤害随玩家等级弹性 ×(1+(等级−1)×[kJourneyBossDamageLvK])，
///   与玩家生命成长同频，等级提升不稀释压力比值。
library;

/// 每次升级提升的基础攻击力（journey_globals.level_attack_per_lv 可覆盖）。
const double kJourneyLevelAttackPerLv = 12.0;

/// 每次升级提升的生命上限（journey_globals.level_hp_per_lv 可覆盖）。
const double kJourneyLevelHpPerLv = 15.0;

/// 攻击力成长卡单次提升量（journey_globals.upgrade_attack 可覆盖）。
const double kJourneyUpgradeAttack = 50.0;

/// 攻击力成长卡累计提升上限（journey_globals.attack_upgrade_cap 可覆盖）。
const double kJourneyAttackUpgradeCap = 500.0;

/// 妖王血量时间项系数（journey_globals.boss_hp_time_k 可覆盖）：
/// 妖王血量只随局内时间增长，不再叠加关卡难度乘区。
const double kJourneyBossHpTimeK = 0.5;

// ---- 平衡曲线（经验幂次 / 怪物等级项 / 境界 / 品阶）----

/// 经验曲线幂次（journey_globals.exp_curve_pow 可覆盖）：
/// 升级所需 = exp_base + exp_per_lv × lv^pow。1.5 使高级段需求指数级
/// 拉开（Lv 20→131 / Lv 60→677 / Lv 99→1275），配合精英经验重标定
/// 支撑 99 级约 45~55 分钟极限局；pow=1 完全还原旧线性曲线。
const double kJourneyExpCurvePow = 1.5;

/// 怪物经验随强度乘区的缩放系数（journey_globals.exp_mult_k 可覆盖）：
/// 经验掉落 ×(1 + 生成时乘区 × K)。乘区上限 12 时最高 ×2.8，
/// 让后段刷怪收益跟得上幂次曲线；K=0 完全还原旧口径。
const double kJourneyExpMultK = 0.15;

/// 普通怪血量的玩家等级成长系数（journey_globals.monster_lv_k 可覆盖）：
/// 普通怪血量 ×(1+(等级−1)×K)。精英不跟等级（秒杀爽感锚点），
/// 妖王另用 boss_hp_lv_k；K=0 还原旧口径。
const double kJourneyMonsterLvK = 0.08;

/// 妖王血量的玩家等级成长系数（journey_globals.boss_hp_lv_k 可覆盖）：
/// 妖王血量 ×(1+(等级−1)×K)，与时间项叠乘；99 级妖王约 ×12.9 基础量，
/// 维持妖王作为唯一操作挑战的定位。K=0 还原旧口径。
const double kJourneyBossHpLvK = 0.12;

/// 精英宝箱掉落概率（journey_battle_params.economy.elite_chest_rate 可覆盖）：
/// 精英以经验掉落为主，宝箱降格为低概率惊喜彩蛋（1%）；妖王保留必掉但仅首杀。
const double kJourneyEliteChestRate = 0.01;

/// 每次境界突破的增伤增量（journey_globals.realm_amp_per 可覆盖）：
/// 增伤Σ%加法合流（伤害定序口径），每档境界 +8%。
const double kJourneyRealmAmpPer = 0.08;

/// 每次境界突破的生命上限增幅（journey_globals.realm_hp_per 可覆盖）：
/// 突破瞬间 maxHp ×(1+该值) 复利，每档 +10%。
const double kJourneyRealmHpPer = 0.10;

/// 境界步长（journey_globals.realm_step 可覆盖）：每 10 级一档境界，
/// 99 级共 9 档；突破发生在档位边界（10/20/.../90 级）。
const int kJourneyRealmStep = 10;

/// 法宝品阶 L9+ 每级增幅（journey_globals.weapon_grade_per_lv 可覆盖）：
/// 分级表只定义到 L8，L9 起按 L8 锚点 ×(1+增幅)^(等级−8) 复利延展。
const double kJourneyWeaponGradePerLv = 0.015;

/// 境界通用名号池（回退与补位口径）：远端行/内置按角色表均未命中的
/// 档位使用。名号而非事件描述；各角色的专属名号按故事顺序嵌入，
/// 空缺档位由此表补位（部分通用）。
const List<String> kJourneyRealmTitles = <String>[
  '初入凡尘',
  '脱胎换骨',
  '法力初成',
  '法力通玄',
  '神游三界',
  '半步金仙',
  '神通大成',
  '功圆行满',
  '圆满正果',
];

/// 境界 9 档按角色名号表（索引 = (等级−1)~/realm_step，钳 0~8）：
/// 每个角色一串**故事中真实持有的名号**（出身→称号→法名→正果），
/// 按故事先后排序；非名号档位用通用名号池补位；终档=原著正果名号。
/// journey_characters.realm_titles jsonb 后台可整表覆盖，行缺失/
/// 档位缺项回落本表，再回落通用名号池。
const Map<String, List<String>> kJourneyRealmTitlesByChar =
    <String, List<String>>{
  // 石猴→美猴王→悟空（祖师赐名）→弼马温→齐天大圣→孙行者→正果
  'wukong': <String>[
    '石猴',
    '美猴王',
    '悟空',
    '弼马温',
    '齐天大圣',
    '孙行者',
    '神通大成',
    '功圆行满',
    '斗战胜佛',
  ],
  // 江流儿→玄奘→三藏→御弟→圣僧→正果
  'tang': <String>[
    '江流儿',
    '玄奘',
    '三藏',
    '御弟',
    '圣僧',
    '法力通玄',
    '神通大成',
    '功圆行满',
    '旃檀功德佛',
  ],
  // 天蓬元帅→猪刚鬣→云栈洞主→悟能（观音赐名）→八戒（唐僧赐名）→正果
  'bajie': <String>[
    '天蓬元帅',
    '猪刚鬣',
    '云栈洞主',
    '悟能',
    '八戒',
    '法力通玄',
    '神通大成',
    '功圆行满',
    '净坛使者',
  ],
  // 卷帘大将→流沙河主→悟净→沙和尚→正果
  'shaseng': <String>[
    '卷帘大将',
    '流沙河主',
    '悟净',
    '沙和尚',
    '法力通玄',
    '神游三界',
    '神通大成',
    '功圆行满',
    '金身罗汉',
  ],
  // 灵珠子→哪吒→三太子→中坛元帅→正果
  'nezha': <String>[
    '灵珠子',
    '哪吒',
    '三太子',
    '中坛元帅',
    '法力通玄',
    '神游三界',
    '神通大成',
    '功圆行满',
    '三坛海会大神',
  ],
  // 红孩儿→火云洞主→圣婴大王→（被收伏后修行）→正果
  'honghaier': <String>[
    '红孩儿',
    '火云洞主',
    '圣婴大王',
    '法力通玄',
    '神游三界',
    '半步金仙',
    '神通大成',
    '功圆行满',
    '善财童子',
  ],
  // 罗刹女→铁扇仙（民间称呼）→铁扇公主→正果（原著「经藏中万古流名」）
  'tieshan': <String>[
    '罗刹女',
    '铁扇仙',
    '铁扇公主',
    '法力通玄',
    '神游三界',
    '半步金仙',
    '神通大成',
    '功圆行满',
    '万古流名',
  ],
  // 修行→老君→道德天尊（终档）
  'laojun': <String>[
    '初入凡尘',
    '脱胎换骨',
    '法力初成',
    '法力通玄',
    '神游三界',
    '神通大成',
    '半步金仙',
    '太上老君',
    '道德天尊',
  ],
  // 兜率童子→金角大王→（回归本职）→金炉正果
  'jinjiao': <String>[
    '兜率童子',
    '金角大王',
    '法力初成',
    '法力通玄',
    '神游三界',
    '神通大成',
    '半步金仙',
    '功圆行满',
    '金炉大神',
  ],
};
