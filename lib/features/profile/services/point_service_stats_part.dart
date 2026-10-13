part of 'point_service.dart';

/// 用户统计 / 积分记录 / 日历查询 / 本地缓存相关实现
mixin PointServiceStatsMixin {
  /// 分页获取积分记录（change-server：走后端 /users/points/records）
  ///
  /// [statusFilter] 状态过滤，null 表示不过滤（后端默认 active）
  Future<List<PointRecord>> getRecords({
    int page = 1,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    try {
      final result = await BackendApi.get(
        '/users/points/records',
        query: {
          'page': '$page',
          'page_size': '$pageSize',
          // null=不过滤：显式传 all（后端缺省 active，会把已过期记录隐藏，
          // 而流水页需要全量以展示「已过期/即将过期」标签）
          'status': statusFilter ?? 'all',
        },
      );

      if (!result.success) return [];
      return result.list
          .map((json) => PointRecord.fromJson(json as Map<String, dynamic>))
          .toList();
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
  /// 仅供签到日历展示使用，纯只读查询，不修改任何数据、不改奖励逻辑。
  /// [month] 任意代表目标月份的 DateTime（仅取年月）。
  /// change-server：走后端 records 端点 type=checkin + created_date 范围（北京日，闭区间）。
  Future<Set<String>> getCheckinDatesInMonth(DateTime month) async {
    try {
      final first = DateTime(month.year, month.month, 1);
      final last = DateTime(month.year, month.month + 1, 0);
      final result = await BackendApi.get(
        '/users/points/records',
        query: {
          'type': 'checkin',
          'from': beijingDateKey(first),
          'to': beijingDateKey(last),
          'page_size': '100',
          // checkin 流水 180 天后过期翻转为 expired，日历回溯需跨状态全量
          'status': 'all',
        },
      );

      final dates = <String>{};
      if (result.success) {
        for (final row in result.list) {
          final date = (row as Map<String, dynamic>)['created_date'] as String?;
          if (date != null) dates.add(date);
        }
      }
      return dates;
    } catch (e) {
      if (kDebugMode) debugPrint('查询当月签到日期失败: $e');
      return {};
    }
  }

  /// 查询最早一条签到记录所在月份的首日（仅取年月），无数据返回 null。
  ///
  /// 用于约束日历向前翻月范围：早于该月的月份均无签到数据，不再允许切换。
  /// change-server：走后端 records 端点 type=checkin + order=asc，取首条 created_date。
  Future<DateTime?> getEarliestCheckinMonth() async {
    try {
      final result = await BackendApi.get(
        '/users/points/records',
        query: {
          'type': 'checkin',
          'order': 'asc',
          'page_size': '1',
          // 同上：早期签到流水可能已翻转为 expired，须跨状态查询
          'status': 'all',
        },
      );
      if (result.success && result.list.isNotEmpty) {
        final date =
            (result.list.first as Map<String, dynamic>)['created_date']
                as String?;
        if (date != null && date.isNotEmpty) {
          final dt = DateTime.parse(date);
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
