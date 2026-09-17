import '../models/pet_models.dart';

/// 宠物操作预算：喂食/抚摸的冷却与每日次数派生逻辑
///
/// 数据源为 rpc_pet_summary 2026-09-17 扩展字段：
/// - config：`free_feed_cooldown_min` / `free_feed_daily` /
///   `interact_cooldown_min` / `interact_daily` 等；
/// - pet：`todayFreeFeedCount` / `lastFeedAt` /
///   `todayInteractCount` / `lastInteractAt`。
///
/// 约定：配置缺省或为 0 视为「未配置」→ 不限次、无冷却、不展示角标。
class PetActionBudget {
  const PetActionBudget({required this.config, this.pet});

  /// 宠物功能配置（pet_config 快照）
  final Map<String, dynamic> config;

  /// 当前宠物（无宠物时冷却/次数均为 null）
  final PetBriefModel? pet;

  /// 读取整型配置，缺省返回 0（未配置）
  int cfg(String key) => (config[key] as num?)?.toInt() ?? 0;

  Duration? _cooldownLeft(DateTime? lastAt, int cooldownMin) {
    if (lastAt == null || cooldownMin <= 0) return null;
    final end = lastAt.add(Duration(minutes: cooldownMin));
    return end.isAfter(DateTime.now()) ? end.difference(DateTime.now()) : null;
  }

  /// 喂食剩余冷却（null = 无冷却）
  Duration? get feedCooldown =>
      _cooldownLeft(pet?.lastFeedAt, cfg('free_feed_cooldown_min'));

  /// 抚摸剩余冷却（null = 无冷却）
  Duration? get interactCooldown =>
      _cooldownLeft(pet?.lastInteractAt, cfg('interact_cooldown_min'));

  /// 是否任一操作处于冷却中（用于逐秒刷新 Timer 的省电判断）
  bool get anyCooling => feedCooldown != null || interactCooldown != null;

  /// 喂食今日剩余次数（null = 未配置不限次）
  int? get feedRemain {
    final daily = cfg('free_feed_daily');
    if (daily <= 0) return null;
    return (daily - (pet?.todayFreeFeedCount ?? 0)).clamp(0, daily);
  }

  /// 抚摸今日剩余次数（null = 未配置不限次）
  int? get interactRemain {
    final daily = cfg('interact_daily');
    if (daily <= 0) return null;
    return (daily - (pet?.todayInteractCount ?? 0)).clamp(0, daily);
  }

  /// 操作是否被禁用：冷却中 或 次数耗尽
  bool blocked(Duration? cool, int? remain) =>
      cool != null || (remain != null && remain <= 0);

  /// 冷却倒计时文案（「2分30秒」/「45秒」）
  String coolText(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '$m分$s秒' : '$s秒';
  }
}
