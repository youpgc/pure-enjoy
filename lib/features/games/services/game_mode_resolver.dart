import '../models/game_level_model.dart';
import 'game_service.dart';

/// 由关卡反解「模式编码」（mode code）。
///
/// 结算链路多处需要知道「本局是哪个模式」——段位徽章判定（mode_tier 的
/// `condition.mode`）、带模式限定的得分成就（score 的 `condition.mode`）。
/// 此前逻辑私有在 `GameBadgeService._resolveModeCode`，2026-09-15 抽出共享，
/// 避免两处各写一份、口径漂移。
///
/// 解析顺序：
///   ① 按 `level.modeId` 在配置快照的模式列表里查（权威）；
///   ② 2048 无尽合成关（无 server 关卡行，id 前缀 `endless_2048`）按 `isEndless` 兜底；
///   ③ 都查不到返回 null —— 调用方须按「模式未知」保守处理（跳过模式限定判定，不崩溃）。
String? resolveGameModeCode(
  GameConfigSnapshot config,
  String gameId,
  GameLevelModel level,
) {
  for (final m in config.modesOf(gameId)) {
    if (m.id == level.modeId) return m.code;
  }
  if (level.id.startsWith('endless_2048')) {
    for (final m in config.modesOf(gameId)) {
      if (m.isEndless) return m.code;
    }
  }
  return null;
}
