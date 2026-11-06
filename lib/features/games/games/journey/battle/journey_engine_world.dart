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
    this.isObjDestroyed,
  });

  final double worldSize;
  final String themeColor;
  final int seed;
  final Vector2 bossPos;

  /// 关卡配置的地图参照物（后台 journey_map_objects 维护）。
  final List<JourneyMapObjectModel> mapObjects;

  /// 参照物破坏回调（下标对齐 mapObjects）：已破坏 breakable 不再绘制
  /// （残屑视觉由 fx 层呈现）。null=全部照画。
  final bool Function(int index)? isObjDestroyed;

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

    // ---- 关卡参照物（journey_map_objects 配置，kind 着色圆斑；
    // 已破坏 breakable 由 isObjDestroyed 过滤不画）----
    for (var i = 0; i < mapObjects.length; i++) {
      final o = mapObjects[i];
      if (isObjDestroyed != null && isObjDestroyed!(i)) {
        continue;
      }
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
    // 道具精灵优先（石碑/驿亭），缺失回落手绘几何
    final pic = JourneySprites.get(JourneySprites.prop(m.isPagoda ? 'yiting' : 'shibei'));
    if (pic != null) {
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
            center: m.center.translate(0, -5), width: 48, height: 48),
        srcWidth: 48,
        srcHeight: 48,
      );
      return;
    }
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

  /// 参照物绘制：道具精灵优先（可击破=香火供台 / 不可破=山石，缺失回落
  /// kind 着色圆斑），其余 kind 沿用着色圆斑 + 边界勾线（宝箱点=鎏金 /
  /// 里程碑=黛青 / 驿站路标=月白）。
  void _drawMapObject(Canvas canvas, JourneyMapObjectModel o, Offset c) {
    const spriteByKind = <String, String>{
      'breakable': 'gongtai',
      'unbreakable': 'shikuai',
    };
    final propName = spriteByKind[o.kind];
    if (propName != null) {
      final pic = JourneySprites.get(JourneySprites.prop(propName));
      if (pic != null) {
        // 精灵略大于碰撞圈（视觉更实），底部对齐圆心（物件立于地面）
        final size = o.radius * 2.4;
        JourneySprites.draw(
          canvas,
          pic,
          dstRect: Rect.fromCenter(
              center: c.translate(0, -o.radius * 0.35),
              width: size,
              height: size),
          srcWidth: 48,
          srcHeight: 48,
        );
        return;
      }
    }
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
