part of 'journey_flame_game.dart';

/// 妖王大血条统一同步：每帧在实体与伤害结算后调用一次。
/// 横幅按入列先后自上而下排列：新进妖王从队尾（下方）加入，在列妖王位置
/// 保持稳定，仅当上方横幅被移除时才顺位上移。最多三条；满额时按优先级
/// 淘汰最弱的一条，同批进场的妖王之间按优先级决定上下顺序。

/// 同屏大血条上限。
const int _kBossBarMax = 3;

/// 距离同档粒度（世界单位）：差距落在同档的妖王视为距离相当，改由交战
/// 先后定优先级。同批排序与满额顶替共用这一把尺子，不再各设阈值。
const double _kBossBarDistTier = 24;

void syncBossHud(JourneyFlameGame game) {
  final hud = game.controller.hud;
  final tracked = game.hudTrackedBosses;
  final playerPos = game.player.position;

  // 退场口：倒下、已离场，或脱战且回满——回血未满者暂留以播放增长动画。
  tracked.removeWhere((m) =>
      m.isDead ||
      !game.monsters.any((o) => identical(o, m)) ||
      (!m._aggro && m.hp >= m.maxHp));

  // 新进妖王：在场、满足展示条件且尚未入列者，按优先级降序排队入场。
  final incoming = <JourneyMonsterComponent>[];
  for (final m in game.monsters) {
    if (m.isDead || !m.model.isBoss) continue;
    if (!m._aggro && m.hp >= m.maxHp) continue;
    if (tracked.any((t) => identical(t, m))) continue;
    incoming.add(m);
  }
  if (incoming.isNotEmpty) {
    incoming.sort((a, b) => _bossBarPriority(b, a, playerPos));
    for (final m in incoming) {
      if (tracked.length >= _kBossBarMax) {
        // 满额：先找队列里优先级最低的一条；新妖须严格更优先才顶替，
        // 与同批入场排序共用同一判据（交战态 > 距离档 > 最新交战）。
        var weakAt = 0;
        for (var i = 1; i < tracked.length; i++) {
          if (_bossBarPriority(tracked[i], tracked[weakAt], playerPos) < 0) {
            weakAt = i;
          }
        }
        if (_bossBarPriority(m, tracked[weakAt], playerPos) <= 0) continue;
        tracked.removeAt(weakAt);
      }
      // 一律追加队尾：新进从下方入列，在列妖王的横幅位置不受影响。
      tracked.add(m);
    }
  }

  // 展示快照：仅在数值/成员/顺序变化时写 notifier，避免逐帧重建横幅。
  final bars = <JourneyBossHudBar>[
    for (final m in tracked)
      JourneyBossHudBar(
        key: m,
        name: m.model.name,
        ratio: (m.hp / m.maxHp).clamp(0.0, 1.0),
        hp: m.hp.clamp(0.0, m.maxHp).round(),
        maxHp: m.maxHp.round(),
      ),
  ];
  if (!_sameBossBars(hud.bossBars.value, bars)) {
    hud.bossBars.value = bars;
  }
}

/// 优先级：交战态高于脱战回血；距离按档量化，更近档优先；同档按交战
/// 先后定高下（越新越优先）。返回正数表示 [a] 排在 [b] 之前。同一判据
/// 供同批排序与满额顶替共用，避免两处各设阈值造成口径漂移。
int _bossBarPriority(
  JourneyMonsterComponent a,
  JourneyMonsterComponent b,
  Vector2 playerPos,
) {
  if (a._aggro != b._aggro) return a._aggro ? 1 : -1;
  final daTier = ((a.position - playerPos).length / _kBossBarDistTier).floor();
  final dbTier = ((b.position - playerPos).length / _kBossBarDistTier).floor();
  if (daTier != dbTier) return daTier < dbTier ? 1 : -1;
  return a.lastEngageSeq.compareTo(b.lastEngageSeq);
}

/// 快照逐项比较：比例留容差，避免逐帧微小浮点抖动触发重建。
bool _sameBossBars(List<JourneyBossHudBar> a, List<JourneyBossHudBar> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (!identical(x.key, y.key) ||
        x.name != y.name ||
        x.hp != y.hp ||
        x.maxHp != y.maxHp ||
        (x.ratio - y.ratio).abs() > 0.005) {
      return false;
    }
  }
  return true;
}
