part of 'journey_flame_game.dart';

/// 并行攻击单位的数据模型：数值快照与飞行弹体。
/// 与主调度文件同 library，供调度与形态 part 共用。

/// 单个并行单位的当前分级数值快照（升级时由 _refreshAttackUnits 重建）。
class JourneyAttackUnit {
  JourneyAttackUnit({
    required this.code,
    required this.kind,
    this.damage = 0,
    this.intervalMs = 0,
    this.projCount = 1,
    this.valueNum = 0,
    this.pierce = 0,
    this.speed = 0,
    this.aoeRadius = 0,
    this.rangePx = 0,
    this.starterEffect = '',
  });

  final String code;
  final String kind;
  final double damage;
  final double intervalMs;
  final int projCount;
  final double valueNum;
  final int pierce;
  final double speed;
  final double aoeRadius;
  final double rangePx;

  /// 法宝初始特效槽（knockback/burn/lifesteal/pierce）：并行命中沿用该
  /// 特效，保证非出战法宝的初始特性不因脱离环绕维度槽而丢失。
  final String starterEffect;

  /// 发射/扫击计时器，归零触发并重置；无目标时回退到阈值前 1s 重试。
  double timer = 0;
}

/// 飞行弹体：projectile 穿透 / boomerang 去回程；world 坐标驱动。
class JourneyAttackShot {
  JourneyAttackShot({
    required this.unit,
    required this.pos,
    required this.dir,
    required this.speed,
    required this.range,
    required this.pierce,
    required this.boomerang,
    required this.lifeSec,
  });

  /// 所属单位：升级刷新后按 code 重绑到新数值快照，保证飞行中弹体用新伤害。
  JourneyAttackUnit unit;
  Vector2 pos;
  final Vector2 dir;
  final double speed;
  final double range;
  final int pierce;
  final bool boomerang;

  /// 剩余存在时间（秒）：逐帧扣减，归零即销毁，防止异常射程/速度配置下
  /// 弹体滞留。初值取后台 attack_shot_life_sec，缺省 8 秒。
  double lifeSec;

  double traveled = 0;
  bool returning = false;
  int hits = 0;
  final Set<JourneyMonsterComponent> hitSet = <JourneyMonsterComponent>{};
}
