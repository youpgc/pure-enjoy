part of 'journey_flame_game.dart';

/// 掉落与拾取：击杀产出（香火=经验/功德铜钱/蟠桃/宝箱 + 后期分档
/// 妖丹=大经验/灵珠=大治疗/功德金锭=大额功德），磁吸拾取。
enum JourneyPickupKind { exp, meritCoin, peach, chest, yaodan, lingzhu, jinding }

class JourneyPickupComponent extends PositionComponent {
  JourneyPickupComponent({
    required this.game,
    required this.kind,
    required super.position,
    required this.value,
  }) : _radius = kind == JourneyPickupKind.chest || kind == JourneyPickupKind.jinding
            ? 13
            : 8;

  final JourneyFlameGame game;
  final JourneyPickupKind kind;

  /// 拾取价值（可变：对象池复用时重置，见 JourneyLootMixin._spawnPickup）。
  int value;

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

  /// 拾取结算（对象池，节点12）：效果入账后移出父级并入池（复用时 reset）。
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
        // 宝箱流水线（§6 炼化/额外三选一/功德兜底）
        game.handleChestCollected();
        break;
      case JourneyPickupKind.yaodan:
        game.gainExp(value.toDouble());
        break;
      case JourneyPickupKind.lingzhu:
        game.player.heal(value.toDouble());
        break;
      case JourneyPickupKind.jinding:
        game.addMeritCoins(value);
        break;
    }
    game._recyclePickup(this);
  }

  @override
  void render(Canvas canvas) {
    // 精灵优先（pickup_<kind>.svg，48 视箱）；失败回落色块
    final spriteKey = switch (kind) {
      JourneyPickupKind.exp => 'xianghuo',
      JourneyPickupKind.meritCoin => 'coin',
      JourneyPickupKind.peach => 'peach',
      JourneyPickupKind.chest => 'chest',
      JourneyPickupKind.yaodan => 'yaodan',
      JourneyPickupKind.lingzhu => 'lingzhu',
      JourneyPickupKind.jinding => 'jinding',
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
        JourneyPickupKind.yaodan => const Color(0xFF6C4BD5),
        JourneyPickupKind.lingzhu => const Color(0xFF5BC4B0),
        JourneyPickupKind.jinding => const Color(0xFFE8A83E),
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
  /// 拾取物对象池（节点12 性能）：按 kind 回收复用，避免高频掉落实例化
  /// 抖动。池随对局实例存在（game 引用绑定单局，跨局不串）。
  final Map<JourneyPickupKind, List<JourneyPickupComponent>> _pickupPool =
      <JourneyPickupKind, List<JourneyPickupComponent>>{};

  /// 统一生成入口：池空新建，池非空取尾复用（reset 位置/数值后重新挂载）。
  void _spawnPickup(
    JourneyFlameGame game,
    JourneyPickupKind kind,
    Vector2 pos,
    int value,
  ) {
    final pool =
        (_pickupPool[kind] ??= <JourneyPickupComponent>[]);
    final reused = pool.isNotEmpty ? pool.removeLast() : null;
    final p = reused
      ?? JourneyPickupComponent(
          game: game,
          kind: kind,
          position: pos,
          value: value,
        );
    if (reused != null) {
      p
        ..position = pos
        ..value = value;
    }
    game.pickups.add(p);
    game.world.add(p);
  }

  /// 回收入池：移出父级（主 update 的未挂载过滤会将其移出 pickups 列表）。
  void _recyclePickup(JourneyPickupComponent p) {
    p.removeFromParent();
    (_pickupPool[p.kind] ??= <JourneyPickupComponent>[]).add(p);
  }

  /// 击杀掉落（journey_drops 表驱动）：boss/精英/普通分表加权随机；
  /// 空表回落内置硬编码概率口径（香火必掉/铜钱 35%/蟠桃 4%）。
  /// 精英/妖王宝箱固定掉落由 monster_elite/monster_boss 表承接。
  void spawnLoot(JourneyFlameGame game, JourneyMonsterComponent m) {
    // 掉落分档：21+ 难切换 late 表（高价值拾取物权重上调）；
    // late 表缺行回落基础表（老配置不炸）。
    final base = m.model.isBoss
        ? 'monster_boss'
        : m.model.isElite
            ? 'monster_elite'
            : 'monster_normal';
    final isLateTier = game.level.levelNo > 20;
    final table = game.config?.dropTableOf(isLateTier ? '${base}_late' : base) ??
        const <JourneyDropModel>[];
    final effective =
        table.isNotEmpty ? table : game.config?.dropTableOf(base) ?? const <JourneyDropModel>[];
    if (effective.isNotEmpty) {
      _rollDropTable(game, effective, m.position.clone());
      return;
    }

    // 兜底口径（掉落表未就绪时保持可玩）
    void drop(JourneyPickupKind kind, int value) {
      _spawnPickup(
        game,
        kind,
        m.position.clone() +
            Vector2(
              (game.rng.nextDouble() - 0.5) * 24,
              (game.rng.nextDouble() - 0.5) * 24,
            ),
        value,
      );
    }

    drop(JourneyPickupKind.exp, m.model.expDrop);
    if (game.rng.nextDouble() < 0.35) {
      drop(JourneyPickupKind.meritCoin, 3 + game.level.levelNo ~/ 2);
    }
    if (game.rng.nextDouble() < 0.04) {
      drop(JourneyPickupKind.peach, 25);
    }
    // 兜底口径对齐远端掉落表：精英/妖王固定掉宝箱（monster_elite/boss 表行）
    if (m.model.isElite || m.model.isBoss) {
      drop(JourneyPickupKind.chest, 15);
    }
  }
}

/// 掉落表加权随机：weight=0 行跳过；pickup_code 空=什么都不掉；
/// 命中后按 pickup 编码映射生成拾取物（值=单价×随机数量）。
void _rollDropTable(
  JourneyFlameGame game,
  List<JourneyDropModel> table,
  Vector2 pos,
) {
  var total = 0;
  for (final d in table) {
    if (d.weight > 0) total += d.weight;
  }
  if (total <= 0) return;
  var roll = game.rng.nextInt(total);
  JourneyDropModel? hit;
  for (final d in table) {
    if (d.weight <= 0) continue;
    if (roll < d.weight) {
      hit = d;
      break;
    }
    roll -= d.weight;
  }
  final code = hit?.pickupCode;
  if (code == null || code.isEmpty) return;
  final qtyMin = hit!.qtyMin < 0 ? 0 : hit.qtyMin;
  final qtyMax = hit.qtyMax < qtyMin ? qtyMin : hit.qtyMax;
  final qty = qtyMin + game.rng.nextInt(qtyMax - qtyMin + 1);
  if (qty <= 0) return; // 误配 0/0 行：不生成 0 价值拾取物
  _spawnPickupByCode(game, code, pos, qty);
}

/// pickup 编码映射（drops 的 pickup_code → 拾取物）：
/// xianghuo=香火(经验) / gongde_tongqian=功德铜钱 / pantao_pickup=蟠桃 /
/// baoxiang=宝箱 / yaodan=妖丹(大经验) / lingzhu=灵珠(大治疗) /
/// jinding=功德金锭(大额功德)；未知编码不生成。
void _spawnPickupByCode(
  JourneyFlameGame game,
  String code,
  Vector2 pos,
  int qty,
) {
  final kind = switch (code) {
    'xianghuo' => JourneyPickupKind.exp,
    'gongde_tongqian' => JourneyPickupKind.meritCoin,
    'pantao_pickup' => JourneyPickupKind.peach,
    'baoxiang' => JourneyPickupKind.chest,
    'yaodan' => JourneyPickupKind.yaodan,
    'lingzhu' => JourneyPickupKind.lingzhu,
    'jinding' => JourneyPickupKind.jinding,
    _ => null,
  };
  if (kind == null) return;
  // 值=单价×数量；单价优先 pickupConfigOf，缺省回落现有数值
  final unit = game.config?.pickupConfigOf(code)?.value ??
      switch (kind) {
        JourneyPickupKind.exp => 1,
        JourneyPickupKind.meritCoin => 3,
        JourneyPickupKind.peach => 15,
        JourneyPickupKind.chest => 0,
        JourneyPickupKind.yaodan => 30,
        JourneyPickupKind.lingzhu => 80,
        JourneyPickupKind.jinding => 30,
      };
  game._spawnPickup(
    game,
    kind,
    pos +
        Vector2(
          (game.rng.nextDouble() - 0.5) * 24,
          (game.rng.nextDouble() - 0.5) * 24,
        ),
    unit * qty,
  );
}
