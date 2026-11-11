part of 'journey_flame_game.dart';

/// 接触判定保留的重叠量：怪物停在接触边界内 2 单位，保证节拍伤害照常结算。
const double kJourneyContactOverlap = 2.0;

/// 怪物不得进入角色武器环带内圈：最小距取接触边界（玩家半径 + 怪半径），
/// 该值恒大于内圈半径，同时满足 dist <= 怪半径 + 玩家半径 的接触判定。
void clampMonsterOutOfInnerCircle(
  JourneyMonsterComponent monster,
  Vector2 playerPos,
) {
  final minDist = monster.radius +
      JourneyPlayerComponent._radius -
      kJourneyContactOverlap;
  final delta = monster.position - playerPos;
  final len = delta.length;
  if (len >= minDist) return;
  monster.position = len > 0.01
      ? playerPos + delta.normalized() * minDist
      : playerPos + Vector2(minDist, 0);
}

/// 位置钳进世界边界（推开/约束后统一调用，防越界）。
void clampMonsterToWorld(JourneyMonsterComponent monster, double worldSize) {
  monster.position.x =
      monster.position.x.clamp(monster.radius, worldSize - monster.radius);
  monster.position.y =
      monster.position.y.clamp(monster.radius, worldSize - monster.radius);
}
