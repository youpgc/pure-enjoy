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

  /// 本地动作锚点:喂食/抚摸成功响应那一刻的客户端时间(按宠+动作记一份)。
  ///
  /// 冷却结束时刻 = 服务端 last_xxx_at + 冷却,而 last_xxx_at 的写入时刻
  /// **晚于**客户端发起请求(网络往返),再叠加客户机与服务端的时钟偏移——
  /// 直接拿服务端锚减客户端 now,会把这些全算进冷却:10 分钟喂食显示 11 分、
  /// 1 分钟抚摸显示 63 秒(20261021 用户报告)。锚点用客户端自己的时间轴,
  /// 保证展示自洽;注意锚点只管展示,倒计时走完后服务端仍可能拒
  /// (PET_FEED_COOLDOWN 提示兜底)。锚点仅在 App 存活期有效,
  /// 重进后回落服务端 last_xxx_at(偏差亚秒级)。
  static final Map<String, DateTime> _actionAnchor = <String, DateTime>{};

  /// 喂养/抚摸成功后由 [PetRpc] 回调记录锚点
  static void noteActionAnchor(String petId, String kind) {
    _actionAnchor['$petId:$kind'] = DateTime.now();
  }

  /// 冷却计算(秒级;20261021 配置单位下沉,_sec 新键优先,_min×60 兜底旧缓存)
  Duration? _cooldownLeftSec(DateTime? lastAt, int? cooldownSec) {
    if (lastAt == null || cooldownSec == null || cooldownSec <= 0) return null;
    final end = lastAt.add(Duration(seconds: cooldownSec));
    return end.isAfter(DateTime.now()) ? end.difference(DateTime.now()) : null;
  }

  /// 锚点优先的冷却计算(锚点在冷却期内用锚点;**锚点过期穿透服务端锚**——
  /// 批量喂养等路径不写本地锚,过期即 return null 会永久遮蔽服务端新冷却,
  /// 喂食钮误示可点(20261021 复审 P1);秒级配置缺键时由调用方传入
  /// null → 无冷却,与「不为缺失字段编默认值」一致)
  Duration? _cooldownAnchored(String petId, String kind, DateTime? lastAt, int? cooldownSec) {
    if (cooldownSec == null || cooldownSec <= 0) return null;
    final anchor = _actionAnchor['$petId:$kind'];
    if (anchor != null) {
      final left = anchor
          .add(Duration(seconds: cooldownSec))
          .difference(DateTime.now());
      if (left > Duration.zero) return left;
    }
    return _cooldownLeftSec(lastAt, cooldownSec);
  }

  /// 喂食剩余冷却（null = 无冷却）
  Duration? get feedCooldown => _cooldownAnchored(pet?.id ?? '', 'feed',
      pet?.lastFeedAt, _cooldownSec('free_feed_cooldown_sec', 'free_feed_cooldown_min'));

  /// 抚摸剩余冷却（null = 无冷却）
  Duration? get interactCooldown => _cooldownAnchored(pet?.id ?? '', 'interact',
      pet?.lastInteractAt, _cooldownSec('interact_cooldown_sec', 'interact_cooldown_min'));

  /// 秒级冷却配置(20261021)。⚠️ [cfg] 对缺失键返回 0 而非 null——
  /// 故 0 视为「键未下发」回落旧键×60(SWR 旧缓存/服务端未升级时);
  /// 运营若要禁用冷却请配 1 秒(不支持显式 0)。
  int? _cooldownSec(String secKey, String minKey) {
    final sec = cfg(secKey);
    if (sec > 0) return sec;
    final min = cfg(minKey);
    if (min > 0) return min * 60;
    return null;
  }

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
