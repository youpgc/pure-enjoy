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
