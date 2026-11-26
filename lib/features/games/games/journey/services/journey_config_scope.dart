/// 西行配置表清单与页面分组：按页面声明所需表，服务只拉缺失的表。
///
/// 表名即 PostgREST 资源名；请求参数集中在此，避免服务层散落硬编码。
/// 依赖 gameId 的表（game_levels / game_dimensions / journey_weapon_levels）
/// 必须先取 games.code='journey' 的行，否则全表会混入其他游戏数据。
/// journey_levels 按 level_id 与 game_levels 关联，无独立 gameId 过滤。
library;

enum JourneyConfigTable {
  games('games', 'code.asc', 'id,code'),
  regions('journey_regions', 'seq.asc'),
  levels('game_levels', 'level_no.asc',
      'id,level_no,name,config,enabled,difficulty'),
  characters('journey_characters', 'unlock_level_no.asc'),
  weapons('journey_weapons', 'code.asc'),
  talentBranches('journey_talent_branches', 'character_code.asc,seq.asc'),
  globals('journey_globals', 'code.asc'),
  monsters('journey_monsters', 'code.asc'),
  weaponSlots('journey_weapon_slots', 'sort_order.asc'),
  weaponLevels('journey_weapon_levels', 'lv.asc'),
  scoreDimensions('game_dimensions', 'sort_order.asc', 'id,code'),
  drops('journey_drops', 'table_code.asc'),
  evoRecipes('journey_evo_recipes', 'seq.asc'),
  relicUnlocks('journey_relic_unlocks', 'seq.asc'),
  unlockEntries('journey_unlock_entries', 'code.asc'),
  pickups('journey_pickups', 'code.asc'),
  dailyMaps('journey_daily_maps', 'sort.asc'),
  endlessWaves('journey_endless_waves', 'wave_no.asc'),
  weaponParams('journey_weapon_params', 'weapon_id.asc'),
  monsterParams('journey_monster_params', 'monster_id.asc'),
  battleParams('journey_battle_params', 'group_code.asc'),
  upgradeCards('journey_upgrade_cards', 'sort_order.asc'),
  characterAuraParams('journey_character_aura_params', 'character_code.asc'),
  realmTitles('journey_realm_titles', 'character_code.asc,tier.asc'),
  journeyLevels('journey_levels', 'level_id.asc'),
  monsterAbilities('journey_monster_abilities', 'monster_id.asc,slot.asc'),
  monsterAbilityParams('journey_monster_ability_params', 'ability_id.asc'),
  levelBossFights('journey_level_boss_fights', 'level_id.asc,fight_no.asc');

  const JourneyConfigTable(this.tableName, this.order, [this.select]);

  final String tableName;
  final String order;
  final String? select;

  /// 没有西行 game_id 时这些表不能拉（会混入其他游戏关卡/维度）。
  bool get needsGameId =>
      this == JourneyConfigTable.levels ||
      this == JourneyConfigTable.weaponLevels ||
      this == JourneyConfigTable.scoreDimensions;

  Map<String, String>? filters(String gameId) => switch (this) {
        JourneyConfigTable.games => <String, String>{'code': 'eq.journey'},
        JourneyConfigTable.levels ||
        JourneyConfigTable.scoreDimensions =>
          <String, String>{'game_id': 'eq.$gameId'},
        JourneyConfigTable.dailyMaps => <String, String>{'enabled': 'eq.true'},
        _ => null,
      };
}

/// 页面范围：只声明该页渲染与交互真正读取的表。
/// 所有局外页面共用的基础组是 games + regions——gameId 用于成绩/成就/
/// 排行榜，regions 用于主题色、区域归属与远端就绪判定。
enum JourneyConfigScope {
  hub,
  levelSelect,
  daily,
  character,
  talent,
  compendium,
  achievements,
  battle,
}

extension JourneyConfigScopeTables on JourneyConfigScope {
  Set<JourneyConfigTable> get tables {
    const base = <JourneyConfigTable>{
      JourneyConfigTable.games,
      JourneyConfigTable.regions,
    };
    return switch (this) {
      JourneyConfigScope.hub => <JourneyConfigTable>{
          ...base,
          JourneyConfigTable.characters,
          JourneyConfigTable.weapons,
        },
      JourneyConfigScope.levelSelect => <JourneyConfigTable>{
          ...base,
          JourneyConfigTable.levels,
        },
      JourneyConfigScope.daily => <JourneyConfigTable>{
          ...base,
          JourneyConfigTable.dailyMaps,
        },
      JourneyConfigScope.character => <JourneyConfigTable>{
          ...base,
          JourneyConfigTable.characters,
          JourneyConfigTable.weapons,
        },
      JourneyConfigScope.talent => <JourneyConfigTable>{
          ...base,
          JourneyConfigTable.characters,
          JourneyConfigTable.talentBranches,
        },
      JourneyConfigScope.compendium => <JourneyConfigTable>{
          ...base,
          JourneyConfigTable.characters,
          JourneyConfigTable.weapons,
          JourneyConfigTable.weaponSlots,
          JourneyConfigTable.monsters,
          JourneyConfigTable.relicUnlocks,
          JourneyConfigTable.unlockEntries,
        },
      JourneyConfigScope.achievements => base,
      // 战斗引擎帧内会读强度曲线、维度槽、掉落、法宝/妖王参数等，
      // 进战斗页一次性补齐全部表，避免对局中再发请求。
      JourneyConfigScope.battle => JourneyConfigTable.values.toSet(),
    };
  }
}

/// 外键映射补全：分级/配方/解锁/法宝参数依赖法宝行把 id 映射为 code，
/// 妖王参数依赖怪物行；缺源表时这些行会被静默丢弃，故自动带上源表。
Set<JourneyConfigTable> expandConfigDependencies(
    Set<JourneyConfigTable> tables) {
  final result = <JourneyConfigTable>{...tables};
  const needsWeapons = <JourneyConfigTable>{
    JourneyConfigTable.weaponLevels,
    JourneyConfigTable.evoRecipes,
    JourneyConfigTable.relicUnlocks,
    JourneyConfigTable.weaponParams,
  };
  if (tables.any(needsWeapons.contains)) {
    result.add(JourneyConfigTable.weapons);
  }
  if (tables.contains(JourneyConfigTable.monsterParams) ||
      tables.contains(JourneyConfigTable.monsterAbilities)) {
    result.add(JourneyConfigTable.monsters);
  }
  // 能力专属参数依赖能力行把 ability_id 映射为「怪物code|能力键」，缺源表时丢弃。
  if (tables.contains(JourneyConfigTable.monsterAbilityParams)) {
    result
      ..add(JourneyConfigTable.monsterAbilities)
      ..add(JourneyConfigTable.monsters);
  }
  // 角色附带数据：aura 参数与境界名号按 character_code 关联，缺源表时
  // 角色会退回内置兜底，故凡需角色的页面自动带上这两张表。
  const needsCharacters = <JourneyConfigTable>{
    JourneyConfigTable.characterAuraParams,
    JourneyConfigTable.realmTitles,
  };
  if (tables.contains(JourneyConfigTable.characters) ||
      tables.any(needsCharacters.contains)) {
    result
      ..add(JourneyConfigTable.characters)
      ..add(JourneyConfigTable.characterAuraParams)
      ..add(JourneyConfigTable.realmTitles);
  }
  // 关卡的西行专属属性已拆到 journey_levels（level_id=game_levels.id），
  // 选关页需同时拿到两者；缺任一表则该关退回内置兜底。
  if (tables.contains(JourneyConfigTable.levels) ||
      tables.contains(JourneyConfigTable.journeyLevels) ||
      tables.contains(JourneyConfigTable.levelBossFights)) {
    result
      ..add(JourneyConfigTable.levels)
      ..add(JourneyConfigTable.journeyLevels);
  }
  return result;
}
