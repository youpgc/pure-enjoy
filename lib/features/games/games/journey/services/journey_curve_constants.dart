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
