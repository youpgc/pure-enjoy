part of 'journey_flame_game.dart';

/// 怪物池与妖王归属解析（远端配置优先、内置种子兜底）：

/// 怪物池：远端 journey_monsters 配置优先，内置种子兜底（SQL 未就绪
/// 或远端行缺失时保证可玩）。
/// - 关卡配置了波次：池=波次怪种 ∪ 本关妖王（波次全权定刷怪内容，
///   区域原著妖怪口径由配置保证）；
/// - 无波次：池=全部普通/精英 + 本关妖王（兜底全向刷怪）。
List<JourneyMonsterModel> _buildPool(JourneyFlameGame game) {
  final remote = game.config?.monsters ?? const <JourneyMonsterModel>[];
  final source = remote.isNotEmpty
      ? List<JourneyMonsterModel>.of(remote)
      : kJourneyMonsterSeed.map(JourneyMonsterModel.fromJson).toList();
  final bossCode = resolveBossCode(game);
  final boss = source
      .where((m) => m.isBoss && m.code == bossCode)
      .toList(growable: false);
  if (game.runtime.waves.isNotEmpty) {
    // 波次关：池=波次怪种（映射断裂的行已在 config service 过滤）∪ 妖王
    final waveCodes = <String>{for (final w in game.runtime.waves) w.monsterCode};
    final mobs = source
        .where((m) => !m.isBoss && waveCodes.contains(m.code))
        .toList();
    return <JourneyMonsterModel>[...mobs, ...boss];
  }
  return source.where((m) => !m.isBoss || m.code == bossCode).toList();
}

/// 本关妖王编码：
/// - 远端区域行存在：boss_code 即定稿口径（NULL=原著无妖章回，无妖王战，
///   引擎走「坚持通关」口径）；
/// - 区域行缺失/内置兜底快照：回落关卡号区间映射（保可玩，每关有妖王）。
String? resolveBossCode(JourneyFlameGame game) {
  final region = game.config?.regionOf(game.level.regionCode);
  if (game.config?.fromSeed != true && region != null) {
    final configured = region.bossCode;
    return (configured != null && configured.isNotEmpty) ? configured : null;
  }
  return _fallbackBossCode(game.level.levelNo);
}

/// 兜底映射：区域配置未就绪时按关卡区间取妖王（近似原著章回；
/// 无妖章回返回 null，走坚持通关口径，与远端 boss_code=NULL 语义一致）。
String? _fallbackBossCode(int levelNo) {
  if (levelNo <= 4) return null; // 序章·长安
  if (levelNo <= 7) return 'yin_jiangjun'; // 双叉岭·寅将军
  if (levelNo <= 9) return null; // 五行山/鹰愁涧
  if (levelNo <= 11) return 'heixiong_jing'; // 黑风山·黑熊精
  if (levelNo <= 12) return null; // 高老庄
  if (levelNo <= 14) return 'huangfeng_jing'; // 黄风岭·黄风怪
  if (levelNo <= 19) return null; // 流沙河/五庄观
  return 'baigu_jing'; // 白虎岭起
}

JourneyMonsterModel? _bossOfRegion(JourneyFlameGame game) {
  final code = resolveBossCode(game);
  if (code == null) return null;
  final remote = game.config?.monsters ?? const <JourneyMonsterModel>[];
  final source = remote.isNotEmpty
      ? remote
      : kJourneyMonsterSeed.map(JourneyMonsterModel.fromJson).toList();
  for (final m in source) {
    if (m.code == code && m.isBoss) return m;
  }
  return null;
}

/// 怪物生成与妖王据点（平铺大地图口径）：
/// - **波次优先**：关卡配置了 journey_waves 时按时间轴刷怪（start_sec 起
///   每 spawn_interval_ms 刷 count 只 monster_code，该波乘 buff_mult）；
/// - 无波次配置回落全向兜底刷怪（探索沿途持续遭遇）；
/// - 生成点感知密度热区：妖穴（demon_den）内集中刷怪、安全谷排除；
/// - 妖王据点开局即驻守 + 周边守卫群，罗盘指引玩家前往。
mixin JourneySpawnMixin {
  double _spawnTimer = 0;

  /// 波次刷怪进度（index 对齐 game.runtime.waves）。
  final List<List<double>> _waveProgress = <List<double>>[]; // [spawned, timer]

  /// 引擎接入关卡波次配置时初始化进度表（onLoad 调一次）。
  void initWaveProgress(JourneyFlameGame game) {
    _waveProgress
      ..clear()
      ..addAll(<List<double>>[
        for (final _ in game.runtime.waves) <double>[0, 0],
      ]);
  }

  void updateSpawns(JourneyFlameGame game, double dt) {
    // 波次驱动（关卡配置了波次时由波次定刷怪内容与节奏）；
    // 波次全部播完后返回 true → 回落兜底节奏补怪：坚持难（无妖难 300s）
    // 与绕路找据点的长局在后半程仍维持遭遇密度，不空场。
    if (game.runtime.waves.isNotEmpty && !_updateWaves(game, dt)) return;
    // 兜底：0.8s 起刷随局内时间渐密；批量 1~3 只（3 分钟后拉满）
    _spawnTimer += dt;
    final minute = game._elapsed / 60.0;
    final interval = (0.8 - minute * 0.2).clamp(0.3, 0.8);
    if (_spawnTimer < interval) return;
    _spawnTimer = 0;
    final batch = 1 + (minute ~/ 3).clamp(0, 2);
    for (var i = 0; i < batch; i++) {
      if (game.monsters.length >= game.monsterCap) return;
      final pick = _pickMonster(game);
      if (pick != null) spawnMonster(game, pick);
    }
  }

  /// 波次推进。返回 true=全部波次已播完（计数达成）。
  bool _updateWaves(JourneyFlameGame game, double dt) {
    final elapsed = game._elapsed;
    var allDone = true;
    for (var i = 0; i < game.runtime.waves.length; i++) {
      final wave = game.runtime.waves[i];
      if (elapsed < wave.startSec) {
        allDone = false;
        continue;
      }
      final prog = _waveProgress.isEmpty ? null : _waveProgress[i];
      if (prog == null) return false;
      if (prog[0] >= wave.count) continue;
      allDone = false;

      prog[1] += dt;
      final interval = (wave.spawnIntervalMs / 1000.0).clamp(0.05, 10.0);
      while (prog[1] >= interval && prog[0] < wave.count) {
        prog[1] -= interval;
        if (game.monsters.length >= game.monsterCap) return false;
        final model = _modelOf(game, wave.monsterCode);
        if (model == null) {
          // 怪种映射缺失：整波跳过（config service 已做同口径过滤，双保险）
          prog[0] = wave.count.toDouble();
          break;
        }
        spawnMonsterAt(
          game,
          model,
          buffMult: game.buffMult * wave.buffMult,
          position: _spawnPosition(game),
        );
        prog[0]++;
      }
    }
    return allDone;
  }

  JourneyMonsterModel? _modelOf(JourneyFlameGame game, String code) {
    for (final m in game.pool) {
      if (m.code == code) return m;
    }
    return null;
  }

  /// 生成点：感知密度热区——妖穴内集中（70% 概率），安全谷排除；
  /// 无热区时回落玩家活动环带。
  Vector2 _spawnPosition(JourneyFlameGame game) {
    final size = game.worldSize;
    final dens = game.runtime.heatZones
        .where((z) => z.kind == 'demon_den')
        .toList();
    final safe = game.runtime.heatZones
        .where((z) => z.kind == 'safe_valley')
        .toList();

    Vector2 pick() {
      if (dens.isNotEmpty && game.rng.nextDouble() < 0.70) {
        final z = dens[game.rng.nextInt(dens.length)];
        final a = game.rng.nextDouble() * math.pi * 2;
        final r = z.radius * math.sqrt(game.rng.nextDouble());
        return Vector2(
          (z.x + math.cos(a) * r).clamp(60.0, size - 60),
          (z.y + math.sin(a) * r).clamp(60.0, size - 60),
        );
      }
      final angle = game.rng.nextDouble() * math.pi * 2;
      final dist = 420.0 + game.rng.nextDouble() * 780.0;
      return Vector2(
        (game.player.position.x + math.cos(angle) * dist)
            .clamp(80.0, size - 80),
        (game.player.position.y + math.sin(angle) * dist)
            .clamp(80.0, size - 80),
      );
    }

    var pos = pick();
    for (var retry = 0; retry < 3; retry++) {
      final inSafe = safe.any((z) =>
          (pos - Vector2(z.x, z.y)).length <= z.radius);
      if (!inSafe) break;
      pos = pick();
    }
    return pos;
  }

  JourneyMonsterModel? _pickMonster(JourneyFlameGame game) {
    final normal = game.pool.where((m) => !m.isBoss).toList();
    if (normal.isEmpty) return null;
    final minute = game._elapsed / 60.0;
    final eliteRate = 0.10 + minute * 0.06;
    if (game.rng.nextDouble() < eliteRate) {
      final elites = normal.where((m) => m.isElite).toList();
      return elites.isEmpty
          ? normal[game.rng.nextInt(normal.length)]
          : elites[game.rng.nextInt(elites.length)];
    }
    return normal[game.rng.nextInt(normal.length)];
  }

  void spawnMonster(JourneyFlameGame game, JourneyMonsterModel model) {
    spawnMonsterAt(game, model, buffMult: game.buffMult, position: null);
  }

  /// 统一落怪入口：[position] 为 null 时按玩家活动环带随机（全向散布）。
  void spawnMonsterAt(
    JourneyFlameGame game,
    JourneyMonsterModel model, {
    required double buffMult,
    Vector2? position,
  }) {
    final size = game.worldSize;
    var pos = position;
    if (pos == null) {
      final angle = game.rng.nextDouble() * math.pi * 2;
      final dist = 420.0 + game.rng.nextDouble() * 780.0;
      pos = Vector2(
        (game.player.position.x + math.cos(angle) * dist)
            .clamp(80.0, size - 80),
        (game.player.position.y + math.sin(angle) * dist)
            .clamp(80.0, size - 80),
      );
    }
    final comp = JourneyMonsterComponent(
      game: game,
      model: model,
      buffMult: buffMult,
      position: pos,
    );
    game.monsters.add(comp);
    game.world.add(comp);
  }

  /// 开局铺场：进局立即在玩家周围布置一圈怪（500~1200 环带随机方位），
  /// 避免新手期「走好远才见到怪」的空旷感（波次关卡跳过——波次全权接管）。
  void seedInitialPack(JourneyFlameGame game, {int count = 24}) {
    if (game.runtime.waves.isNotEmpty) return;
    for (var i = 0; i < count; i++) {
      if (game.monsters.length >= game.monsterCap) return;
      final pick = _pickMonster(game);
      if (pick == null) return;
      spawnMonster(game, pick);
    }
  }

  /// 妖王据点：开局即驻守（驻点待机，玩家进入侦测半径才交战），
  /// 并在据点周围布置守卫群；属性乘区统一走 buffMult（含关卡难度乘区）。
  void spawnBossAtPost(JourneyFlameGame game) {
    final model = game.bossModel;
    if (model == null) return;
    final bossPos = game.bossPos;
    final comp = JourneyMonsterComponent(
      game: game,
      model: model,
      buffMult: game.buffMult,
      position: bossPos.clone(),
    );
    game.boss = comp;
    game.monsters.add(comp);
    game.world.add(comp);

    // 据点守卫：妖王周边环状 10 只精英/普通怪
    final guards = game.pool.where((m) => !m.isBoss).toList();
    for (var i = 0; i < 10 && guards.isNotEmpty; i++) {
      final gAngle = (i / 6) * math.pi * 2 + game.rng.nextDouble() * 0.6;
      final gDist = 120.0 + game.rng.nextDouble() * 140.0;
      spawnMonsterAt(
        game,
        guards[game.rng.nextInt(guards.length)],
        buffMult: game.buffMult,
        position: Vector2(
          (bossPos.x + math.cos(gAngle) * gDist)
              .clamp(60.0, game.worldSize - 60),
          (bossPos.y + math.sin(gAngle) * gDist)
              .clamp(60.0, game.worldSize - 60),
        ),
      );
    }
  }

  /// 下一场妖王：同体增强（血量 +55%/场、伤害 +25%/场），据点重生。
  void respawnBoss(JourneyFlameGame game) {
    final model = game.bossModel;
    if (model == null) return;
    final comp = JourneyMonsterComponent(
      game: game,
      model: model,
      buffMult: game.buffMult * (1.0 + game._bossStage * 0.55),
      position: game.bossPos.clone(),
    );
    comp.scaleStageDamage(game._bossStage);
    game.boss = comp;
    game.monsters.add(comp);
    game.world.add(comp);
    game.controller.onBossSpawn('${game._bossStage + 1} 打 · ${model.name}');
  }
}
