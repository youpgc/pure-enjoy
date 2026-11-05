import '../../../services/game_score_service.dart';
import '../battle/journey_battle_controller.dart';
import 'journey_config_service.dart';

/// 西行·成绩上报器：结算写入既有 game_scores 链（成绩看板/排行榜/
/// 数据分析的数据源）。维度取值=远端 game_dimensions 配置
/// （farthest_level/run_kills/run_merit）；未登录/维度未配置/未就绪时
/// 静默跳过（本地进度不受影响），上报失败由服务层记日志并上报错误平台。
class JourneyScoreReporter {
  JourneyScoreReporter._();

  /// 上报一局成绩。[result] 为引擎结算结果；[cleared] 决定状态与
  /// farthest_level 维度取值（未通关传 0，max 聚合不受污染）。
  static void report({
    required JourneyRunResult result,
    required bool cleared,
    required String levelId,
    JourneyConfigSnapshot? snapshot,
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
        if (dims['farthest_level'] != null)
          dims['farthest_level']!: cleared ? result.levelNo : 0,
        if (dims['run_kills'] != null) dims['run_kills']!: result.kills,
        if (dims['run_merit'] != null) dims['run_merit']!: result.meritTotal,
      },
    );
  }
}
