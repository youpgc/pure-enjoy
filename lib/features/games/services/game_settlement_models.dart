/// 游戏结算模型（纯数据类，无 IO）。
///
/// 从 `game_reward_service.dart` 拆出（体量红线拆分，2026-09-04）；
/// 调用方仍可从 `game_reward_service.dart` 导入（该文件 export 本文件）。
library;

/// 奖励发放结果
class GameRewardResult {
  /// 是否实际发放
  final bool granted;

  /// 发放积分（未发放为 0）
  final int points;

  /// 未发放原因（发放成功为 null）
  final String? reason;

  const GameRewardResult._({
    required this.granted,
    this.points = 0,
    this.reason,
  });

  /// 发放成功。
  factory GameRewardResult.granted({required int points}) =>
      GameRewardResult._(granted: true, points: points);

  /// 未发放（含原因，便于 UI 提示）。
  factory GameRewardResult.notGranted({String? reason}) =>
      GameRewardResult._(granted: false, reason: reason);
}

/// 单条奖励明细（供结算页展示）
class GameSettlementItem {
  /// 奖励种类：daily_first_clear / score_range / achievement
  final String kind;

  /// 展示名
  final String label;

  /// 发放积分（未发放为 0）
  final int points;

  /// 是否实际发放
  final bool granted;

  /// 未发放原因（发放成功为 null）
  final String? reason;

  const GameSettlementItem({
    required this.kind,
    required this.label,
    required this.points,
    required this.granted,
    this.reason,
  });
}

/// 一次结算的全部奖励明细
class GameSettlementResult {
  /// 明细列表
  final List<GameSettlementItem> items;

  const GameSettlementResult({required this.items});

  /// 实际发放总积分
  int get totalPoints =>
      items.where((e) => e.granted).fold(0, (sum, e) => sum + e.points);

  /// 是否有任意一项发放成功
  bool get hasGranted => items.any((e) => e.granted);
}
