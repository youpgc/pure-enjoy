part of 'point_service.dart';

/// 用户统计 / 积分记录 / 日历查询 / 本地缓存相关实现
mixin PointServiceStatsMixin {
  /// 分页获取积分记录
  ///
  /// [statusFilter] 状态过滤，null 表示不过滤（显示所有记录）
  Future<List<PointRecord>> getRecords({
    int page = 1,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return [];

      final offset = (page - 1) * pageSize;
      final filters = <String, String>{'user_id': 'eq.$userId'};
      if (statusFilter != null) {
        filters['status'] = 'eq.$statusFilter';
      }

      final result = await ApiClient.get(
        'point_records',
        filters: filters,
        order: 'created_at.desc',
        limit: pageSize,
        offset: offset,
      );

      if (result.isSuccess) {
        final records = result.data!;
        return records.map((json) => PointRecord.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取积分记录失败');
      }
      return [];
    }
  }

  /// 获取用户可用积分（有效且未过期的积分）
  Future<int> getAvailablePoints() async {
    final stats = await _fetchUserStats();
    return (stats?['available_points'] as num?)?.toInt() ?? 0;
  }

  /// 获取连续签到天数
  Future<int> getConsecutiveCheckinDays() async {
    final stats = await _fetchUserStats();
    return (stats?['consecutive_checkin_days'] as num?)?.toInt() ?? 0;
  }

  /// 查询30天内即将过期的积分总数
  Future<int> getExpiringSoonPoints() async {
    final stats = await _fetchUserStats();
    return (stats?['expiring_points'] as num?)?.toInt() ?? 0;
  }

  /// 获取指定月份（北京时区）已签到的日期键集合（yyyy-MM-dd）。
  ///
  /// 仅供签到日历展示使用，纯只读查询 point_records，不修改任何数据、不改奖励逻辑。
  /// [month] 任意代表目标月份的 DateTime（仅取年月）。
  Future<Set<String>> getCheckinDatesInMonth(DateTime month) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return {};

    final nextMonth = month.month == 12 ? 1 : month.month + 1;
    final nextYear = month.month == 12 ? month.year + 1 : month.year;

    // 以北京自然月为窗口：北京时间 [month-01 00:00, nextMonth-01 00:00)
    // 中国不实行夏令时，固定 UTC+8，故直接对 UTC 零点边界减 8 小时即得对应 UTC 过滤边界。
    final startUtc =
        DateTime.utc(month.year, month.month, 1).subtract(const Duration(hours: 8));
    final endUtc =
        DateTime.utc(nextYear, nextMonth, 1).subtract(const Duration(hours: 8));

    final result = await ApiClient.get(
      'point_records',
      filters: {
        'user_id': 'eq.$userId',
        'type': 'eq.checkin',
        'and':
            '(created_at.gte.${startUtc.toIso8601String()},created_at.lt.${endUtc.toIso8601String()})',
      },
      columns: 'created_at',
      limit: null,
    );

    final dates = <String>{};
    if (result.isSuccess && result.data != null) {
      for (final record in result.data!) {
        final created = record['created_at'] as String?;
        if (created != null) {
          dates.add(beijingDateKey(DateTime.parse(created)));
        }
      }
    }
    return dates;
  }

  /// 查询最早一条签到记录所在月份的首日（仅取年月），无数据返回 null。
  ///
  /// 用于约束日历向前翻月范围：早于该月的月份均无签到数据，不再允许切换。
  /// 只读 point_records，不修改任何数据。
  Future<DateTime?> getEarliestCheckinMonth() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;
    try {
      final result = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.checkin',
        },
        columns: 'created_at',
        order: 'created_at.asc',
        limit: 1,
      );
      if (result.isSuccess &&
          result.data != null &&
          result.data!.isNotEmpty) {
        final created = result.data![0]['created_at'] as String?;
        if (created != null) {
          final dt = DateTime.parse(created);
          return DateTime(dt.year, dt.month, 1);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('查询最早签到月份失败: $e');
      return null;
    }
  }

  /// 缓存积分统计到本地，供积分页进入时立即展示（避免闪现 0）
  ///
  /// [lastCheckinDate] 最近一次签到的北京日期键（yyyy-MM-dd），为 null 表示未签到。
  /// 由 App 端在签到成功或拉取后端数据后维护，仅用于首屏秒渲染，不替代后端权威数据。
  /// 隔天后缓存日期键与今日不匹配，hasCheckedInToday 自动归 false，无需手动清理。
  Future<void> cachePointsStats({
    required int availablePoints,
    required int consecutiveCheckinDays,
    String? lastCheckinDate,
  }) async {
    await savePointStatsCache(
      availablePoints: availablePoints,
      consecutiveCheckinDays: consecutiveCheckinDays,
      lastCheckinDate: lastCheckinDate,
    );
  }

  /// 读取本地缓存的积分统计
  ///
  /// 若未缓存则返回全 0 / null。已签到状态由 lastCheckinDate 与今日北京日期键实时比较得出，
  /// 保证隔天后缓存自动失效、首屏渲染正确。字段含义同 cachePointsStats。
  Future<Map<String, dynamic>> getCachedPointsStats() async {
    return loadPointStatsCache();
  }
}
