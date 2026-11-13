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
    // 兜底：随局内时间渐密；每日游历按图里程提高密度档，让 300 秒
    // 单局的经验池足以支撑该图目标等级，批量上限随档位递增。
    _spawnTimer += dt;
    final minute = game._elapsed / 60.0;
    final tier = _isDaily(game) ? _dailyDensityTier(game) : 0;
    final interval = (0.8 - 0.10 * tier - minute * 0.12).clamp(0.28, 0.8);
    if (_spawnTimer < interval) return;
    _spawnTimer = 0;
    final batchCap = 1 + tier;
    final batch = 1 + (minute ~/ 1.5).clamp(0, batchCap - 1);
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

  JourneyMonsterModel? _pickMonster(
    JourneyFlameGame game, {
    bool allowElite = true,
  }) {
    final pool = game.pool.where((m) => !m.isBoss).toList();
    if (pool.isEmpty) return null;
    final protectSec =
        (game.config?.earlyGameProtectSec ?? kJourneyEarlyGameProtectSec)
            .toDouble();
    final elapsed = game._elapsed;
    // 保护期内不产生精英；保护期过后按局内时间线性增长并钳上限
    final eliteRate = (elapsed < protectSec || !allowElite)
        ? 0.0
        : (((elapsed - protectSec) / 60.0) *
                (game.config?.eliteRatePerMin ?? kJourneyEliteRatePerMin))
            .clamp(0.0, kJourneyEliteRateCap);
    if (eliteRate > 0 && game.rng.nextDouble() < eliteRate) {
      final elites = pool.where((m) => m.isElite).toList();
      if (elites.isNotEmpty) return elites[game.rng.nextInt(elites.length)];
    }
    // 普通怪单独取样：保护期内排除高血「伪普通」怪，未命中精英率时
    // 也不把精英混进随机结果
    final commons = pool
        .where((m) =>
            !m.isElite && (elapsed >= protectSec || m.baseHp <= 200))
        .toList();
    final fallback = pool.where((m) => !m.isElite).toList();
    final candidates = commons.isNotEmpty
        ? commons
        : (fallback.isNotEmpty ? fallback : pool);
    return candidates[game.rng.nextInt(candidates.length)];
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
    // 妖王名照写；血条比例由首次进侦测圈（bossEngaged）时按当前血量写入，
    // 开局不再预写常显（领地显隐口径见 monsters part）。
    // onLoad 挂载期 HUD 通知调度帧尾（防 markNeedsBuild during build）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hud = game.controller.hud;
      hud.bossName.value = model.name;
      hud.bossPresent.value = true;
      hud.bossMaxHp.value = comp.maxHp.round();
      hud.bossHp.value = comp.hp.round();
    });

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
      hpBuffMult: game.bossHpBuffMult *
          (1.0 + game._bossStage * 0.55),
      position: game.bossPos.clone(),
    );
    comp.scaleStageDamage(game._bossStage);
    game.boss = comp;
    game.monsters.add(comp);
    game.world.add(comp);
    // 妖王名与绝对血量照写；比例由再次进侦测圈时按当前血量写入
    // （下场增强再战，新体满血；respawn 后仍未 engaged）
    final hud = game.controller.hud;
    hud.bossName.value = model.name;
    hud.bossPresent.value = true;
    hud.bossMaxHp.value = comp.maxHp.round();
    hud.bossHp.value = comp.hp.round();
    game.controller.onBossSpawn('${game._bossStage + 1} 打 · ${model.name}');
  }

  // ---- 无尽妖潮 / 每日游历（虚拟关 level_no=0，纯 App 端模式）----

  /// 无尽妖潮波次生成器（除尽推进制）：当前波怪全灭才进下一波；
  /// 波次配置 journey_endless_waves 优先——monster_code 命中妖王=妖王波
  /// （首只妖王 + 小怪护卫），count 为本波总量、elite_count 为末尾精英数；
  /// 未配置或新列未部署时按经验池公式推演（50~120 只、每波 2~14 精英、
  /// buff=1+0.03n）；波内先低阶小妖供发育、末尾分阶精英施压，整波约 18
  /// 秒铺完。末波（99）刷完清空→「妖潮无尽·功成」可结算。
  void _updateEndless(JourneyFlameGame game, double dt) {
    final hud = game.controller.hud;
    if (hud.endlessWave.value != game._endlessWave) {
      hud.endlessWave.value = game._endlessWave;
    }
    if (game._endlessRest > 0) {
      game._endlessRest -= dt;
      return;
    }
    final n = game._endlessWave;
    final waveConf = game.config?.endlessWaveOf(n);
    final count = waveConf?.count ?? endlessWaveCount(n);
    final buff = waveConf?.buffMult ?? endlessWaveBuff(n);
    // 本波精英只数：后台配置优先，0（含新列未部署）=按波号公式兜底；
    // 精英恒留至少 1 个普通怪位，保证先发育后施压
    final eliteCount = waveConf != null && waveConf.eliteCount > 0
        ? waveConf.eliteCount
        : endlessEliteCount(n);
    final elite = math.min(eliteCount, math.max(0, count - 1));
    // 波次怪种：普通/精英怪=该波普通段只刷该怪；选妖王=妖王波
    // （首只妖王 + 小怪护卫，其余数量按 count 配置）
    final configuredCode = waveConf?.monsterCode ?? '';
    final isBossWave = configuredCode.isNotEmpty &&
        _monsterSource(game).any((m) => m.code == configuredCode && m.isBoss);

    if (game._endlessSpawned >= count) {
      // 除尽推进：本波怪（含妖王）全灭才进下一波
      final alive =
          game.monsters.any((m) => !m.isDead && m.endlessWave == n);
      if (alive) return;
      if (n >= 99) {
        // 末波（第 99 波）清空 → 终局：挂功成横幅（endless 预置
        // _bossDefeated=true，不走门控直接标记），2.4s 播报完整后自动
        // 结算（期间玩家也可点常亮的结算按钮提前结算）
        if (!game._endlessSettleScheduled) {
          game._endlessSettleScheduled = true;
          game._markClearedAvailable('妖潮无尽·功成');
          dart_async.Timer(const Duration(milliseconds: 2400), () {
            if (!game.isEnded) game.settleNow();
          });
        }
        return;
      }
      game._endlessWave = n + 1;
      game._endlessSpawned = 0;
      game._endlessRest = 1.2;
      return;
    }
    game._endlessTimer += dt;
    // 每波约 18 秒铺完（50 只→0.35s、120 只→0.15s），保持割草节奏
    final interval = (18.0 / count).clamp(0.12, 0.35);
    if (game._endlessTimer < interval) return;
    if (game.monsters.length >= game.monsterCap) return;
    final spawned = game._endlessSpawned;
    final isElite = elite > 0 && spawned >= count - elite;
    final model = (isBossWave && spawned == 0)
        ? _bossModelOf(game, configuredCode)
        : _pickEndlessMonster(game, n, isElite ? '' : configuredCode,
            elite: isElite);
    if (model == null) return;
    game._endlessTimer = 0;
    spawnMonsterAt(game, model, buffMult: buff, position: null);
    game.monsters.last.endlessWave = n;
    game._endlessSpawned++;
    // 妖王波首只现身：走 onBossSpawn 统一播报「妖王降临 · X」（HUD 状态同步）
    if (isBossWave && spawned == 0) {
      game.controller.onBossSpawn(model.name);
    }
  }

  /// 妖王波取怪：怪物全源按 code 取妖王（endless 刷怪池不含妖王）。
  JourneyMonsterModel? _bossModelOf(JourneyFlameGame game, String code) {
    for (final m in _monsterSource(game)) {
      if (m.code == code && m.isBoss) return m;
    }
    return null;
  }

  /// 无尽怪池挑选：普通段尊重后台配置的怪种（配置断裂回落分阶随机池），
  /// 精英段强制走分阶精英池，保证每波末尾都有精英施压。
  JourneyMonsterModel? _pickEndlessMonster(
    JourneyFlameGame game,
    int waveNo,
    String configuredCode, {
    required bool elite,
  }) {
    if (!elite && configuredCode.isNotEmpty) {
      final hit = game.pool
          .where((m) => m.code == configuredCode)
          .toList(growable: false);
      if (hit.isNotEmpty) return hit[game.rng.nextInt(hit.length)];
    }
    final pool = endlessTierPool(game, waveNo: waveNo, elite: elite);
    if (pool.isEmpty) return null;
    return pool[game.rng.nextInt(pool.length)];
  }

  /// 每日游历·铜钱雨：每 4s 在玩家环带 spawn 5 枚功德铜钱，
  /// 每枚价值=pickupConfigOf('gongde_tongqian').value×10（缺省 30）。
  void _updateDailyCoinRain(JourneyFlameGame game, double dt) {
    game._dailyCoinTimer += dt;
    if (game._dailyCoinTimer < 4) return;
    game._dailyCoinTimer = 0;
    // 每日铜钱单价固定 8，与普通铜钱(3)保持同一量级，压低每日总产出
    const unit = 8;
    final size = game.worldSize;
    for (var i = 0; i < 4; i++) {
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
