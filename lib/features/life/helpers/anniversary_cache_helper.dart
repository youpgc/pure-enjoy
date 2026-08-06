/// 纪念日日期工具（从原 anniversary_cache_helper 收敛而来）。
///
/// 原列表缓存读写已统一到全局 [CacheHelper]（lib/utils/cache_helper.dart，
/// 见 [CacheHelper.loadList] / [CacheHelper.saveList]），避免与全局缓存层分叉；
/// 本文件仅保留与缓存无关的日期规整逻辑。
///
/// 注意：切换账号时 [CacheHelper.clearAllUserData] 已按 `cached_anniversaries_*` 前缀
/// 清扫本模块缓存键，无需在此单独处理。
library;

/// 保存时日期强制当天 12:00（农历项经转换后存公历）。
DateTime normalizeAnniversaryDate(DateTime date) =>
    DateTime(date.year, date.month, date.day, 12);
