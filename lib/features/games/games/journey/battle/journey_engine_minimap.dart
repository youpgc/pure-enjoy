part of 'journey_flame_game.dart';

/// 小地图采样：怪点取相对玩家偏移，妖王点只在已降临且存活时绘制。
extension JourneyMinimapSampling on JourneyFlameGame {
  /// 0.25s 采样一次：怪取相对玩家偏移 ≤1000 的前 60 只；妖王仅已降临
  /// 且存活时绘制，范围内带实际偏移、超范围按 bearing 方向贴窗缘；
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
    // 妖王点只在已降临且存活时绘制：未降临（延迟计时中）与清剿后
    // 均置 null，避免窗缘常显一个并不存在的方向标记。
    if (b != null && !b.isDead && !_bossDefeated) {
      final d = b.position - center;
      bossOffset = d.length <= span
          ? d.clone()
          : Vector2(
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
