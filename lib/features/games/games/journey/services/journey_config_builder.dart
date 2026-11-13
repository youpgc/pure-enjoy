import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import 'journey_config_scope.dart';
import 'journey_config_snapshot.dart';
import 'journey_seed.dart';

/// 已成功加载的配置行：key 存在即代表该表就绪，空列表代表后台未配置。
/// 未加载或拉取失败的表不写入，由组装侧按域回落内置种子。
typedef JourneyConfigRows = Map<String, List<Map<String, dynamic>>>;

class _RowsView {
  const _RowsView(this._rows);

  final JourneyConfigRows _rows;

  bool loaded(JourneyConfigTable table) => _rows.containsKey(table.tableName);

  List<Map<String, dynamic>> of(JourneyConfigTable table) =>
      _rows[table.tableName] ?? const <Map<String, dynamic>>[];

  /// 已加载则按远端行解析，否则用内置种子模型；空表如实返回空列表。
  /// parse 返回 null 表示该行外键映射断裂，直接丢弃。
  List<T> models<T>(
    JourneyConfigTable table,
    List<T> Function() seed,
    T? Function(Map<String, dynamic> row) parse,
  ) =>
      loaded(table) ? of(table).map(parse).whereType<T>().toList() : seed();
}

Map<String, String> _idCodeMap(List<Map<String, dynamic>> rows) =>
    <String, String>{
      for (final row in rows)
        if (row['id'] is String && row['code'] is String)
          row['id'] as String: row['code'] as String,
    };

/// 关卡行：name=难名；西行专属属性在 config jsonb。
JourneyLevelModel _levelFromRow(Map<String, dynamic> row) {
  final config =
      (row['config'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  return JourneyLevelModel.fromJson(<String, dynamic>{
    'id': row['id'],
    'level_no': row['level_no'],
    'title': row['name'],
    'region_code': config['region_code'],
    'level_kind': config['level_kind'],
    'boss_fights': config['boss_fights'],
    'first_clear_merit': config['first_clear_merit'],
    'duration_target_sec': config['duration_target_sec'],
    'difficulty': row['difficulty'],
  });
}

/// 角色：客户端过滤禁用行（enabled 列后台开关；列未部署时解析缺省
/// true 不丢行）。空表回落种子，避免「无可用角色」死局。
List<JourneyCharacterModel> _charactersOf(_RowsView view) {
  const table = JourneyConfigTable.characters;
  if (!view.loaded(table)) {
    return kJourneyCharacterSeed.map(JourneyCharacterModel.fromJson).toList();
  }
  final rows = view
      .of(table)
      .map(JourneyCharacterModel.fromJson)
      .where((c) => c.enabled)
      .toList();
  return rows.isEmpty
      ? kJourneyCharacterSeed.map(JourneyCharacterModel.fromJson).toList()
      : rows;
}

typedef _WeaponRelations = ({
  Map<String, List<JourneyWeaponLevelModel>> weaponLevels,
  List<JourneyEvoRecipeModel> evoRecipes,
  List<JourneyRelicUnlockModel> relicUnlocks,
  Map<String, Map<String, double>> weaponParams,
});

/// 法宝外键表：id → code 由法宝行映射；断裂行丢弃，避免把外键 id 当编码。
/// 表未加载时炼化/解锁走内置种子，其余按域为空由引擎兜底。
_WeaponRelations _weaponRelations(
  _RowsView view,
  Map<String, String> idToCode,
) {
  final weaponLevels = <String, List<JourneyWeaponLevelModel>>{};
  for (final row in view.of(JourneyConfigTable.weaponLevels)) {
    final code = idToCode[row['weapon_id'] as String?];
    if (code == null) continue;
    (weaponLevels[code] ??= <JourneyWeaponLevelModel>[])
        .add(JourneyWeaponLevelModel.fromJson(row));
  }

  final evoRecipes = view.models<JourneyEvoRecipeModel>(
    JourneyConfigTable.evoRecipes,
    () => kJourneyEvoRecipeSeed.map(JourneyEvoRecipeModel.fromJson).toList(),
    (row) {
      final code = idToCode[row['weapon_id'] as String?];
      final passive = idToCode[row['required_passive_id'] as String?];
      if (code == null || passive == null) return null;
      return JourneyEvoRecipeModel.fromJson(<String, dynamic>{
        'seq': row['seq'],
        'weapon_code': code,
        'required_passive_code': passive,
        'required_passive_lv': row['required_passive_lv'],
        'result_code': row['result_code'],
        'result_name': row['result_name'],
        'evo_mult': row['evo_mult'],
      });
    },
  );

  final relicUnlocks = view.models<JourneyRelicUnlockModel>(
    JourneyConfigTable.relicUnlocks,
    () =>
        kJourneyRelicUnlockSeed.map(JourneyRelicUnlockModel.fromJson).toList(),
    (row) {
      final code = idToCode[row['weapon_id'] as String?];
      if (code == null) return null;
      return JourneyRelicUnlockModel.fromJson(<String, dynamic>{
        'seq': row['seq'],
        'weapon_code': code,
        'achievement_code': row['achievement_code'],
        'merit_cost': row['merit_cost'],
      });
    },
  );

  final weaponParams = <String, Map<String, double>>{};
  for (final row in view.of(JourneyConfigTable.weaponParams)) {
    final code = idToCode[row['weapon_id'] as String?];
    final paramCode = row['code'] as String?;
    final value = (row['value_num'] as num?)?.toDouble();
    if (code == null || paramCode == null || value == null) continue;
    (weaponParams[code] ??= <String, double>{})[paramCode] = value;
  }

  return (
    weaponLevels: weaponLevels,
    evoRecipes: evoRecipes,
    relicUnlocks: relicUnlocks,
    weaponParams: weaponParams,
  );
}

/// 妖王能力参数：monster_id → code 由怪物行映射，断裂行丢弃。
Map<String, Map<String, double>> _monsterParams(
  _RowsView view,
  Map<String, String> idToCode,
) {
  final result = <String, Map<String, double>>{};
  for (final row in view.of(JourneyConfigTable.monsterParams)) {
    final code = idToCode[row['monster_id'] as String?];
    final paramCode = row['code'] as String?;
    final value = (row['value_num'] as num?)?.toDouble();
    if (code == null || paramCode == null || value == null) continue;
    (result[code] ??= <String, double>{})[paramCode] = value;
  }
  return result;
}

/// 把已加载的配置行组装成快照：未加载的表按域回落内置种子，已加载的
/// 表无论先后都参与外键映射，避免分组加载时「分级/配方/参数」被丢弃。
({JourneyConfigSnapshot snapshot, bool fromSeed}) buildJourneyConfigSnapshot(
  JourneyConfigRows rows,
  String gameId,
) {
  final view = _RowsView(rows);

  // 核心就绪只认 games 行与区域表；其余表单表缺失、失败或为空都逐域
  // 兜底，不把已加载的远端角色/法宝配置整体退回种子。
  if (gameId.isEmpty ||
      !view.loaded(JourneyConfigTable.regions) ||
      view.of(JourneyConfigTable.regions).isEmpty) {
    return (snapshot: buildJourneySeedSnapshot(), fromSeed: true);
  }

  final regions = view
      .of(JourneyConfigTable.regions)
      .map(JourneyRegionModel.fromJson)
      .toList();
  final levels = view.loaded(JourneyConfigTable.levels)
      ? view
          .of(JourneyConfigTable.levels)
          .where((row) => row['enabled'] != false)
          .map(_levelFromRow)
          .toList()
      : kJourneyLevelSeed.map(JourneyLevelModel.fromJson).toList();
  // 关卡表已部署但一行未开：沿用内置八十一难，保证选关页不空白。
  final resolvedLevels = levels.isEmpty
      ? kJourneyLevelSeed.map(JourneyLevelModel.fromJson).toList()
      : levels;

  final weaponRows = view.loaded(JourneyConfigTable.weapons)
      ? view.of(JourneyConfigTable.weapons)
      : kJourneyWeaponSeed;
  final weaponIdToCode = _idCodeMap(weaponRows);
  final monsterRows = view.of(JourneyConfigTable.monsters);
  final monsterIdToCode = _idCodeMap(monsterRows);
  final relations = _weaponRelations(view, weaponIdToCode);

  final branchSeed = buildJourneyTalentBranchSeed()
      .map(JourneyTalentBranchModel.fromJson)
      .toList();
  final branches = view.models(
    JourneyConfigTable.talentBranches,
    () => branchSeed,
    JourneyTalentBranchModel.fromJson,
  );

  final globalsRows = view.of(JourneyConfigTable.globals);
  final globalsRaw =
      view.loaded(JourneyConfigTable.globals) && globalsRows.isNotEmpty
          ? globalsRows.first
          : null;

  return (
    snapshot: JourneyConfigSnapshot(
      regions: regions,
      levels: resolvedLevels,
      characters: _charactersOf(view),
      weapons: weaponRows.map(JourneyWeaponModel.fromJson).toList(),
      talentBranches: branches.isEmpty ? branchSeed : branches,
      monsters: monsterRows.map(JourneyMonsterModel.fromJson).toList(),
      slotDefs: view.models(
        JourneyConfigTable.weaponSlots,
        () => kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson).toList(),
        JourneySlotDefModel.fromJson,
      ),
      weaponLevels: relations.weaponLevels,
      drops: view.models(
        JourneyConfigTable.drops,
        () => kJourneyDropSeed.map(JourneyDropModel.fromJson).toList(),
        JourneyDropModel.fromJson,
      ),
      evoRecipes: relations.evoRecipes,
      relicUnlocks: relations.relicUnlocks,
      pickupConfigs: view.models(
        JourneyConfigTable.pickups,
        () => kJourneyPickupConfigSeed
            .map(JourneyPickupConfigModel.fromJson)
            .toList(),
        JourneyPickupConfigModel.fromJson,
      ),
      dailyMaps: view.models(
        JourneyConfigTable.dailyMaps,
        () => kJourneyDailyMapSeed.map(JourneyDailyMapModel.fromJson).toList(),
        JourneyDailyMapModel.fromJson,
      ),
      endlessWaves: view
          .of(JourneyConfigTable.endlessWaves)
          .map(JourneyEndlessWaveModel.fromJson)
          .toList(),
      weaponParams: relations.weaponParams,
      monsterParams: _monsterParams(view, monsterIdToCode),
      globalsRaw: globalsRaw,
      gameId: gameId,
      scoreDimIds: <String, String>{
        for (final row in view.of(JourneyConfigTable.scoreDimensions))
          if (row['id'] is String && row['code'] is String)
            row['code'] as String: row['id'] as String,
      },
      fromSeed: false,
    ),
    fromSeed: false,
  );
}

/// 远端未就绪时的内置兜底（SQL 种子的镜像），保离线可玩。
JourneyConfigSnapshot buildJourneySeedSnapshot() {
  return JourneyConfigSnapshot(
    regions: kJourneyRegionSeed.map(JourneyRegionModel.fromJson).toList(),
    levels: kJourneyLevelSeed.map(JourneyLevelModel.fromJson).toList(),
    characters:
        kJourneyCharacterSeed.map(JourneyCharacterModel.fromJson).toList(),
    weapons: kJourneyWeaponSeed.map(JourneyWeaponModel.fromJson).toList(),
    talentBranches: buildJourneyTalentBranchSeed()
        .map(JourneyTalentBranchModel.fromJson)
        .toList(),
    drops: kJourneyDropSeed.map(JourneyDropModel.fromJson).toList(),
    evoRecipes:
        kJourneyEvoRecipeSeed.map(JourneyEvoRecipeModel.fromJson).toList(),
    relicUnlocks:
        kJourneyRelicUnlockSeed.map(JourneyRelicUnlockModel.fromJson).toList(),
    pickupConfigs: kJourneyPickupConfigSeed
        .map(JourneyPickupConfigModel.fromJson)
        .toList(),
    slotDefs: kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson).toList(),
    dailyMaps: kJourneyDailyMapSeed.map(JourneyDailyMapModel.fromJson).toList(),
    fromSeed: true,
  );
}
