/// 西行·难度曲线内置兜底值。
///
/// 运营数值由管理后台在 journey_globals 编辑保存；本文件只在列未部署或
/// 行未填值时提供保底，保证对局可玩且强度有界。
library;

/// 局内强度每分钟增长斜率（journey_globals.buff_time_slope 可覆盖）。
/// 时间项与关卡项分离，难号不在时间斜率中重复计入。
const double kJourneyBuffTimeSlope = 0.30;

/// 每点关卡难度的强度乘区增量（journey_globals.buff_level_mult 可覆盖）。
const double kJourneyBuffLevelMult = 0.04;

/// 生效强度乘区上限（journey_globals.buff_mult_cap 可覆盖）：
/// 波次倍率、妖王阶段倍率等叠加源在怪物生成时统一钳到此值。
const double kJourneyBuffMultCap = 6.0;

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
  // 携法宝、狮猁青狮坐骑、红孩儿幼童妖王、鼍龙龙种鳞甲、虎力道袍虎精
  'huangpao_guai': 75,
  'jinjiao_dawang': 80,
  'shili_guai': 85,
  'honghaier': 70,
  'tuolong': 95,
  'huli_daxian': 78,
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
