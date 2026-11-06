part of 'journey_flame_game.dart';

/// 小地图采样（节点11，自主文件拆出控制主文件行数）。
extension JourneyMinimapSampling on JourneyFlameGame {
  /// 0.25s 采样一次：怪取相对玩家偏移 ≤1000 的前 60 只；妖王在范围内带
  /// 实际偏移，超范围用 bearing 方向 ×1000 近似点（保证骷髅常显）；
  /// 无变化不写 notifier（HUD 直读零 setState）。
  void _sampleMinimap(double dt) {
    _minimapTimer -= dt;
    if (_minimapTimer > 0) return;
    _minimapTimer = 0.25;
    final center = player.position;
    final hud = controller.hud;
    const span = 1000.0;
    final offsets = <Vector2>[];
    for (final m in monsters) {
      if (m.isDead || identical(m, boss)) continue;
      final d = m.position - center;
      if (d.length2 <= span * span) {
        offsets.add(d);
        if (offsets.length >= 60) break;
      }
    }
    Vector2? bossOffset;
    final b = boss;
    if (bossModel != null) {
      if (b != null && !b.isDead) {
        final d = b.position - center;
        if (d.length <= span) bossOffset = d.clone();
      }
      // 超范围近似点：罗盘 bearing 方向 × span（恒显示在窗缘指方向）
      bossOffset ??= Vector2(
        math.cos(hud.bearing.value),
        math.sin(hud.bearing.value),
      ) * span;
    }
    final next = JourneyMinimapData(
      playerPos: center.clone(),
      bossPos: bossOffset,
      monsterOffsets: offsets,
    );
    final prev = hud.minimap.value;
    if (prev != null && sameMinimap(prev, next)) return;
    hud.minimap.value = next;
  }

  /// 无变化判定：怪数/boss 点/全部怪偏移均在 0.5px 阈值内视为未变。
  static bool sameMinimap(JourneyMinimapData a, JourneyMinimapData b) {
    if (a.monsterOffsets.length != b.monsterOffsets.length) return false;
    final ab = a.bossPos;
    final bb = b.bossPos;
    if ((ab == null) != (bb == null)) return false;
    if (ab != null && bb != null && (ab - bb).length2 > 0.25) return false;
    for (var i = 0; i < a.monsterOffsets.length; i++) {
      if ((a.monsterOffsets[i] - b.monsterOffsets[i]).length2 > 0.25) {
        return false;
      }
    }
    return true;
  }
}
