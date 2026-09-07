import '../models/game_mode_model.dart';
import '../models/game_model.dart';

/// GameFlow 流程节点。
///
/// 每个节点独立解析、独立降级：节点关闭（配置显式 false）或解析异常时，
/// 一律回落「游戏默认行为」（见参考文档 §16.1 降级矩阵），绝不阻塞游戏可玩。
enum GameFlowNode {
  /// 首页模式网格（game_modes 驱动）
  modeGrid('mode_grid', '模式网格'),

  /// 选关弹窗（game_levels 驱动）
  levelSelect('level_select', '选关'),

  /// 结算（成绩上报 + 奖励/成就发放）
  settlement('settlement', '结算奖励');

  const GameFlowNode(this.key, this.label);

  /// 配置键（games.config['flow'].nodes 下的键名）
  final String key;

  /// 中文名（日志/调试用）
  final String label;
}

/// 游戏级流程配置（来源：`games.config['flow']`，jsonb）。
///
/// 结构：`{ "enabled": true, "nodes": { "mode_grid": true, ... } }`；
/// 缺省视为全开（enabled=true、全部节点 true）——**配置缺位不降级**，
/// 只有显式关闭或解析异常才走默认流程。
class GameFlowConfig {
  /// 总开关：false 时整局走默认流程（经典模式、无选关、不发分）。
  final bool enabled;

  /// 节点开关表（key → 是否启用；未配置的节点视为 true）。
  final Map<String, bool> nodes;

  const GameFlowConfig({required this.enabled, required this.nodes});

  /// 全开默认配置。
  static const GameFlowConfig allEnabled =
      GameFlowConfig(enabled: true, nodes: <String, bool>{});

  /// 从游戏配置解析；任何结构异常都安全回落全开（配置坏 ≠ 功能禁用）。
  factory GameFlowConfig.of(GameModel game) {
    try {
      final raw = game.config['flow'];
      if (raw is! Map<String, dynamic>) return allEnabled;
      if (raw['enabled'] == false) {
        return GameFlowConfig(enabled: false, nodes: const <String, bool>{});
      }
      final nodesRaw = raw['nodes'];
      final nodes = <String, bool>{};
      if (nodesRaw is Map<String, dynamic>) {
        nodesRaw.forEach((key, value) => nodes[key] = value != false);
      }
      return GameFlowConfig(enabled: true, nodes: nodes);
    } catch (_) {
      return allEnabled;
    }
  }

  /// 指定节点是否启用（总开关 && 节点开关）。
  bool nodeEnabled(GameFlowNode node) =>
      enabled && (nodes[node.key] != false);
}

/// 模式级流程开关（`game_modes.config['flow_enabled']`，缺省 true）。
///
/// false 的模式不进入首页模式网格（不可玩），游戏按其余模式或默认流程执行。
bool modeFlowEnabled(GameModeModel mode) {
  try {
    return mode.config['flow_enabled'] != false;
  } catch (_) {
    return true;
  }
}
