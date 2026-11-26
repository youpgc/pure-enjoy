import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import '../models/journey_unlock_models.dart';
import 'journey_seed.dart';

part 'journey_config_unlock_access.dart';
part 'journey_config_globals_access.dart';

/// 西行·配置快照（一次聚合全部 journey_* 静态配置）。
class JourneyConfigSnapshot {
  final List<JourneyRegionModel> regions;
  final List<JourneyLevelModel> levels;
  final List<JourneyCharacterModel> characters;
  final List<JourneyWeaponModel> weapons;

  /// 五行天赋分支（4 角色 × 5 系 × 3 分支 = 60 行；v4 分支树制）。
  final List<JourneyTalentBranchModel> talentBranches;

  /// 怪物池（journey_monsters 远端配置；空=引擎回落内置种子池）。
  final List<JourneyMonsterModel> monsters;

  /// 武器维度槽定义（journey_weapon_slots；空=引擎回落内置兜底）。
  final List<JourneySlotDefModel> slotDefs;

  /// 三选一基础值成长卡（journey_upgrade_cards；空=引擎回落内置兜底）。
  final List<JourneyUpgradeCardModel> upgradeCards;

  /// 法宝分级（journey_weapon_levels，按法宝 code 分组，lv 升序）；
  /// 空=引擎回落内置基准数值。
  final Map<String, List<JourneyWeaponLevelModel>> weaponLevels;

  /// 掉落表（journey_drops，table_code 分组）；空=消费侧回落内置种子。
  final List<JourneyDropModel> drops;

  /// 炼化配方（journey_evo_recipes，seq 升序=判定优先级）；
  /// 空=消费侧回落内置种子。
  final List<JourneyEvoRecipeModel> evoRecipes;

  /// 图鉴解锁（journey_relic_unlocks，seq 升序）；空=消费侧回落内置种子。
  final List<JourneyRelicUnlockModel> relicUnlocks;

  /// 统一解锁规则（journey_unlock_entries）；空=三类目标均不设门控。
  final List<JourneyUnlockEntryModel> unlockEntries;

  /// 拾取物配置（journey_pickups，code 升序）；空=消费侧回落内置种子。
  final List<JourneyPickupConfigModel> pickupConfigs;

  /// 每日游历地图列表（journey_daily_maps，后台可配）；空=消费侧回落种子。
  final List<JourneyDailyMapModel> dailyMaps;

  /// 无尽妖潮波次配置（journey_endless_waves，上限 99；空=全部内置公式）。
  final List<JourneyEndlessWaveModel> endlessWaves;

  /// 法宝数值参数（journey_weapon_params，code 分组：weaponCode→{code→值}；
  /// 空=引擎全部走内置兜底）。
  final Map<String, Map<String, double>> weaponParams;

  /// 妖王能力参数（journey_monster_params，code 分组：monsterCode→{code→值}；
  /// 空=引擎全部走内置兜底）。
  final Map<String, Map<String, double>> monsterParams;

  /// 妖王能力行（journey_monster_abilities，monsterCode 分组，slot 升序）。
  /// 空=沿用 journey_monsters.ability_key 单值，行为与改造前一致。
  final Map<String, List<JourneyMonsterAbilityModel>> monsterAbilities;

  /// 能力专属参数（journey_monster_ability_params，
  /// key='monsterCode|abilityKey' → {参数code→值}）；优先级高于 monsterParams。
  final Map<String, Map<String, double>> monsterAbilityParams;

  /// 同关逐战妖王编排（journey_level_boss_fights，levelId 分组，fightNo 升序）。
  /// 空=沿用关卡>区域>内置兜底的三级解析。
  final Map<String, List<JourneyLevelBossFightModel>> levelBossFights;

  /// journey_globals 原始行（通用成长卡/经验曲线等扩展列直读；
  /// 列缺失/seed 快照为 null 时消费侧回落内置兜底）。
  final Map<String, dynamic>? globalsRaw;

  /// 通用战斗参数（journey_battle_params，key = 'group_code.param_code'）：
  /// 数值型与文本型分表存储，引擎按分组+语义键读取；未配置或停用的参数
  /// 不写入，消费侧经 [battleNum]/[battleText] 回落内置常量。
  final Map<String, double> battleParamsNum;
  final Map<String, String> battleParamsText;

  /// 西行游戏 id（games.code='journey'；成绩上报用，空=未就绪不上报）。
  final String gameId;

  /// 成绩维度 id（game_dimensions，code→id：farthest_level/run_kills/
  /// run_merit）；成绩上报 values 键，空=未配置不上报。
  final Map<String, String> scoreDimIds;

  /// true = 全部来自内置兜底（journey_* 表未部署或拉取失败）。
  final bool fromSeed;

  /// 通用战斗参数键：分组码与语义键拼成唯一键。
  static String battleKey(String group, String code) => '$group.$code';

  /// 数值型战斗参数：未配置走 [fallback]。引擎逐项传入原内置常量，
  /// 保证参数表未部署/未配置时行为与改造前一致。
  double battleNum(String group, String code, double fallback) =>
      battleParamsNum[battleKey(group, code)] ?? fallback;

  /// 枚举/文本型战斗参数：未配置走 [fallback]。
  String battleText(String group, String code, String fallback) =>
      battleParamsText[battleKey(group, code)] ?? fallback;

  const JourneyConfigSnapshot({
    required this.regions,
    required this.levels,
    required this.characters,
    required this.weapons,
    required this.talentBranches,
    this.monsters = const <JourneyMonsterModel>[],
    this.slotDefs = const <JourneySlotDefModel>[],
    this.upgradeCards = const <JourneyUpgradeCardModel>[],
    this.weaponLevels = const <String, List<JourneyWeaponLevelModel>>{},
    this.drops = const <JourneyDropModel>[],
    this.evoRecipes = const <JourneyEvoRecipeModel>[],
    this.relicUnlocks = const <JourneyRelicUnlockModel>[],
    this.unlockEntries = const <JourneyUnlockEntryModel>[],
    this.pickupConfigs = const <JourneyPickupConfigModel>[],
    this.dailyMaps = const <JourneyDailyMapModel>[],
    this.endlessWaves = const <JourneyEndlessWaveModel>[],
    this.weaponParams = const <String, Map<String, double>>{},
    this.monsterParams = const <String, Map<String, double>>{},
    this.monsterAbilities = const <String, List<JourneyMonsterAbilityModel>>{},
    this.monsterAbilityParams = const <String, Map<String, double>>{},
    this.levelBossFights = const <String, List<JourneyLevelBossFightModel>>{},
    this.battleParamsNum = const <String, double>{},
    this.battleParamsText = const <String, String>{},
    this.globalsRaw,
    this.gameId = '',
    this.scoreDimIds = const <String, String>{},
    required this.fromSeed,
  });

  /// 维度定义（code → def）；远端空表回落内置种子。
  Map<String, JourneySlotDefModel> slotDefMap() {
    final defs = slotDefs.isNotEmpty
        ? slotDefs
        : kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson).toList();
    return <String, JourneySlotDefModel>{for (final d in defs) d.code: d};
  }

  /// 基础值成长卡（code → 卡）；远端空表回落内置种子。
  Map<String, JourneyUpgradeCardModel> upgradeCardMap() {
    final cards = upgradeCards.isNotEmpty
        ? upgradeCards
        : kJourneyUpgradeCardSeed.map(JourneyUpgradeCardModel.fromJson).toList();
    return <String, JourneyUpgradeCardModel>{for (final c in cards) c.code: c};
  }

  JourneyRegionModel? regionOf(String code) {
    for (final r in regions) {
      if (r.code == code) return r;
    }
    return null;
  }

  JourneyWeaponModel? weaponOf(String code) {
    for (final w in weapons) {
      if (w.code == code) return w;
    }
    return null;
  }

  /// 每日游历地图（code 匹配；仅内置兜底快照回落种子）。
  JourneyDailyMapModel? dailyMapOf(String code) {
    for (final m in dailyMapList()) {
      if (m.code == code) return m;
    }
    return null;
  }

  /// 无尽妖潮波次（wave_no 匹配；未配置该波走引擎内置公式）。
  JourneyEndlessWaveModel? endlessWaveOf(int waveNo) {
    for (final w in endlessWaves) {
      if (w.waveNo == waveNo) return w;
    }
    return null;
  }

  /// 每日游历地图列表：组装侧已保证未加载的表回落内置种子，已加载的
  /// 空列表代表后台全部禁用（App 显示「今日暂无游历」）。
  List<JourneyDailyMapModel> dailyMapList() => dailyMaps;

  /// 法宝数值参数（weaponCode+参数 code 读取；行缺失回落 fallback）。
  double weaponParam(String weaponCode, String code, double fallback) {
    return weaponParams[weaponCode]?[code] ?? fallback;
  }

  /// 妖王能力参数（monsterCode+参数 code 读取；行缺失回落 fallback）。
  double monsterParam(String monsterCode, String code, double fallback) {
    return monsterParams[monsterCode]?[code] ?? fallback;
  }

  /// 能力专属参数键：怪物编码与能力键拼接，避免共享参数键跨能力串值。
  static String abilityParamKey(String monsterCode, String abilityKey) =>
      '$monsterCode|$abilityKey';

  /// 能力作用域参数：能力专属 > 怪物级 > fallback。
  /// 多能力共存时同一参数键（如 blind_sec）按能力各取一套值。
  double abilityParam(
    String monsterCode,
    String abilityKey,
    String code,
    double fallback,
  ) {
    return monsterAbilityParams[abilityParamKey(monsterCode, abilityKey)]?[code] ??
        monsterParams[monsterCode]?[code] ??
        fallback;
  }

  /// 妖王能力行（monsterCode；已按 slot 升序）；空列表=回落单值 abilityKey。
  List<JourneyMonsterAbilityModel> abilitiesOf(String monsterCode) =>
      monsterAbilities[monsterCode] ?? const <JourneyMonsterAbilityModel>[];

  /// 同关逐战编排（levelId；已按 fightNo 升序）；空列表=走旧三级解析。
  List<JourneyLevelBossFightModel> bossFightsOf(String levelId) =>
      levelBossFights[levelId] ?? const <JourneyLevelBossFightModel>[];

  /// 指定场次的妖王编码与彩蛋标签；无编排行时返回 null 走旧逻辑。
  ({String bossCode, String note})? bossFightAt(String levelId, int fightNo) {
    for (final f in bossFightsOf(levelId)) {
      if (f.fightNo == fightNo) {
        return (bossCode: f.bossCode, note: f.note);
      }
    }
    return null;
  }

  List<JourneyLevelModel> levelsOfRegion(String regionCode) =>
      levels.where((l) => l.regionCode == regionCode).toList()
        ..sort((a, b) => a.levelNo.compareTo(b.levelNo));

  /// 掉落表行（tableCode 组；未配置返回空列表，消费侧兜底）。
  List<JourneyDropModel> dropTableOf(String tableCode) =>
      drops.where((d) => d.tableCode == tableCode).toList();

  /// 武器第一条炼化配方（seq 升序首条；无配方返回 null）。
  JourneyEvoRecipeModel? evoRecipeOf(String weaponCode) {
    for (final r in evoRecipes) {
      if (r.weaponCode == weaponCode) return r;
    }
    return null;
  }

  /// 拾取物配置（未配置返回 null）。
  JourneyPickupConfigModel? pickupConfigOf(String code) {
    for (final p in pickupConfigs) {
      if (p.code == code) return p;
    }
    return null;
  }

  /// 某角色的五行天赋分支（element/seq 升序）；该角色无远端行 → 内置
  /// 60 行种子按同角色过滤兜底，消费侧不死局。
  List<JourneyTalentBranchModel> branchesOf(String char) {
    final own = talentBranches.where((b) => b.characterCode == char).toList();
    if (own.isEmpty) {
      return buildJourneyTalentBranchSeed()
          .where((row) => row['character_code'] == char)
          .map(JourneyTalentBranchModel.fromJson)
          .toList();
    }
    return own
      ..sort((a, b) {
        final byElement = a.element.compareTo(b.element);
        return byElement != 0 ? byElement : a.seq.compareTo(b.seq);
      });
  }

  /// 某角色某系某分支（远端行缺失回落内置种子行）。
  JourneyTalentBranchModel branchOf(
      String char, String element, String branchType) {
    for (final b in branchesOf(char)) {
      if (b.element == element && b.branchType == branchType) return b;
    }
    // 异常配置（分支行被删）：给中性默认分支
    return JourneyTalentBranchModel(
        id: '',
        characterCode: char,
        element: element,
        branchType: branchType,
        branchCode: journeyBranchCode(char, element, branchType),
        name: branchType,
        attrKey: branchType);
  }
}
