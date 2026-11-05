part of 'journey_flame_game.dart';

/// 掉落与拾取：击杀产出（香火=经验/功德铜钱/蟠桃/宝箱），磁吸拾取。
enum JourneyPickupKind { exp, meritCoin, peach, chest }

class JourneyPickupComponent extends PositionComponent {
  JourneyPickupComponent({
    required this.game,
    required this.kind,
    required super.position,
    required this.value,
  }) : _radius = kind == JourneyPickupKind.chest ? 13 : 8;

  final JourneyFlameGame game;
  final JourneyPickupKind kind;
  final int value;
  final double _radius;

  @override
  void update(double dt) {
    super.update(dt);
    if (game._ended) return;
    final player = game.player;
    final to = player.position - position;
    final dist = to.length;

    // 磁吸：进入拾取范围后飞向玩家
    if (dist < player.pickupRange) {
      final speed = 180 + (player.pickupRange - dist) * 3;
      if (dist > 1) {
        position += to.normalized() * speed * dt;
      }
    }
    if (dist < 20) {
      _collect();
    }
  }

  void _collect() {
    switch (kind) {
      case JourneyPickupKind.exp:
        game.gainExp(value.toDouble());
        break;
      case JourneyPickupKind.meritCoin:
        game.addMeritCoins(value);
        break;
      case JourneyPickupKind.peach:
        game.player.heal(value.toDouble());
        break;
      case JourneyPickupKind.chest:
        // 宝箱流水线（炼化确认弹窗）在后续迭代接入；先按铜钱兜底口径产出
        game.addMeritCoins(value);
        break;
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // 精灵优先（pickup_<kind>.svg，48 视箱）；失败回落色块
    final spriteKey = switch (kind) {
      JourneyPickupKind.exp => 'xianghuo',
      JourneyPickupKind.meritCoin => 'coin',
      JourneyPickupKind.peach => 'peach',
      JourneyPickupKind.chest => 'chest',
    };
    final pic = JourneySprites.get(JourneySprites.pickup(spriteKey));
    if (pic != null) {
      final size = _radius * 2.4;
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
          center: Offset.zero,
          width: size,
          height: size,
        ),
        srcWidth: 48,
        srcHeight: 48,
      );
      return;
    }
    final paint = Paint()
      ..color = switch (kind) {
        JourneyPickupKind.exp => const Color(0xFF9C7BD5),
        JourneyPickupKind.meritCoin => const Color(0xFFE8C470),
        JourneyPickupKind.peach => const Color(0xFFD4593F),
        JourneyPickupKind.chest => const Color(0xFFB98F3E),
      };
    canvas.drawCircle(Offset.zero, _radius, paint);
    if (kind == JourneyPickupKind.chest) {
      canvas.drawCircle(
        Offset.zero,
        _radius + 3,
        Paint()
          ..color = const Color(0xFFE8C470)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }
}

mixin JourneyLootMixin {
  /// 击杀掉落：香火必掉；铜钱 35%；蟠桃 4%；精英/妖王加宝箱（暂按铜钱兜底）。
  void spawnLoot(JourneyFlameGame game, JourneyMonsterComponent m) {
    void drop(JourneyPickupKind kind, int value) {
      final p = JourneyPickupComponent(
        game: game,
        kind: kind,
        position: m.position.clone() +
            Vector2(
              (game.rng.nextDouble() - 0.5) * 24,
              (game.rng.nextDouble() - 0.5) * 24,
            ),
        value: value,
      );
      game.pickups.add(p);
      game.world.add(p);
    }

    drop(JourneyPickupKind.exp, m.model.expDrop);
    if (game.rng.nextDouble() < 0.35) {
      drop(JourneyPickupKind.meritCoin, 3 + game.level.levelNo ~/ 2);
    }
    if (game.rng.nextDouble() < 0.04) {
      drop(JourneyPickupKind.peach, 25);
    }
    if (m.model.isElite || m.model.isBoss) {
      drop(JourneyPickupKind.chest, 15);
    }
  }
}
