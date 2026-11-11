/// 西行·角色成长与妖王血量内置兜底值。
///
/// 运营数值由管理后台在 journey_globals 编辑保存；本文件只在列未部署或
/// 行未填值时提供保底，保证对局可玩且强度有界。
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
