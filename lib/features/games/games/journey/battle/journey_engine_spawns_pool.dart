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
/// - 无尽/游历（虚拟关 kind=endless/daily）：无妖王模式，恒 null；
/// - 远端区域行存在：boss_code 即定稿口径（NULL=原著无妖章回，无妖王战，
///   引擎走「坚持通关」口径）；
/// - 区域行缺失/内置兜底快照：回落关卡号区间映射（保可玩，每关有妖王）。
String? resolveBossCode(JourneyFlameGame game) {
  if (_isEndless(game) || _isDaily(game)) return null;
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
  final source = _monsterSource(game);
  for (final m in source) {
    if (m.code == code && m.isBoss) return m;
  }
  return null;
}

/// 怪物全源（远端优先，种子兜底）：妖王波判定/指定怪种刷怪共用——
/// 无尽妖潮刷怪池不含妖王，波次配置的怪种语义需在全源上判定。
List<JourneyMonsterModel> _monsterSource(JourneyFlameGame game) {
  final remote = game.config?.monsters ?? const <JourneyMonsterModel>[];
  return remote.isNotEmpty
      ? List<JourneyMonsterModel>.of(remote)
      : kJourneyMonsterSeed.map(JourneyMonsterModel.fromJson).toList();
}

