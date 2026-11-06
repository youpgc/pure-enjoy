part of 'journey_flame_game.dart';

/// 均匀空间哈希网格（节点12 性能）：cell 160，每帧重建一次；
/// 武器扇形判定/接触伤害只查询玩家附近候选，避免 monsterCap 全量遍历。
/// 世界坐标恒 ≥0（实体被边界钳制），格键无碰撞。
class JourneySpatialGrid {
  static const double cellSize = 160;

  /// 格桶（键=cx*100000+cy，cy 上限远小于 100000，无碰撞）。
  final Map<int, List<JourneyMonsterComponent>> _cells =
      <int, List<JourneyMonsterComponent>>{};

  /// 帧首重建：死亡怪不入格（消费方另有 isDead 过滤，双保险）。
  void rebuild(List<JourneyMonsterComponent> monsters) {
    _cells.clear();
    for (final m in monsters) {
      if (m.isDead) continue;
      (_cells[_keyOf(m.position)] ??= <JourneyMonsterComponent>[]).add(m);
    }
  }

  /// 圆形范围查询：覆盖 [center±radius] 的所有格桶并集
  /// （每实体恰在一个桶，无需去重）。
  List<JourneyMonsterComponent> queryRange(Vector2 center, double radius) {
    final minCx = ((center.x - radius) ~/ cellSize).clamp(0, 1 << 20);
    final maxCx = ((center.x + radius) ~/ cellSize).clamp(0, 1 << 20);
    final minCy = ((center.y - radius) ~/ cellSize).clamp(0, 1 << 20);
    final maxCy = ((center.y + radius) ~/ cellSize).clamp(0, 1 << 20);
    final result = <JourneyMonsterComponent>[];
    for (var cx = minCx; cx <= maxCx; cx++) {
      for (var cy = minCy; cy <= maxCy; cy++) {
        final bucket = _cells[cx * 100000 + cy];
        if (bucket != null) result.addAll(bucket);
      }
    }
    return result;
  }

  int _keyOf(Vector2 p) => (p.x ~/ cellSize) * 100000 + (p.y ~/ cellSize);
}
