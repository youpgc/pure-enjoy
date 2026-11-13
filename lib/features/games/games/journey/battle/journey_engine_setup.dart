part of 'journey_flame_game.dart';

/// 对局世界装配：地图/相机/参照物/玩家/渲染层一次性初始化。
extension JourneyWorldSetup on JourneyFlameGame {
  void setupWorld() {
    final size = worldSize;
    final angle = rng.nextDouble() * math.pi * 2;
    final dist = size * (0.32 + rng.nextDouble() * 0.13);
    bossPos = Vector2(
      (size / 2 + math.cos(angle) * dist).clamp(320.0, size - 320),
      (size / 2 + math.sin(angle) * dist).clamp(320.0, size - 320),
    );

    // 使用 FlameGame 自带的 world/camera（自建会与 game.world/game.camera
    // 错位成两套坐标系：实体进默认世界、相机查错相机 → 实体全部不可见）。
    camera.viewfinder.anchor = Anchor.center;
    // 相机边界钳制交由 Flame 内置 BoundedPositionBehavior：整个视口不出
    // 世界矩形（防黑边）。该行为 priority 1000，每帧在 follow 修正之后
    // 生效，手写在组件 update 里覆盖 viewfinder.position 会被 follow 拉回。
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, size, size),
      considerViewport: true,
    );

    // 参照物运行时状态：破坏标记 + 可击破血量表（hp<=0 行视为一击破坏）
    _mapObjDead = List<bool>.filled(runtime.mapObjects.length, false);
    for (var i = 0; i < runtime.mapObjects.length; i++) {
      final o = runtime.mapObjects[i];
      if (o.kind == 'breakable' && o.hp > 0) {
        _mapObjHp[i] = o.hp.toDouble();
      }
    }

    world.add(JourneyWorldBackground(
      worldSize: size,
      themeColor: controller.themeColor,
      seed: level.levelNo,
      bossPos: bossPos,
      mapObjects: runtime.mapObjects,
      isObjDestroyed: (i) => _mapObjDead[i],
    ));

    player = JourneyPlayerComponent(
      game: this,
      position: Vector2(size / 2, size / 2),
      maxHp: character.baseHp.toDouble(),
    );
    world.add(player);
    world.add(JourneyOrbitWeapons(game: this));
    world.add(fxLayer);
    camera.follow(player);

    bossStartDist = (bossPos - player.position).length;
    // 罗盘「里」换算基准（距妖王 = 接近度 × 基准距离 ÷25，1 里=25 单位）
    debugPrint('罗盘基准: lv=${level.levelNo} boss=${bossModel?.code} '
        'startDist=${bossStartDist.toStringAsFixed(0)} '
        'bossPos=$bossPos player=${player.position} worldSize=$size');
  }
}
