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

  /// 免费喂食额度是否可用（false = 本次只能走背包口粮）
  bool get feedFreeAvailable =>
      !blocked(feedCooldown, feedRemain);

  /// 饱腹阈值（`pet_config.feed_full_hunger`，后台可配；0/缺配 = 不设门槛）
  int get feedFullHunger => cfg('feed_full_hunger');

  /// 是否已吃饱：唯一让喂食钮置灰的业务条件（2026-09-24 定版）
  ///
  /// 阈值未下发（旧版 rpc_pet_summary）时为 false，不阻塞喂食。
  bool get isFull {
    final p = pet;
    final threshold = feedFullHunger;
    return p != null && threshold > 0 && p.hunger >= threshold;
  }

  /// 免费喂食的真实增量（配置值，服务端 _pet_add_progress 同源）
  String get feedDeltaText {
    final parts = <String>[];
    final hunger = cfg('free_feed_hunger');
    final exp = cfg('free_feed_exp');
    if (hunger > 0) parts.add('饱食+$hunger');
    if (exp > 0) parts.add('经验+$exp');
    return parts.join(' · ');
  }

  /// 抚摸的真实增量（服务端加 interact_mood）
  String get interactDeltaText {
    final mood = cfg('interact_mood');
    return mood > 0 ? '心情+$mood' : '';
  }

  /// 冷却倒计时文案（「2分30秒」/「45秒」）
  ///
  /// 秒数**向上取整**：剩余 0.4 秒显示「1秒」而非「0秒」——刷新是 1 秒一跳，
  /// 截断会出现"停在 0 秒却还点不动"的一秒空窗（2026-09-24 修）。
  String coolText(Duration d) {
    final total = (d.inMilliseconds / 1000).ceil();
    final m = total ~/ 60;
    final s = total % 60;
    if (m <= 0) return '$s秒';
    return s == 0 ? '$m分' : '$m分$s秒';
  }
}
