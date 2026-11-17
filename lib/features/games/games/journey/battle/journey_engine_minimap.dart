part of 'journey_flame_game.dart';

/// 小地图采样：怪点取相对玩家偏移，妖王大红点覆盖全部存活妖王
/// （主线据点妖王 + 妖王潮多妖王同源采样），无妖王时不画。
extension JourneyMinimapSampling on JourneyFlameGame {
  /// 0.25s 采样一次：怪取相对玩家偏移 ≤1000 的前 60 只；妖王逐只采样
  /// （范围内带实际偏移，超范围按妖王自身方位贴窗缘示方向）；主线据点
  /// 妖王清剿后不画；无变化不写 notifier（HUD 直读零 setState）。
  void _sampleMinimap(double dt) {
    _minimapTimer -= dt;
    if (_minimapTimer > 0) return;
    _minimapTimer = 0.25;
    final center = player.position;
    final hud = controller.hud;
    const span = 1000.0;
    final offsets = <Vector2>[];
    final bossOffsets = <Vector2>[];
    for (final m in monsters) {
      if (m.isDead) continue;
      final d = m.position - center;
      final inRange = d.length2 <= span * span;
      if (m.model.isBoss) {
        // 妖王大红点：存活即画；超范围按妖王自身相对玩家的方位贴窗缘
        // 示方向。不用罗盘 bearing——无尽模式无据点妖王，bearing 恒为 0，
        // 会把所有超距妖王钉在窗右缘；多妖王也需各自方位而非同一方向。
        bossOffsets.add(
          inRange
              ? d.clone()
              : d.normalized() * span,
        );
        continue;
      }
      if (inRange) {
        offsets.add(d);
        if (offsets.length >= 60) break;
      }
    }
    final next = JourneyMinimapData(
      playerPos: center.clone(),
      bossPositions: bossOffsets,
      monsterOffsets: offsets,
    );
    final prev = hud.minimap.value;
    if (prev != null && sameMinimap(prev, next)) return;
    hud.minimap.value = next;
  }

  /// 无变化判定：怪数/妖王点/全部怪偏移均在 0.5px 阈值内视为未变。
  static bool sameMinimap(JourneyMinimapData a, JourneyMinimapData b) {
    if (a.monsterOffsets.length != b.monsterOffsets.length) return false;
    if (a.bossPositions.length != b.bossPositions.length) return false;
    for (var i = 0; i < a.bossPositions.length; i++) {
      if ((a.bossPositions[i] - b.bossPositions[i]).length2 > 0.25) {
        return false;
      }
    }
    for (var i = 0; i < a.monsterOffsets.length; i++) {
      if ((a.monsterOffsets[i] - b.monsterOffsets[i]).length2 > 0.25) {
        return false;
      }
    }
    return true;
  }
}
