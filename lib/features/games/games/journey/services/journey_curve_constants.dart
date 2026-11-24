/// 西行·难度曲线内置兜底值。
///
/// 运营数值由管理后台在 journey_globals 编辑保存；本文件只在列未部署或
/// 行未填值时提供保底，保证对局可玩且强度有界。
library;

/// 局内强度每分钟增长斜率（journey_globals.buff_time_slope 可覆盖）。
/// 时间项与关卡项分离，难号不在时间斜率中重复计入。
/// 0.40 配合上限 12：13 分钟左右触顶，99 级长局强度仍有爬升空间。
const double kJourneyBuffTimeSlope = 0.40;

/// 每点关卡难度的强度乘区增量（journey_globals.buff_level_mult 可覆盖）。
const double kJourneyBuffLevelMult = 0.04;

/// 生效强度乘区上限（journey_globals.buff_mult_cap 可覆盖）：
/// 波次倍率、妖王阶段倍率等叠加源在怪物生成时统一钳到此值。
/// 6→12：旧上限 13~16 分钟即触顶，长局后半段强度恒定是 20 级后
/// 无可玩性的根因之一；放宽后经验/怪物成长同步延展。
const double kJourneyBuffMultCap = 12.0;

/// 生态轮换分带线（按局内角色等级）：10 级精英登场、16 级普通怪渐退、
/// 26 级普通怪绝迹（只刷精英）。角色能力上升后小怪不再刷，取而代之
/// 的是持续遭遇可秒杀的精英——爽感锚点由「一刀切小怪」换成「大怪秒杀」。
const int kJourneyEcoEliteInLv = 10;
const int kJourneyEcoCommonFadeLv = 16;
const int kJourneyEcoCommonOutLv = 26;

/// 生态轮换精英分阶血量阈值：小型 ≤600 / 中型 ≤2800 / 大型 >2800。
/// 按角色等级限定登场精英档位（低级不见顶阶精英，高级不刷低阶小精英）。
const double kJourneyEcoEliteMidHp = 600;
const double kJourneyEcoEliteLargeHp = 2800;

/// 怪物最终移速上限（journey_globals.monster_speed_cap 可覆盖，px/s）：
/// 低于玩家基准移速，长时对局怪群不会反超玩家。
const double kJourneyMonsterSpeedCap = 200.0;

/// 妖王接触伤害的玩家等级成长系数（journey_globals.boss_damage_lv_k 可覆盖）：
/// 接触伤害 ×(1+(玩家等级−1)×K)。K 与玩家生命成长斜率（15/100 每级）同频，
/// 玩家等级提升不稀释妖王压力比值。
const double kJourneyBossDamageLvK = 0.15;

/// 吸血回复比例（占最终命中伤害）：1 级基准，每级按
/// journey_weapon_slots.lifesteal.value_per_level（缺省 +1.5%）递增，
/// 比例钳 ≤ 上限。回复随伤害量级缩放，低伤命中另设保底点数。
const double kJourneyLifestealBaseRatio = 0.03;

/// 吸血比例的每级增量（journey_weapon_slots.lifesteal.value_per_level
/// 可覆盖）：9 级 = 3% + 1.5%×8 = 15%。
const double kJourneyLifestealRatioPerLv = 0.015;

/// 吸血比例上限：无论等级与远端配置，单次回复比例不突破此值。
const double kJourneyLifestealRatioCap = 0.20;

/// 吸血单次保底回复点数：伤害×比例不足 2 点时按 2 点回复，
/// 保证开局低伤阶段吸血维度仍然有效。
const double kJourneyLifestealHealFloor = 2.0;

/// 吸血每秒回复上限（占最大生命比例）：多目标高频命中的合计钳制，
/// 防止扇叶扫掠多目标时回复叠乘失控。
const double kJourneyLifestealSecCapRatio = 0.10;

/// 穿刺破甲比例（无视目标护甲比例）：1 级基准，每级按
/// journey_weapon_slots.pierce.value_per_level（缺省 +2.5%）递增，钳 ≤ 上限。
const double kJourneyPierceBaseRatio = 0.10;

/// 穿刺破甲的每级增量（journey_weapon_slots.pierce.value_per_level 可覆盖）：
/// 9 级 = 10% + 2.5%×8 = 30%。
const double kJourneyPierceIgnorePerLv = 0.025;

/// 穿刺破甲比例上限：无论等级与远端配置，无视护甲比例不突破此值。
const double kJourneyPierceRatioCap = 0.30;

/// ---- 无尽妖潮·妖王潮（journey_globals 十列可覆盖，App 内置兜底）----
/// 妖潮语义：波次表配置妖王配额的波起小怪淡出（精英为主）、妖王波改
/// 配额制——同场并发钳制、击杀后按降临倒计时依次补位（不同时刷新），
/// 妖王领地锚点散布（最小间距）+ 软领地 leash 杜绝群殴；妖潮起点以
/// 后台实际配置为准（首个 boss_count>0 的波）。

/// 妖潮期每波妖王配额兜底公式的起点（波次表首个 boss_count>0 的波
/// 优先于本值）：前 9 波发育期（小怪+精英），第 10 波起妖王按线性
/// 端点式递增至终波满额。
const int kJourneyEndlessBossTideStartWave = 10;

/// 同波妖王配额上限（可配置，默认 99）：单波刷新量级，与同屏并发
/// （endless_boss_concurrent，默认 10）为两个独立维度——配额限总量、
/// 并发限在场，配额内超出并发的部分按降临倒计时排队补位。
const int kJourneyEndlessBossCountCap = 99;

/// 同场并发妖王数上限（可配置，默认 10）：配额内妖王按降临倒计时依次
/// 登场，同屏在场数不突破此值；击杀腾位后补位降临。
const int kJourneyEndlessBossConcurrent = 10;

/// 妖王补位降临倒计时（秒）：缺口出现后按此间隔依次降临（后台可配）。
const double kJourneyEndlessBossArriveCd = 10.0;

/// 妖王能力每波额外增幅：妖王 buffMult = 波次 buff ×(1+(波号−分界)×K)，
/// 与全局波次 buff 叠乘；0=只吃波次 buff。
const double kJourneyEndlessBossAmpPerWave = 0.04;

/// 妖王领地半径（px）：软领地侦测圈=该值；null/未配回落 isBoss 默认口径。
const double kJourneyEndlessBossTerritoryRadius = 300.0;

/// 软领地 leash 倍率：追出领地半径×1.3 即脱战归位锚点（快速回血照旧）。
const double kJourneyEndlessBossLeashGain = 1.3;

/// 多妖王锚点最小间距（px）：降临点散布约束，领地不重叠防群殴。
const double kJourneyEndlessBossSpreadMinDist = 700.0;

/// 妖潮期护卫/普通段精英占比：精英为主+少量小怪（0.8=两成小怪保留
/// 割草节奏）；1=全精英。发育期不受此值影响。
const double kJourneyEndlessBossGuardEliteRatio = 0.8;

/// 无尽妖王宝箱掉落概率：妖王潮配额制下妖王数量大，宝箱改为
/// **波内首杀**才掷概率的惊喜（全程期望约 9 箱）；主线据点妖王
/// 保持首杀必掉不受影响。
const double kJourneyEndlessBossChestRate = 0.10;

/// 宝葫（jinjiao）妖潮期每波炼化上限：精英/妖王击杀触发的回血+叠层
/// 共用本配额（超出不触发），防止海量妖王下无限回血/秒满层；
/// 主线与每日不受限。
const int kJourneyEndlessBossRefinePerWave = 2;

/// 无尽模式专属升级需求曲线参数（主线/每日保持 12+7×lv^1.5 不变）：
/// need(lv) = base + per_lv × lv^pow。产出侧三类怪（普通/精英/妖王）
/// 的经验共享同一个波次成长乘区（exp_wave_gain），妖王经验另用独立
/// 基准脱离限血选怪的表值锁死；需求取同阶幂次（pow=1.75），标定=
/// 每波经验池至第 81 波累计覆盖 99 级总需求，波 17 约 17 级。
const double kJourneyEndlessExpBase = 12;
const double kJourneyEndlessExpPerLv = 28;
const double kJourneyEndlessExpPow = 1.75;

/// 无尽波次统一经验成长系数：每波经验池（普通/精英/妖王三类怪的经验
/// 之和）乘 1+该值×(波号−1)，与降幂后的需求曲线同阶；0=还原为不随波
/// 成长（旧口径会卡在 17 波前后）。journey_battle_params.endless 可覆盖。
const double kJourneyExpWaveGain = 0.02;

/// 无尽妖王经验基准：降临妖王的经验不再取被「限血选怪」锁死在低血档
/// 的 exp_drop 表值，改用该独立基准×强度缩放×波次成长乘区，避免
/// 「等级低→只能选低血妖王→经验低→升不动」的负反馈。
const double kJourneyEndlessBossExpBase = 200;

/// 满级后经验累计数值上限：达到角色等级上限后不再升级，经验继续入账，
/// 封顶此值；HUD 分母固定显示文字 max，展示「当前经验/max」，条保持充满。
const double kJourneyPostMaxLevelExpCap = 99999;

/// 妖潮妖王血量每波额外增幅（journey_globals.endless_boss_hp_amp 可覆盖）：
/// 妖潮妖王血量乘区与经验/速度/接触伤害共用乘区解耦，独立走
/// hpBuffMult = 波次 buff ×(1+(波号−起点)×K)，且不吃玩家等级项——
/// 等级项 ×(1+(等级−1)×boss_hp_lv_k) 是主线妖王终盘血量的主力，
/// 叠加进妖潮会把 99 级妖王血量推到基础值 150 倍以上（打不动）；
/// 波次项对标玩家 DPS 成长，终盘妖王单挑 30~70 秒量级，最后几波
/// 满级也需操作。结果仍受 buff_mult_cap 钳制（12）。0=还原共用乘区。
const double kJourneyEndlessBossHpAmp = 0.02;


/// 护甲减伤曲线分母 K：armor/(armor+K)。K 越大同护甲减伤越低，
/// 用于拉开 50~200 护甲档位的区分度（journey_globals.armor_curve_k 可覆盖）。
/// 参考减伤：25 甲≈23.8%、50≈38.5%、100≈55.6%、150≈65.2%、200≈71.4%。
const double kJourneyArmorCurveK = 80.0;

/// 玩家侧护甲减伤上限：单次接触伤害至少保留原值的 40%。
const double kJourneyPlayerArmorCap = 0.60;

/// 怪物侧护甲减伤上限：高于玩家侧，使 150~200 甲档位仍可区分
/// （journey_globals.monster_armor_reduction_cap 可覆盖）。
const double kJourneyMonsterArmorCap = 0.72;

/// 普通怪兜底护甲：journey_monster_params.armor 逐怪覆盖优先。
/// （25 甲 ≈ 23.8% 减伤）
const double kJourneyNormalBaseArmor = 25;

/// 精英怪兜底护甲：妖将定位厚血抗压档。（40 甲 ≈ 33.3% 减伤）
const double kJourneyEliteBaseArmor = 40;

/// 妖王兜底护甲：表内未配 armor 行的妖王回落此值。
const double kJourneyBossArmorFallback = 80;

/// 妖王兜底护甲表（按西游背景定档，50~200 随章节递进；
/// journey_monster_params.armor 逐怪覆盖优先）。
/// 减伤参考（armor/(armor+80)）：50≈38.5%、80≈50%、120≈60%、
/// 160≈66.7%、200≈71.4%（怪物侧钳 ≤72%）。
const Map<String, double> kJourneyBossArmorDefaults = {
  // 五行山~白虎岭（早期妖王 50~65）：寅将军虎皮初甲、黑熊精黑甲皮糙、
  // 黄风怪风怨身轻、白骨精枯骨无肉
  'yin_jiangjun': 55,
  'heixiong_jing': 65,
  'huangfeng_jing': 58,
  'baigu_jing': 50,
  // 宝象国~车迟国（前中期 70~95）：黄袍怪奎木狼天将披甲、金角天庭童子
  // 携法宝、狮猁青狮坐骑、红孩儿幼童妖王、鼍龙龙种鳞甲、虎力道袍虎精、
  // 鹿力白鹿角甲、羊力羚羊精
  'huangpao_guai': 75,
  'jinjiao_dawang': 80,
  'shili_guai': 85,
  'honghaier': 70,
  'tuolong': 95,
  'huli_daxian': 78,
  'luli_daxian': 72,
  'yangli_daxian': 70,
  // 通天河~毒敌山（中期 90~110）：灵感金鱼精鳞甲、独角兕金刚琢护体、
  // 蝎子毒尾轻甲、六耳与悟空同源灵巧
  'linggan_dawang': 92,
  'dujiao_si': 110,
  'xiezi_jing': 96,
  'liuer_mihou': 88,
  // 积雷山~小西天（中后期 105~135）：牛魔王不动如山妖王顶档之一、
  // 九头虫硬壳、十八公古树主干、黄眉弥勒童子肉身、红鳞巨蟒厚鳞
  'niu_mowang': 180,
  'jiutou_chong': 130,
  'shibagong': 120,
  'huangmei_dawang': 105,
  'honglin_mang': 135,
  // 麒麟山~狮驼岭（后期 90~130）：赛太岁金毛犼、百眼蜈蚣甲壳、
  // 大鹏翎羽轻甲极速
  'sai_taishui': 125,
  'baiyan_mojun': 128,
  'dapeng': 90,
  // 比丘国~隐雾山（终盘前 70~100）：白鹿仙鹿轻捷、鼠精灵巧、南山豹子精
  'bailu_jing': 80,
  'laoshu_jing': 72,
  'nanshan_dawang': 100,
  // 竹节山~天竺国（终盘 140~200）：辟寒犀牛精寒甲厚重、九灵元圣九头狮祖
  // 妖王护甲之最、玉兔月宫仙兔
  'pihan_dawang': 140,
  'jiuling_yuansheng': 200,
  'yutu_jing': 76,
};
