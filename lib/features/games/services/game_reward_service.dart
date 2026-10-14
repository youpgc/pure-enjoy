import '../../../core/utils/event_bus.dart';
import '../models/game_level_model.dart';
import '../models/game_model.dart';
import 'game_score_service.dart';
import 'game_service.dart';

// 结算模型类（GameRewardResult / GameSettlementItem / GameSettlementResult）
// 已拆至 game_settlement_models.dart；import 供 part 文件使用，export 保持调用方
// 原有 import 路径（from game_reward_service.dart）不变。
import 'game_settlement_models.dart';
export 'game_settlement_models.dart';

// 【文件拆分 2026-09-22】单文件超 500 行红线，按 part + extension 分片：
// game_reward_settlement.dart（统一结算编排 settleGame；change-server 起为
// 服务端权威 settle 的薄映射层）。
part 'game_reward_settlement.dart';

/// 非 uuid 的合成关 id（endless_2048_N、GameFlow 默认关）清洗基准。
final RegExp _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// 游戏积分奖励服务（change-server：发放编排已移植服务端 `GameSettlementService`，
/// 本类收敛为结算入口 [settleGame]（见 part 文件））。
///
/// 旧客户端 claim 链（grant_game_reward RPC / 上限预检缓存 / 段位徽章解锁）已随
/// 服务端权威结算移除；幂等由 score_id（settleToken）与 claim_key 唯一索引在
/// 服务端保证。
class GameRewardService {
  GameRewardService._();

  /// 单例
  static final GameRewardService instance = GameRewardService._();

  /// 账号切换时清理结算相关内存态（缓存已随服务端权威结算移除，
  /// 保留入口以兼容 auth_provider 的统一清理调用）。
  void resetForAccountSwitch() {}
}
