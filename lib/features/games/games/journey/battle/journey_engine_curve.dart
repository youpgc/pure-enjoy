part of 'journey_flame_game.dart';

/// 局内强度乘区与难度曲线参数：时间斜率与关卡乘区分离，难号只在关卡项
/// 计入一次；结果钳到统一上限，避免长时对局数值无界增长。
extension JourneyCurve on JourneyFlameGame {
  double get buffMult => math.min(
        (1.0 + (_elapsed / 60.0) * buffTimeSlope) * levelMult,
        buffMultCap,
      );

  /// 关卡难度乘区：difficulty 由关卡配置驱动，每点系数由全局参数驱动。
  double get levelMult => 1.0 + level.difficulty * buffLevelMult;

  /// 局内强度每分钟增长斜率（后台列，缺省走内置兜底）。
  double get buffTimeSlope =>
      config?.buffTimeSlope ?? kJourneyBuffTimeSlope;

  /// 每点关卡难度的乘区增量。
  double get buffLevelMult =>
      config?.buffLevelMult ?? kJourneyBuffLevelMult;

  /// 生效强度乘区上限。
  double get buffMultCap => config?.buffMultCap ?? kJourneyBuffMultCap;

  /// 怪物最终移速上限（px/s）。
  double get monsterSpeedCap =>
      config?.monsterSpeedCap ?? kJourneyMonsterSpeedCap;

  /// 妖王血量乘区：只随局内时间增长，不含关卡难度项。
  double get bossHpBuffMult =>
      1.0 + (_elapsed / 60.0) * buffTimeSlope * bossHpTimeK;

  /// 妖王血量时间项系数（后台列，缺省走内置兜底）。
  double get bossHpTimeK => config?.bossHpTimeK ?? kJourneyBossHpTimeK;

  /// 妖王接触伤害的玩家等级成长系数（后台列，缺省走内置兜底）。
  double get bossDamageLvK => config?.bossDamageLvK ?? kJourneyBossDamageLvK;
}

/// 怪物生成时统一钳制生效乘区：波次倍率、妖王阶段倍率等叠加源都不得
/// 突破全局上限，怪物血量/速度/接触伤害共用同一基数。
double clampJourneyBuff(JourneyFlameGame game, double raw) =>
    math.min(raw, game.buffMultCap);

/// 钳制后的怪物移速：能力倍率计入后仍受全局上限约束；妖王冲撞爆发
/// 以该值为基数按比例放大，不再叠加无界的乘区结果。
double cappedMonsterSpeed(JourneyMonsterComponent monster) => math.min(
      monster._speed * monster._speedMult,
      monster.game.monsterSpeedCap,
    );

/// 钳制后的缓速移速（收招/归位）：保持原有 0.4 倍关系，仅加上限。
double cappedMonsterSlowSpeed(JourneyMonsterComponent monster) => math.min(
      monster._speed * 0.4,
      monster.game.monsterSpeedCap,
    );
