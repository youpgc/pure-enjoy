import '../../../services/game_score_service.dart';
import '../battle/journey_attributes_data.dart';
import '../battle/journey_battle_controller.dart';
import '../battle/journey_flame_game.dart';
import 'journey_config_service.dart';

/// 西行·成绩上报器：结算写入既有 game_scores 链（成绩看板/排行榜/
/// 数据分析的数据源）。维度取值=远端 game_dimensions 配置
/// （farthest_level/run_kills/run_merit）；未登录/维度未配置/未就绪时
/// 静默跳过（本地进度不受影响），上报失败由服务层记日志并上报错误平台。
class JourneyScoreReporter {
  JourneyScoreReporter._();

  /// 上报一局成绩。[result] 为引擎结算结果；[cleared] 决定状态与
  /// farthest_level 维度取值（未通关传 0，max 聚合不受污染）。
  /// [runDetail] 为对局详情快照（角色/属性等，落 game_scores.run_detail，
  /// 供游戏记录/排障/后续排行榜与成就使用；终局无论胜败均随上报落库）。
  /// 全部模式（主线/无尽/游历）均上报对局与属性快照；farthest_level
  /// 维度只有主线写值，虚拟关 level_no=0 不参与最远关卡聚合。
  static void report({
    required JourneyRunResult result,
    required bool cleared,
    required String levelId,
    JourneyConfigSnapshot? snapshot,
    Map<String, Object?>? runDetail,
  }) {
    final dims = snapshot?.scoreDimIds ?? const <String, String>{};
    final gameId = snapshot?.gameId ?? '';
    if (gameId.isEmpty || dims.isEmpty) return;
    GameScoreService.instance.submitScore(
      gameId: gameId,
      levelId: levelId,
      cleared: cleared,
      durationMs: result.durationSec * 1000,
      values: <String, num>{
        if (dims['farthest_level'] != null && result.levelNo > 0)
          dims['farthest_level']!: cleared ? result.levelNo : 0,
        if (dims['run_kills'] != null) dims['run_kills']!: result.kills,
        if (dims['run_merit'] != null) dims['run_merit']!: result.meritTotal,
      },
      runDetail: runDetail,
    );
  }

  /// 组装对局详情快照（game_scores.run_detail + journey_runs.run_detail）：
  /// 扁平字段供后台成绩看板摘要，attr_groups 为属性面板全量分组行
  /// （与局内面板共用 [JourneyAttributesData] 口径），供历史详情页展示；
  /// [modeCode] 为所属模式码（main/endless/daily），供成绩看板在无 level_id
  /// 时回退展示模式名；[game] 为 null（配置异常兜底局）时返回 null。
  static Map<String, Object?>? buildRunDetail(
    JourneyFlameGame? game, {
    required String characterCode,
    required String modeCode,
  }) {
    if (game == null) return null;
    final hud = game.controller.hud;
    return <String, Object?>{
      'character_code': characterCode,
      'mode': modeCode,
      'char_level': hud.level.value,
      'hp': hud.hp.value.round(),
      'max_hp': hud.maxHp.value.round(),
      'hit_damage': game.hitDamageBase.toStringAsFixed(1),
      'move_speed_amp': game.moveSpeedAmp,
      'crit_rate': game.critRate,
      'crit_damage': game.critDamage,
      'regen': game.player.regen,
      'armor': game.player.armor,
      'exp_amp': game.expAmp,
      'weapon_slots': <String, int>{
        for (final s in game.weaponSlots) s.code: s.level,
      },
      'passives': game.passiveSlotCodes,
      'evolved': game.evolved,
      'attr_groups': <Map<String, dynamic>>[
        for (final g in JourneyAttributesData.collect(game)) g.toJson(),
      ],
    };
  }
}
