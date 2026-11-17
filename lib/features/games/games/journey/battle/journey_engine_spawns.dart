part of 'journey_flame_game.dart';

/// 怪物生成与妖王据点（平铺大地图口径）：
/// - **波次优先**：关卡配置了 journey_waves 时按时间轴刷怪（start_sec 起
///   每 spawn_interval_ms 刷 count 只 monster_code，该波乘 buff_mult）；
/// - 无波次配置回落全向兜底刷怪（探索沿途持续遭遇）；
/// - 生成点感知密度热区：妖穴（demon_den）内集中刷怪、安全谷排除；
/// - 妖王据点延迟降临 + 周边守卫群，降临后罗盘指引玩家前往。
mixin JourneySpawnMixin {
  double _spawnTimer = 0;

  // ---- 无尽妖潮（虚拟关 kind=endless）波次状态 ----
  int _endlessWave = 1; // 当前波（1 起，999 封顶）
  int _endlessSpawned = 0; // 本波已刷只数
  double _endlessTimer = 0; // 波内刷怪间隔计时
  double _endlessRest = 0; // 波间休整倒计时（>0 休整中）
  int _endlessBossSummoned = 0; // 妖潮期本波已降临妖王数（配额消耗）
  double _endlessBossCd = 0; // 妖王补位降临倒计时（>0 计时中）
  int _endlessBossKilled = 0; // 妖潮期本波已被击杀妖王数（宝箱/天赋点首杀判定）
  int _jinjiaoWaveRefines = 0; // 宝葫本波已炼化次数（妖潮期按波限流）

  // ---- 每日游历（虚拟关 kind=daily）铜钱雨状态 ----
  double _dailyCoinTimer = 0;

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
    // 模式分支：无尽妖潮=波次生成器全权刷怪；每日游历=兜底刷怪+铜钱雨
    if (_isEndless(game)) {
      _updateEndless(game, dt);
      return;
    }
    if (_isDaily(game)) {
      _updateDailyCoinRain(game, dt);
    }
    // 波次驱动（关卡配置了波次时由波次定刷怪内容与节奏）；
    // loop=true 循环层永不判完成（持续补怪至怪量上限）——含循环层的关卡
    // 不会回落兜底节奏，循环层全权承担时间轴播完后的遭遇密度。
    if (game.runtime.waves.isNotEmpty && !_updateWaves(game, dt)) return;
    // 兜底：随局内时间渐密；每日游历按图里程提高密度档，使单局经验池
    // 足以支撑该图目标等级，批量上限随档位递增。
    _spawnTimer += dt;
    final minute = game._elapsed / 60.0;
    final tier = _isDaily(game) ? _dailyDensityTier(game) : 0;
    final spawnMin = game.battleNum('spawn', 'interval_min', 0.28);
    final spawnMax = game.battleNum('spawn', 'interval_base', 0.8);
    final interval = (game.battleNum('spawn', 'interval_base', 0.8) -
            game.battleNum('spawn', 'interval_tier', 0.10) * tier -
            minute * game.battleNum('spawn', 'interval_minute', 0.12))
        .clamp(math.min(spawnMin, spawnMax), math.max(spawnMin, spawnMax));
    if (_spawnTimer < interval) return;
    _spawnTimer = 0;
    final batchCap = 1 + tier;
    final batchMinutes = game.battleNum('spawn', 'batch_minutes', 1.5);
    final batch = 1 +
        (minute ~/ batchMinutes).clamp(0, batchCap - 1);
    for (var i = 0; i < batch; i++) {
      if (game.monsters.length >= game.monsterCap) return;
      final pick = _pickMonster(game);
      if (pick != null) spawnMonster(game, pick);
    }
  }

  /// 波次推进。返回 true=全部波次已播完（计数达成；循环层恒不计完成）。
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
      // 循环层不消费 count（种子置 1 占位），恒不判完成；
      // 时间轴波计数达成后跳过
      if (!wave.loop && prog[0] >= wave.count) continue;
      allDone = false;

      prog[1] += dt;
      final interval = (wave.spawnIntervalMs / 1000.0).clamp(0.05, 10.0);
      while (prog[1] >= interval &&
          (wave.loop || prog[0] < wave.count)) {
        prog[1] -= interval;
        if (game.monsters.length >= game.monsterCap) return false;
        final model = _modelOf(game, wave.monsterCode);
        if (model == null) {
          // 怪种映射缺失：整波跳过（config service 已做同口径过滤，双保险）；
          // 循环层怪种缺失同样封口（标记计数达成防死循环空转）
          prog[0] = wave.count.toDouble();
          break;
        }
        // 保护期内波次指定的强怪回落普通怪，避免开局被打断发育
        final protectSec =
            (game.config?.earlyGameProtectSec ?? kJourneyEarlyGameProtectSec)
                .toDouble();
        // 保护期内精英、妖王与高血「伪普通」怪都回落低阶小妖，
        // 保证开局先拿到经验池再面对强度压力
        final early = game._elapsed < protectSec;
        final spawnModel =
            (early && (model.isElite || model.isBoss || model.baseHp > 200))
                ? (_pickMonster(game, allowElite: false) ?? model)
                : model;
        spawnMonsterAt(
          game,
          spawnModel,
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
      // 妖穴集中概率走 journey_globals.spawn_den_ratio（0~1，后台可调；
      // 调低=玩家沿途遭遇更均匀）
      final denRatio = game.config?.spawnDenRatio ?? 0.70;
      if (dens.isNotEmpty && game.rng.nextDouble() < denRatio) {
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

  void spawnMonster(JourneyFlameGame game, JourneyMonsterModel model) {
    spawnMonsterAt(game, model, buffMult: game.buffMult, position: null);
  }

  /// 统一落怪入口：[position] 为 null 时按玩家活动环带随机（全向散布）。
  void spawnMonsterAt(
    JourneyFlameGame game,
    JourneyMonsterModel model, {
    required double buffMult,
    double? hpBuffMult,
    bool bossLvHpTerm = true,
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
      hpBuffMult: hpBuffMult,
      bossLvHpTerm: bossLvHpTerm,
      position: pos,
    );
    game.monsters.add(comp);
    game.world.add(comp);
  }

  /// 开局铺场：进局立即在玩家周围布置一圈怪（500~1200 环带随机方位），
  /// 避免新手期「走好远才见到怪」的空旷感。数量走 journey_globals.
  /// initial_pack_size（缺省 24，0=关闭）；波次关不再跳过（循环层负责
  /// 持续补怪，铺场只解决开局空场）。
  void seedInitialPack(JourneyFlameGame game) {
    final count = game.config?.initialPackSize ?? 24;
    if (count <= 0) return;
    for (var i = 0; i < count; i++) {
      if (game.monsters.length >= game.monsterCap) return;
      final pick = _pickMonster(game, allowElite: false);
      if (pick == null) return;
      spawnMonster(game, pick);
    }
  }

  /// 妖王据点：降临计时结束后驻守（驻点待机，玩家进入侦测半径才交战），
  /// 并在据点周围布置守卫群；妖王血量走只含时间项的乘区，守卫仍走 buffMult。
  void spawnBossAtPost(JourneyFlameGame game) {
    final model = game.bossModel;
    if (model == null) return;
    final bossPos = game.bossPos;
    final comp = JourneyMonsterComponent(
      game: game,
      model: model,
      buffMult: game.buffMult,
      hpBuffMult: game.bossHpBuffMult,
      position: bossPos.clone(),
    );
    game.boss = comp;
    game.monsters.add(comp);
    game.world.add(comp);
    // 罗盘/小地图的妖王显隐开关；大血条由每帧 syncBossHud 按交战与血量
    // 自行出入列。onLoad 挂载期 HUD 通知调度帧尾（防 markNeedsBuild during build）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      game.controller.hud.bossPresent.value = true;
    });

    // 据点守卫：妖王周边环状精英/普通怪，只数与环带可配
    final guards = game.pool.where((m) => !m.isBoss).toList();
    final guardCount = game.battleNum('spawn', 'boss_guard_count', 10).round();
    final ringMin = game.battleNum('spawn', 'boss_guard_ring_min', 120);
    final ringSpan = game.battleNum('spawn', 'boss_guard_ring_span', 140);
    for (var i = 0; i < guardCount && guards.isNotEmpty; i++) {
      final gAngle = (i / 6) * math.pi * 2 + game.rng.nextDouble() * 0.6;
      final gDist = ringMin + game.rng.nextDouble() * ringSpan;
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

  /// 下一场妖王：同体增强（血量/伤害按场递增），据点重生。
  void respawnBoss(JourneyFlameGame game) {
    final model = game.bossModel;
    if (model == null) return;
    final hpGain =
        game.battleNum('boss', 'stage_hp_gain', 0.55);
    final comp = JourneyMonsterComponent(
      game: game,
      model: model,
      buffMult: game.buffMult * (1.0 + game._bossStage * hpGain),
      hpBuffMult: game.bossHpBuffMult *
          (1.0 + game._bossStage * hpGain),
      position: game.bossPos.clone(),
    );
    comp.scaleStageDamage(game._bossStage);
    game.boss = comp;
    game.monsters.add(comp);
    game.world.add(comp);
    // 罗盘/小地图显隐复位；大血条由每帧 syncBossHud 按新体交战状态入列。
    game.controller.hud.bossPresent.value = true;
    game.controller.onBossSpawn('${game._bossStage + 1} 打 · ${model.name}');
  }

  // ---- 无尽妖潮 / 每日游历（虚拟关 level_no=0，纯 App 端模式）----

  /// 无尽妖潮波次生成器入口（本体在 journey_engine_endless.dart，
  /// 同库 top-level 函数：发育期/妖潮期分段 + 妖王潮配额降临）。
  void _updateEndless(JourneyFlameGame game, double dt) =>
      journeyEndlessTick(game, dt);

  /// 每日游历·铜钱雨：按参数周期在玩家环带撒功德铜钱，每枚价值可配。
  void _updateDailyCoinRain(JourneyFlameGame game, double dt) {
    game._dailyCoinTimer += dt;
    if (game._dailyCoinTimer <
        game.battleNum('economy', 'daily_coin_period_sec', 4)) {
      return;
    }
    game._dailyCoinTimer = 0;
    final unit = game.battleNum('economy', 'daily_coin_unit', 8).round();
    final count = game.battleNum('economy', 'daily_coin_count', 4).round();
    final size = game.worldSize;
    for (var i = 0; i < count; i++) {
      final angle = game.rng.nextDouble() * math.pi * 2;
      final dist = 420.0 + game.rng.nextDouble() * 780.0;
      game._spawnPickup(
        game,
        JourneyPickupKind.meritCoin,
        Vector2(
          (game.player.position.x + math.cos(angle) * dist)
              .clamp(80.0, size - 80),
          (game.player.position.y + math.sin(angle) * dist)
              .clamp(80.0, size - 80),
        ),
        unit,
      );
    }
  }
}

/// 虚拟关模式判定（kind 约定见 JourneyLevelModel；level_no=0 不落主线）。
bool _isEndless(JourneyFlameGame game) => game.level.kind == 'endless';
bool _isDaily(JourneyFlameGame game) => game.level.kind == 'daily';

/// 每日游历密度档：按后台地图序列的里程碑里数分 0~4 档，档位越高刷怪
/// 越密，让 300 秒单局的经验池足以支撑该图目标等级。图序列缺失时按
/// 里程线性分档兜底，保证离线可玩。
int _dailyDensityTier(JourneyFlameGame game) {
  final li =
      game.config?.dailyMapOf(game.level.regionCode)?.milestoneLi ?? 800;
  final maps = game.config?.dailyMapList();
  if (maps == null || maps.isEmpty) {
    return ((li - 800) / 450).floor().clamp(0, 4).toInt();
  }
  final milestones = <int>{for (final m in maps) m.milestoneLi}.toList()
    ..sort();
  final idx = milestones.indexWhere((v) => v >= li);
  return (idx < 0 ? milestones.length - 1 : idx).clamp(0, 4).toInt();
}

/// 妖王降临完整倒计时推进：从首次降临延迟起持续写入剩余秒数，罗盘位
/// 展示「妖王降临 · Xs」（不再仅在末 10s 提醒窗口才显示）；归零即召唤
/// 并写「妖王降临」横幅；ValueNotifier 等值不重复通知，每秒至多一次。
void tickBossSpawnCountdown(JourneyFlameGame game, double dt) {
  if (game._bossSpawnCountdown <= 0) return;
  game._bossSpawnCountdown -= dt;
  if (game._bossSpawnCountdown <= 0) {
    game.controller.hud.bossSpawnIn.value = 0;
    game.spawnBossAtPost(game);
    game.controller.onBossSpawn(game.bossModel?.name ?? '妖王');
    return;
  }
  final left = game._bossSpawnCountdown.ceil();
  if (game.controller.hud.bossSpawnIn.value != left) {
    game.controller.hud.bossSpawnIn.value = left;
  }
}

/// 妖王阵亡（多场战）到复活/新妖王降临的冷却倒计时推进：归零后据点重生
/// 并播「妖王降临」横幅；冷却期间罗盘位展示「妖王降临 · Xs」完整倒计时。
/// 与 [tickBossSpawnCountdown] 互不重叠（仅一者 >0），共用同一 HUD 倒计时位。
void tickBossRespawnCountdown(JourneyFlameGame game, double dt) {
  if (game._bossRespawnCountdown <= 0) return;
  game._bossRespawnCountdown -= dt;
  if (game._bossRespawnCountdown <= 0) {
    game.controller.hud.bossSpawnIn.value = 0;
    game.respawnBoss(game);
    return;
  }
  final left = game._bossRespawnCountdown.ceil();
  if (game.controller.hud.bossSpawnIn.value != left) {
    game.controller.hud.bossSpawnIn.value = left;
  }
}
