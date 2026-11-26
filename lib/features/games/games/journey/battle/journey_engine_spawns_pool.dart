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
  // 逐战编排时把所有场次妖王纳入池，避免后续场次换妖而池里没有该怪。
  final levelId = game.level.id;
  final fightCodes = levelId.isEmpty
      ? const <String>{}
      : game.config?.bossFightsOf(levelId).map((f) => f.bossCode).toSet() ??
          const <String>{};
  final boss = source
      .where((m) =>
          m.isBoss && (m.code == bossCode || fightCodes.contains(m.code)))
      .toList(growable: false);
  if (game.runtime.waves.isNotEmpty) {
    // 波次关：池=波次怪种（映射断裂的行已在 config service 过滤）∪ 妖王
    final waveCodes = <String>{for (final w in game.runtime.waves) w.monsterCode};
    final mobs = source
        .where((m) => !m.isBoss && waveCodes.contains(m.code))
        .toList();
    return <JourneyMonsterModel>[...mobs, ...boss];
  }
  return source
      .where((m) => !m.isBoss || m.code == bossCode || fightCodes.contains(m.code))
      .toList();
}

/// 本关妖王编码：
/// - 无尽/游历（虚拟关 kind=endless/daily）：无妖王模式，恒 null；
/// - 关卡级 boss_code（journey_levels.boss_code）优先：非空即本关妖王
///   （车迟国三关借此各挂虎力/鹿力/羊力，空串=本关显式无妖王战）；
/// - 关卡未配：取区域 boss_code（NULL=原著无妖章回，引擎走「西行里程」口径）；
/// - 远端未就绪/内置兜底快照：回落关卡号区间映射（保可玩）。
String? resolveBossCode(JourneyFlameGame game) {
  if (_isEndless(game) || _isDaily(game)) return null;
  final levelBoss = game.level.bossCode;
  // 关卡显式配置优先：空串=本关无妖王战（走西行里程），非空=覆盖本段妖王。
  if (levelBoss != null) return levelBoss.isEmpty ? null : levelBoss;
  final region = game.config?.regionOf(game.level.regionCode);
  if (game.config?.fromSeed != true && region != null) {
    final configured = region.bossCode;
    return (configured != null && configured.isNotEmpty) ? configured : null;
  }
  return _fallbackBossCode(game.level.levelNo);
}

/// 兜底映射：区域配置未就绪时按关卡区间取妖王（近似原著章回；
/// 无妖章回返回 null，走西行里程口径，与远端 boss_code=NULL 语义一致）。
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

JourneyMonsterModel? _bossOfRegion(JourneyFlameGame game) =>
    bossModelForFight(game, 1);

/// 按场次解析妖王模型：journey_level_boss_fights 有该场编排则按 boss_code
/// 取（可同关逐场不同妖王）；无编排行时回落现有三级解析，行为与改造前一致。
JourneyMonsterModel? bossModelForFight(
  JourneyFlameGame game,
  int fightNo,
) {
  final source = _monsterSource(game);
  final levelId = game.level.id;
  final fight = levelId.isEmpty
      ? null
      : game.config?.bossFightAt(levelId, fightNo);
  final code = fight?.bossCode ?? resolveBossCode(game);
  if (code == null) return null;
  for (final m in source) {
    if (m.code == code && m.isBoss) return m;
  }
  return null;
}

/// 当前场次的彩蛋/剧情标签（编排表 note）；无编排返回空串。
String bossFightNote(JourneyFlameGame game, int fightNo) {
  final levelId = game.level.id;
  if (levelId.isEmpty) return '';
  return game.config?.bossFightAt(levelId, fightNo)?.note ?? '';
}

/// 怪物全源（远端优先，种子兜底）：主线按 code 取关卡妖王、妖潮期
/// 从全池随机取妖王共用；无尽刷怪池不含妖王，妖王取怪须走全源。
List<JourneyMonsterModel> _monsterSource(JourneyFlameGame game) {
  final remote = game.config?.monsters ?? const <JourneyMonsterModel>[];
  return remote.isNotEmpty
      ? List<JourneyMonsterModel>.of(remote)
      : kJourneyMonsterSeed.map(JourneyMonsterModel.fromJson).toList();
}

/// 经验池兜底曲线：后台未配该波或新列未部署时，按波号推演每波总量、
/// 精英数与强度倍率，保证「每波 50~120 只、每波有精英」的节奏始终成立。
/// 总量与倍率都用整数算式取整，和后台、线上配置同口径：浮点累加在
/// 半整数边界会取整偏 1 只，整数算式不受表示误差影响。
int endlessWaveCount(int waveNo) =>
    math.min(120, (505 + 7 * (waveNo - 1)) ~/ 10);

int endlessEliteCount(int waveNo) => math.min(14, 2 + waveNo ~/ 8);

double endlessWaveBuff(int waveNo) => (100 + 3 * waveNo) / 100;

/// 分阶怪池：普通段前期只出低血小妖，避免高血「伪普通」怪打断发育；
/// 精英段按波号取对应经验档（与精英经验重标定的分档渐变对齐：
/// 小型 22~28 / 中型 55~68 / 大型 140~170），强度随波次递进且
/// 不会前期撞上顶阶精英。
List<JourneyMonsterModel> endlessTierPool(
  JourneyFlameGame game, {
  required int waveNo,
  required bool elite,
}) {
  final all = game.pool.where((m) => !m.isBoss).toList(growable: false);
  if (elite) {
    final lo = waveNo <= 10 ? 0 : (waveNo <= 60 ? 40 : 120);
    final hi = waveNo <= 10 ? 35 : (waveNo <= 60 ? 120 : 200);
    final band = all
        .where((m) => m.isElite && m.expDrop >= lo && m.expDrop <= hi)
        .toList(growable: false);
    if (band.isNotEmpty) return band;
    return all.where((m) => m.isElite).toList(growable: false);
  }
  final commons = all.where((m) => !m.isElite).toList(growable: false);
  if (waveNo < 40) {
    final low = commons.where((m) => m.baseHp <= 200).toList(growable: false);
    if (low.isNotEmpty) return low;
  }
  return commons.isNotEmpty ? commons : all;
}

/// 兜底刷怪选怪（波次缺失时的遭遇战来源）：
/// - 生态轮换（角色等级分带线 10/16/26，分档血量阈值 600/2800）——
///   精英登场分阶：10 级前只小型精英、26 级前不见大型精英、之后全量，
///   低级不撞顶阶精英、高级不刷低阶小精英；
/// - 普怪退场曲线：16 级起出现概率线性衰减、26 级绝迹（只刷精英）。
///   能力上升后小怪不再刷，遭遇战换成可秒杀的精英——爽感锚点迁移；
///   铺场（allowElite=false）与保护期不受轮换影响；
/// - 保护期内不产生精英；保护期过后按局内时间线性增长并钳上限
///   （分带轮换之外的既有精英率口径）。
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
  final charLv = game._charLv;
  final elites = _ecologyElitePool(pool, charLv);

  final pCommon = (allowElite &&
          elapsed >= protectSec &&
          charLv > kJourneyEcoCommonFadeLv)
      ? (1.0 -
              (charLv - kJourneyEcoCommonFadeLv) /
                  (kJourneyEcoCommonOutLv - kJourneyEcoCommonFadeLv))
          .clamp(0.0, 1.0)
      : 1.0;
  if (pCommon < 1.0 &&
      elites.isNotEmpty &&
      game.rng.nextDouble() >= pCommon) {
    return elites[game.rng.nextInt(elites.length)];
  }

  final eliteRate = (elapsed < protectSec || !allowElite)
      ? 0.0
      : (((elapsed - protectSec) / 60.0) *
              (game.config?.eliteRatePerMin ?? kJourneyEliteRatePerMin))
          .clamp(0.0, game.config?.eliteRateCap ?? kJourneyEliteRateCap);
  if (eliteRate > 0 && elites.isNotEmpty && game.rng.nextDouble() < eliteRate) {
    return elites[game.rng.nextInt(elites.length)];
  }
  // 普通怪单独取样：保护期内排除高血「伪普通」怪，未命中精英率时
  // 也不把精英混进随机结果
  final commons = pool
      .where((m) => !m.isElite && (elapsed >= protectSec || m.baseHp <= 200))
      .toList();
  final fallback = pool.where((m) => !m.isElite).toList();
  final candidates = commons.isNotEmpty
      ? commons
      : (fallback.isNotEmpty ? fallback : pool);
  return candidates[game.rng.nextInt(candidates.length)];
}

/// 生态轮换精英分阶池：按角色等级限定登场档位（小型 ≤600 / 中型
/// ≤2800 / 大型 >2800 血量档）；分档后为空时回落全量精英池防死局。
List<JourneyMonsterModel> _ecologyElitePool(
  List<JourneyMonsterModel> pool,
  int charLv,
) {
  final elites = pool.where((m) => m.isElite).toList();
  if (elites.isEmpty) return elites;
  final band = charLv < kJourneyEcoEliteInLv
      ? elites.where((m) => m.baseHp <= kJourneyEcoEliteMidHp).toList()
      : charLv < kJourneyEcoCommonOutLv
          ? elites.where((m) => m.baseHp <= kJourneyEcoEliteLargeHp).toList()
          : elites;
  return band.isNotEmpty ? band : elites;
}

