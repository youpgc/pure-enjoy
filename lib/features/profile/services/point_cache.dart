import '../../../utils/cache_helper.dart';
import './point_service_utils.dart';

/// 积分统计本地缓存（从 PointService 抽出，纯逻辑）
/// 与原类内实现逐字节一致。

/// 缓存积分统计到本地，供积分页进入时立即展示（避免闪现 0）
///
/// [lastCheckinDate] 最近一次签到的北京日期键（yyyy-MM-dd），为 null 表示未签到。
/// 由 App 端在签到成功或拉取后端数据后维护，仅用于首屏秒渲染，不替代后端权威数据。
/// 隔天后缓存日期键与今日不匹配，hasCheckedInToday 自动归 false，无需手动清理。
Future<void> savePointStatsCache({
  required int availablePoints,
  required int consecutiveCheckinDays,
  String? lastCheckinDate,
}) async {
  await CacheHelper.instance.saveMap(CacheHelper.keyPointStats, {
    'availablePoints': availablePoints,
    'consecutiveCheckinDays': consecutiveCheckinDays,
    'lastCheckinDate': lastCheckinDate,
  });
}

/// 读取本地缓存的积分统计
///
/// 若未缓存则返回全 0 / null。已签到状态由 lastCheckinDate 与今日北京日期键实时比较得出，
/// 保证隔天后缓存自动失效、首屏渲染正确。字段含义同 savePointStatsCache。
Future<Map<String, dynamic>> loadPointStatsCache() async {
  final m = await CacheHelper.instance.loadMap(CacheHelper.keyPointStats);
  if (m == null) {
    return {
      'availablePoints': 0,
      'consecutiveCheckinDays': 0,
      'lastCheckinDate': null,
    };
  }
  final String? date = m['lastCheckinDate'] as String?;
  final todayKey = beijingDateKey(DateTime.now());
  return {
    'availablePoints': (m['availablePoints'] as num?)?.toInt() ?? 0,
    'consecutiveCheckinDays':
        (m['consecutiveCheckinDays'] as num?)?.toInt() ?? 0,
    'lastCheckinDate': date,
    'hasCheckedInToday': date == todayKey,
  };
}
