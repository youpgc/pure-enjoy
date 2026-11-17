part of 'journey_flame_game.dart';

/// 无尽妖潮波次生成器（自 journey_engine_spawns.dart 迁出）：
/// - **发育期**（妖潮起点前）：小怪普通段+末尾精英，不降临妖王（妖王
///   波统一并入妖潮期）；
/// - **妖潮期**（妖潮起点起）：小怪淡出为「精英为主+少量小怪」
///   （guard_elite_ratio）；妖王波为**妖王潮配额制**——同波配额只
///   依次降临（同场并发钳制 + 缺口出现按降临倒计时补位，不在同一
///   时间刷新），种类从全妖王池随机，每只降临播报并赋软领地（锚点
///   散布+leash 杜绝群殴）；妖潮起点=波次表首个 boss_count>0 的波；
/// - 波次配置 journey_endless_waves 优先：boss_count>0 即妖王波，怪种
///   仅决定普通段/护卫怪种；count 为本波护卫总量、elite_count 末尾精英数、
///   boss_count 本波妖王配额（0=全局公式兜底）；未配置按经验池公式推演；
/// - 除尽推进不变：本波怪全灭且妖王配额耗尽才进下一波；末波（99）
///   清空→「妖潮无尽·功成」可结算。
void journeyEndlessTick(JourneyFlameGame game, double dt) {
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
  // 妖潮期判定以后台波次表实际配置为准：首个 boss_count>0 的波即妖潮起点；
  // 波次表无配额配置时回落全局 tide_start_wave（默认第 10 波）。
  final tideStart = _endlessTideStartWave(game);
  final tide = tideStart != null && n >= tideStart;
  // 本波精英只数：后台配置优先，0（含新列未部署）=按波号公式兜底；
  // 精英恒留至少 1 个普通怪位，保证先发育后施压
  final eliteCount = waveConf != null && waveConf.eliteCount > 0
      ? waveConf.eliteCount
      : endlessEliteCount(n);
  final elite = math.min(eliteCount, math.max(0, count - 1));
  // 波次怪种只决定普通段/护卫怪种；妖王波由 boss_count>0 判定，与怪种解耦。
  final configuredCode = waveConf?.monsterCode ?? '';
  // 妖潮期妖王波配额：波行 boss_count>0 即妖王波，0=全局基数+递增公式兜底；
  // 发育期（妖潮起点前）恒无妖王。
  final bossQuota = !tide
      ? 0
      : (waveConf != null && waveConf.bossCount > 0
          ? waveConf.bossCount
          : _endlessBossQuota(game, n, tideStart));

  if (game._endlessSpawned >= count) {
    // 除尽推进：本波怪全灭且妖王配额已耗尽才进下一波
    final alive =
        game.monsters.any((m) => !m.isDead && m.endlessWave == n);
    if (alive || game._endlessBossSummoned < bossQuota) return;
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
    game._endlessBossSummoned = 0;
    game._endlessBossKilled = 0;
    game._jinjiaoWaveRefines = 0;
    game._endlessBossCd = 0;
    hud.bossSpawnIn.value = 0;
    return;
  }

  // 妖王潮补位降临：同场并发钳制 + 依次降临（倒计时后台可配）
  if (bossQuota > 0) {
    _tickEndlessBossTide(
        game, n, configuredCode, buff, tideStart, bossQuota, dt);
  }

  game._endlessTimer += dt;
  // 每波约 18 秒铺完（50 只→0.35s、120 只→0.15s），保持割草节奏
  final interval = (18.0 / count).clamp(0.12, 0.35);
  if (game._endlessTimer < interval) return;
  if (game.monsters.length >= game.monsterCap) return;
  final spawned = game._endlessSpawned;
  final isElite = elite > 0 && spawned >= count - elite;
  // 妖王全部走妖潮补位降临 tick；本段只铺普通段/护卫小怪。
  final model = _pickEndlessMonster(game, n, configuredCode,
      elite: isElite, tideGuard: tide);
  if (model == null) return;
  game._endlessTimer = 0;
  game.spawnMonsterAt(game, model, buffMult: buff, position: null);
  game.monsters.last.endlessWave = n;
  game._endlessSpawned++;
}

/// 妖潮起点波号：波次表中首个配置妖王配额（boss_count>0）的波——
/// 妖潮期以后台实际配置为准；波次表无任何配额配置时回落全局
/// tide_start_wave（默认第 10 波起，与前 9 波发育期节奏一致）。
int? _endlessTideStartWave(JourneyFlameGame game) {
  int? start;
  for (final w in game.config?.endlessWaves ?? const []) {
    if (w.bossCount > 0 && (start == null || w.waveNo < start)) {
      start = w.waveNo;
    }
  }
  return start ??
      (game.config?.endlessBossTideStartWave ??
          kJourneyEndlessBossTideStartWave);
}

/// 妖潮期每波妖王配额兜底公式：自妖潮起点线性递增至终波满额——
/// quota = (n − 起点 + 1) × 11 ~/ 10（整数算式），起点 10 时
/// 波10=1、波20=12、波50=45、波99=99；波行 boss_count 优先于本公式。
/// 同波配额限刷新总量（默认上限 99），同屏在场数由并发上限独立钳制。
int _endlessBossQuota(JourneyFlameGame game, int n, int? tideStart) {
  final cap = game.config?.endlessBossCountCap ?? kJourneyEndlessBossCountCap;
  if (tideStart == null) return 0;
  return (((n - tideStart + 1) * 11) ~/ 10).clamp(1, cap);
}

/// 妖王潮降临节拍：同场并发钳制；配额内首只立即降临，此后缺口出现
/// （击杀腾位）按降临倒计时依次补位——任意两次降临间隔 ≥ 倒计时，
/// 不在同一时间刷新；倒计时同步罗盘位「妖王降临 · Xs」。
void _tickEndlessBossTide(
  JourneyFlameGame game,
  int n,
  String configuredCode,
  double buff,
  int? tideStart,
  int quota,
  double dt,
) {
  final concurrent =
      (game.config?.endlessBossConcurrent ?? kJourneyEndlessBossConcurrent)
          .clamp(1, 10);
  var aliveBosses = 0;
  for (final m in game.monsters) {
    if (!m.isDead && m.endlessWave == n && m.model.isBoss) aliveBosses++;
  }
  if (game._endlessBossSummoned >= quota) return;
  if (aliveBosses >= concurrent) {
    game._endlessBossCd = 0;
    game.controller.hud.bossSpawnIn.value = 0;
    return;
  }
  // 首只立即降临；后续缺口按降临倒计时补位
  if (game._endlessBossSummoned > 0 && game._endlessBossCd <= 0) {
    game._endlessBossCd =
        game.config?.endlessBossArriveCd ?? kJourneyEndlessBossArriveCd;
    return;
  }
  if (game._endlessBossCd > 0) {
    game._endlessBossCd -= dt;
    final left = game._endlessBossCd.ceil();
    if (game._endlessBossCd > 0) {
      if (game.controller.hud.bossSpawnIn.value != left) {
        game.controller.hud.bossSpawnIn.value = left;
      }
      return;
    }
    game.controller.hud.bossSpawnIn.value = 0;
  }
  _summonEndlessBoss(game, n, configuredCode, buff, tideStart);
}

/// 降临一只妖王：经验/速度/接触伤害走共用乘区（波次 buff ×(1+步进×
/// amp_per_wave)，钳 buff_mult_cap）；血量走独立波次乘区（hp_amp 每
/// 波额外增幅）且不吃玩家等级项——波次项对标玩家 DPS 成长，终盘
/// 妖王单挑 30~70 秒量级，最后几波满级也需操作；位置按玩家环带
/// 锚点散布（与在场妖王锚点保持最小间距），赋软领地半径并播报。
void _summonEndlessBoss(
  JourneyFlameGame game,
  int n,
  String configuredCode,
  double buff,
  int? tideStart,
) {
  final model = _randomTideBoss(game, configuredCode);
  if (model == null) return;
  final amp =
      game.config?.endlessBossAmpPerWave ?? kJourneyEndlessBossAmpPerWave;
  final hpAmp = game.config?.endlessBossHpAmp ?? kJourneyEndlessBossHpAmp;
  final stepped = tideStart != null ? n - tideStart : 0;
  final stepBoost = 1 + (stepped > 0 ? stepped : 0) * amp;
  game.spawnMonsterAt(
    game,
    model,
    buffMult: buff * stepBoost,
    hpBuffMult: buff * (1 + (stepped > 0 ? stepped : 0) * hpAmp),
    bossLvHpTerm: false,
    position: _endlessBossSpawnPos(game),
  );
  final comp = game.monsters.last;
  comp.endlessWave = n;
  comp.territoryRadius =
      game.config?.endlessBossTerritoryRadius ??
          kJourneyEndlessBossTerritoryRadius;
  game._endlessBossSummoned++;
  game.controller.onBossSpawn(model.name);
}

/// 妖王降临点：玩家活动环带随机取样，与在场存活妖王的锚点（home）
/// 保持最小间距——领地不重叠；取样未命中时取间距最大候选兜底。
Vector2 _endlessBossSpawnPos(JourneyFlameGame game) {
  final minDist =
      game.config?.endlessBossSpreadMinDist ?? kJourneyEndlessBossSpreadMinDist;
  final anchors = <Vector2>[
    for (final m in game.monsters)
      if (!m.isDead && m.model.isBoss) m.home,
  ];
  final size = game.worldSize;
  Vector2? best;
  var bestScore = -1.0;
  for (var i = 0; i < 12; i++) {
    final angle = game.rng.nextDouble() * math.pi * 2;
    final dist = 420.0 + game.rng.nextDouble() * 780.0;
    final p = Vector2(
      (game.player.position.x + math.cos(angle) * dist)
          .clamp(80.0, size - 80),
      (game.player.position.y + math.sin(angle) * dist)
          .clamp(80.0, size - 80),
    );
    var nearest = double.infinity;
    for (final a in anchors) {
      final d = (p - a).length;
      if (d < nearest) nearest = d;
    }
    if (anchors.isEmpty || nearest >= minDist) return p;
    if (nearest > bestScore) {
      bestScore = nearest;
      best = p;
    }
  }
  return best ??
      Vector2(
        (game.player.position.x + minDist).clamp(80.0, size - 80),
        game.player.position.y,
      );
}

/// 妖王波取怪：怪物全源按 code 取妖王（endless 刷怪池不含妖王）。
JourneyMonsterModel? _bossModelOf(JourneyFlameGame game, String code) {
  for (final m in _monsterSource(game)) {
    if (m.code == code && m.isBoss) return m;
  }
  return null;
}

/// 妖潮期降临取怪：从怪物全源的全部妖王里随机取一只，使同波配额内
/// 可出现多种妖王。候选池为空（远端怪物表缺失且种子无妖王）时按配置
/// code 回落兜底。
JourneyMonsterModel? _randomTideBoss(JourneyFlameGame game, String code) {
  final bosses = _monsterSource(game).where((m) => m.isBoss).toList();
  if (bosses.isEmpty) return _bossModelOf(game, code);
  return bosses[game.rng.nextInt(bosses.length)];
}

/// 无尽怪池挑选：精英段强制走分阶精英池；普通段尊重后台配置的怪种
/// （配置断裂回落分阶随机池）；妖潮期普通段/护卫按 guard_elite_ratio
/// 「精英为主+少量小怪」取样（少量小怪仍优先配置怪种），保证中后期
/// 小怪淡出、精英成为经验发动机。
JourneyMonsterModel? _pickEndlessMonster(
  JourneyFlameGame game,
  int waveNo,
  String configuredCode, {
  required bool elite,
  bool tideGuard = false,
}) {
  if (!elite && tideGuard) {
    final ratio = game.config?.endlessBossGuardEliteRatio ??
        kJourneyEndlessBossGuardEliteRatio;
    if (game.rng.nextDouble() < ratio) {
      final pool = endlessTierPool(game, waveNo: waveNo, elite: true);
      if (pool.isNotEmpty) return pool[game.rng.nextInt(pool.length)];
    }
    // 少量小怪：优先配置怪种，断裂回落普通分阶池
    if (configuredCode.isNotEmpty) {
      final hit = game.pool
          .where((m) => m.code == configuredCode)
          .toList(growable: false);
      if (hit.isNotEmpty) return hit[game.rng.nextInt(hit.length)];
    }
    final commonPool = endlessTierPool(game, waveNo: waveNo, elite: false);
    if (commonPool.isNotEmpty) {
      return commonPool[game.rng.nextInt(commonPool.length)];
    }
    // 普通池也空：回落全量精英池防死局
  }
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
