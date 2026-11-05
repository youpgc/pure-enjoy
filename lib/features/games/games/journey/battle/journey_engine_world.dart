part of 'journey_flame_game.dart';

/// 世界背景（平铺大地图版）：均匀宣纸底色 + 全图散布的远山/祥云/石碑
/// （确定性 seed 生成一次，渲染只画视口内元素）+ 关卡配置参照物
/// （journey_map_objects，kind 着色）+ 妖王据点妖气结界 + 四边墨色界线。
class JourneyWorldBackground extends Component {
  JourneyWorldBackground({
    required this.worldSize,
    required this.themeColor,
    required this.seed,
    required this.bossPos,
    this.mapObjects = const <JourneyMapObjectModel>[],
  });

  final double worldSize;
  final String themeColor;
  final int seed;
  final Vector2 bossPos;

  /// 关卡配置的地图参照物（后台 journey_map_objects 维护）。
  final List<JourneyMapObjectModel> mapObjects;

  Color get _theme {
    final hex = themeColor.replaceAll('#', '');
    if (hex.length == 7) {
      try {
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFB07C3C);
  }

  /// 全图散布装饰（山丘=三峰剪影 / 云 / 石碑），按密度随地图规模生成。
  late final List<_HillDeco> _hills = _buildHills();
  late final List<_CloudDeco> _clouds = _buildClouds();
  late final List<_MarkerDeco> _markers = _buildMarkers();

  List<_HillDeco> _buildHills() {
    final rng = math.Random(seed * 7 + 1);
    final hills = <_HillDeco>[];
    // 每 ~900² 一座山丘，全图均匀散布（出生点半径 320 内不放，避免遮挡）
    final count = (worldSize * worldSize / 810000).round();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * worldSize;
      final y = rng.nextDouble() * worldSize;
      if ((Offset(x, y) - bossPos.toOffset()).distance < 420) continue;
      hills.add(_HillDeco(
        center: Offset(x, y),
        scale: 0.8 + rng.nextDouble() * 1.1,
        shade: rng.nextInt(3),
      ));
    }
    return hills;
  }

  List<_CloudDeco> _buildClouds() {
    final rng = math.Random(seed * 13 + 2);
    final clouds = <_CloudDeco>[];
    final count = (worldSize * worldSize / 1400000).round();
    for (var i = 0; i < count; i++) {
      clouds.add(_CloudDeco(
        center: Offset(rng.nextDouble() * worldSize,
            rng.nextDouble() * worldSize),
        scale: 0.7 + rng.nextDouble() * 0.8,
      ));
    }
    return clouds;
  }

  List<_MarkerDeco> _buildMarkers() {
    final rng = math.Random(seed * 31 + 3);
    final markers = <_MarkerDeco>[];
    final count = (worldSize * worldSize / 3600000).round();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * worldSize;
      final y = rng.nextDouble() * worldSize;
      if ((Offset(x, y) - bossPos.toOffset()).distance < 420) continue;
      markers.add(_MarkerDeco(
        center: Offset(x, y),
        isPagoda: rng.nextBool(),
      ));
    }
    return markers;
  }

  @override
  void render(Canvas canvas) {
    final visible = _visibleRect();
    final vp = visible ??
        Rect.fromLTWH(0, 0, worldSize, worldSize);

    // ---- 底色：宣纸暖色（均匀平铺） ----
    canvas.drawRect(
      Rect.fromLTWH(0, 0, worldSize, worldSize),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: <Color>[
            Color.lerp(_theme, const Color(0xFFF6EDD6), 0.62)!,
            Color.lerp(_theme, const Color(0xFFE3CC9C), 0.42)!,
          ],
        ).createShader(vp),
    );

    // ---- 远山剪影（只画视口内）----
    final hillShades = <Color>[
      Color.lerp(_theme, const Color(0xFF8A6A4A), 0.45)!.withValues(alpha: 0.42),
      Color.lerp(_theme, const Color(0xFF6E4E33), 0.5)!.withValues(alpha: 0.55),
      Color.lerp(_theme, const Color(0xFF4A3220), 0.55)!.withValues(alpha: 0.7),
    ];
    for (final h in _hills) {
      if (h.center.dx < vp.left - 260 ||
          h.center.dx > vp.right + 260 ||
          h.center.dy < vp.top - 200 ||
          h.center.dy > vp.bottom + 200) {
        continue;
      }
      _drawHill(canvas, h, hillShades[h.shade]);
    }

    // ---- 祥云（鎏金勾线，只画视口内）----
    final cloudPaint = Paint()
      ..color = const Color(0xFF8A6A3A).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final c in _clouds) {
      if (c.center.dx < vp.left - 160 ||
          c.center.dx > vp.right + 160 ||
          c.center.dy < vp.top - 80 ||
          c.center.dy > vp.bottom + 80) {
        continue;
      }
      final s = c.scale;
      canvas.drawOval(
          Rect.fromCenter(
              center: c.center, width: 120 * s, height: 22 * s),
          cloudPaint);
      canvas.drawOval(
          Rect.fromCenter(
              center: c.center.translate(-30 * s, -12 * s),
              width: 70 * s,
              height: 16 * s),
          cloudPaint);
      canvas.drawOval(
          Rect.fromCenter(
              center: c.center.translate(34 * s, -10 * s),
              width: 60 * s,
              height: 15 * s),
          cloudPaint);
    }

    // ---- 里程碑石碑/驿亭（视口裁剪）----
    for (final m in _markers) {
      if (m.center.dx < vp.left - 140 ||
          m.center.dx > vp.right + 140 ||
          m.center.dy < vp.top - 100 ||
          m.center.dy > vp.bottom + 100) {
        continue;
      }
      _drawMarker(canvas, m);
    }

    // ---- 关卡参照物（journey_map_objects 配置，kind 着色圆斑）----
    for (final o in mapObjects) {
      final c = Offset(o.x, o.y);
      if (c.dx < vp.left - o.radius - 40 ||
          c.dx > vp.right + o.radius + 40 ||
          c.dy < vp.top - o.radius - 40 ||
          c.dy > vp.bottom + o.radius + 40) {
        continue;
      }
      _drawMapObject(canvas, o, c);
    }

    // ---- 妖王据点：妖气结界（暗红双环 + 内圈妖纹）----
    final boss = bossPos.toOffset();
    final zoneIn =
        vp.inflate(60).contains(boss) || vp.contains(boss);
    if (zoneIn) {
      final ring = Paint()
        ..color = const Color(0x668E2F3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawCircle(boss, 150, ring);
      canvas.drawCircle(
        boss,
        170,
        Paint()
          ..color = const Color(0x338E2F3C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        boss,
        150,
        Paint()..color = const Color(0x148E2F3C),
      );
      // 四向妖纹短线
      final tick = Paint()
        ..color = const Color(0x998E2F3C)
        ..strokeWidth = 4;
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + math.pi / 4;
        canvas.drawLine(
          boss +
              Offset(math.cos(a), math.sin(a)) * 130,
          boss +
              Offset(math.cos(a), math.sin(a)) * 146,
          tick,
        );
      }
    }

    // ---- 四边墨色界线 ----
    final wallPaint = Paint()
      ..color = const Color(0x554A3220)
      ..strokeWidth = 8;
    canvas.drawLine(const Offset(8, 0), Offset(8, worldSize), wallPaint);
    canvas.drawLine(
        Offset(worldSize - 8, 0), Offset(worldSize - 8, worldSize), wallPaint);
    canvas.drawLine(const Offset(0, 8), Offset(worldSize, 8), wallPaint);
    canvas.drawLine(
        Offset(0, worldSize - 8), Offset(worldSize, worldSize - 8), wallPaint);
  }

  void _drawHill(Canvas canvas, _HillDeco h, Color shade) {
    final s = h.scale;
    final path = Path()
      ..moveTo(h.center.dx - 130 * s, h.center.dy)
      ..quadraticBezierTo(h.center.dx - 60 * s, h.center.dy - 95 * s,
          h.center.dx, h.center.dy)
      ..quadraticBezierTo(h.center.dx + 45 * s, h.center.dy - 60 * s,
          h.center.dx + 130 * s, h.center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = shade);
  }

  void _drawMarker(Canvas canvas, _MarkerDeco m) {
    final stone = Paint()..color = const Color(0xFF6E5844);
    final dark = Paint()..color = const Color(0xFF4A3A28);
    if (m.isPagoda) {
      // 驿亭：两柱 + 攒尖顶
      canvas.drawRect(
          Rect.fromLTWH(m.center.dx - 26, m.center.dy - 10, 8, 44), stone);
      canvas.drawRect(
          Rect.fromLTWH(m.center.dx + 18, m.center.dy - 10, 8, 44), stone);
      final roof = Path()
        ..moveTo(m.center.dx - 38, m.center.dy - 8)
        ..lineTo(m.center.dx, m.center.dy - 44)
        ..lineTo(m.center.dx + 38, m.center.dy - 8)
        ..close();
      canvas.drawPath(roof, dark);
    } else {
      // 石碑：碑身 + 碑帽 + 「西」刻痕
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(m.center.dx - 14, m.center.dy - 30, 28, 52),
              const Radius.circular(4)),
          stone);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(m.center.dx - 18, m.center.dy - 38, 36, 12),
              const Radius.circular(5)),
          dark);
      canvas.drawLine(
          Offset(m.center.dx - 6, m.center.dy - 8),
          Offset(m.center.dx + 6, m.center.dy - 8),
          Paint()
            ..color = const Color(0xFFE8D9B0)
            ..strokeWidth = 2.4);
      canvas.drawLine(
          Offset(m.center.dx, m.center.dy - 8),
          Offset(m.center.dx, m.center.dy + 8),
          Paint()
            ..color = const Color(0xFFE8D9B0)
            ..strokeWidth = 2.4);
    }
  }

  /// 参照物绘制：kind 着色 + 边界勾线（可击破=陶褐 / 不可破=灰岩 /
  /// 宝箱点=鎏金 / 里程碑=黛青 / 驿站路标=月白）。
  void _drawMapObject(Canvas canvas, JourneyMapObjectModel o, Offset c) {
    const colors = <String, Color>{
      'breakable': Color(0xFFB07C5A),
      'unbreakable': Color(0xFF8A8A80),
      'chest_point': Color(0xFFE8C470),
      'milestone': Color(0xFF5E7F9A),
      'waypoint': Color(0xFFD8D2C0),
    };
    final base = colors[o.kind] ?? const Color(0xFF8A8A80);
    canvas.drawCircle(c, o.radius, Paint()..color = base.withValues(alpha: 0.55));
    canvas.drawCircle(
      c,
      o.radius,
      Paint()
        ..color = base
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    // 内部小标：宝箱点画菱形，其余画同心点
    if (o.kind == 'chest_point') {
      final r = o.radius * 0.36;
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = base);
    } else {
      canvas.drawCircle(c, o.radius * 0.22, Paint()..color = base);
    }
  }

  /// 视口世界矩形（取不到相机时返回 null=全画，兜底不致黑屏）。
  Rect? _visibleRect() {
    try {
      final game = findGame();
      if (game is FlameGame) return game.camera.visibleWorldRect;
    } catch (_) {}
    return null;
  }
}

class _HillDeco {
  const _HillDeco({
    required this.center,
    required this.scale,
    required this.shade,
  });
  final Offset center;
  final double scale;
  final int shade;
}

class _CloudDeco {
  const _CloudDeco({required this.center, required this.scale});
  final Offset center;
  final double scale;
}

class _MarkerDeco {
  const _MarkerDeco({required this.center, required this.isPagoda});
  final Offset center;
  final bool isPagoda;
}

/// 玩家（鎏金圆 + 朝向指示；环绕法宝由 JourneyOrbitWeapons 独立渲染）。
class JourneyPlayerComponent extends PositionComponent {
  JourneyPlayerComponent({
    required this.game,
    required super.position,
    this.maxHp = 100,
  }) : hp = maxHp;

  final JourneyFlameGame game;

  double maxHp;
  double hp;
  double regen = 0;
  double armor = 0;
  double pickupRange = 80;
  double _regenTimer = 0;

  static const double _radius = 20;
  static const double _baseSpeed = 240;

  Vector2 facing = Vector2(0, -1);

  @override
  void update(double dt) {
    super.update(dt);
    if (game._ended) return;

    // 摇杆驱动（屏幕向量直接映射世界向量，全向自由移动）
    final v = game.controller.input.vector;
    if (v.distanceSquared > 0.001) {
      position += Vector2(v.dx, v.dy) * _baseSpeed * game.moveSpeedAmp * dt;
      facing = Vector2(v.dx, v.dy)..normalize();
    }
    position.x = position.x
        .clamp(_radius + 8, game.worldSize - _radius - 8);
    position.y = position.y
        .clamp(_radius + 8, game.worldSize - _radius - 8);

    // 木系自动回复
    if (regen > 0) {
      _regenTimer += dt;
      if (_regenTimer >= 1) {
        _regenTimer -= 1;
        if (hp < maxHp) {
          hp = (hp + regen).clamp(0.0, maxHp);
          game.onPlayerHpChanged();
        }
      }
    }

    _reportCompass();
  }

  /// 妖王罗盘上报（低频去重）：bearing=指向据点的世界角，progress=接近度
  /// （0=刚出发，1=已抵达据点圈）。
  void _reportCompass() {
    final boss = game.boss;
    if (boss == null) return;
    final hud = game.controller.hud;
    final to = boss.position - position;

    final brg = math.atan2(to.y, to.x);
    var d = brg - hud.bearing.value;
    if (d > math.pi) d -= math.pi * 2;
    if (d < -math.pi) d += math.pi * 2;
    if (d.abs() > 0.03) {
      hud.bearing.value = brg;
    }

    final ratio = 1 - to.length / game.bossStartDist;
    final near = ratio.clamp(0.0, 1.0);
    if ((near - hud.progress.value).abs() > 0.005) {
      hud.progress.value = near;
    }
  }

  @override
  void render(Canvas canvas) {
    // 注意：PositionComponent 的 render 画布已平移到本组件局部坐标，
    // 绘制必须围绕原点，禁止再叠加 position（双重偏移会画出屏外）。
    // 角色立绘优先（char_<code>.svg）；失败回落几何
    final pic = JourneySprites.get(JourneySprites.character(game.character.code));
    if (pic != null) {
      const size = 76.0;
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
          center: const Offset(0, -14),
          width: size * 0.74,
          height: size,
        ),
        srcWidth: 220,
        srcHeight: 300,
      );
      return;
    }
    // 底环
    canvas.drawCircle(
      Offset.zero,
      _radius + 4,
      Paint()
        ..color = const Color(0x33E8C470)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 本体
    canvas.drawCircle(
      Offset.zero,
      _radius,
      Paint()..color = const Color(0xFFF6E3B4),
    );
    canvas.drawCircle(
      Offset.zero,
      _radius,
      Paint()
        ..color = const Color(0xFFB98F3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 朝向点
    canvas.drawCircle(
      (facing * _radius * 0.62).toOffset(),
      4,
      Paint()..color = const Color(0xFFD4593F),
    );
  }

  void takeDamage(double amount) {
    if (hp <= 0) return;
    hp = (hp - amount).clamp(0.0, maxHp);
    game.onPlayerHpChanged();
  }

  void heal(double amount) {
    hp = (hp + amount).clamp(0.0, maxHp);
    game.onPlayerHpChanged();
  }
}
