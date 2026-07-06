import '../../../services/api_client.dart';
import '../models/novel_model.dart';

/// 排行榜服务
/// 提供各类榜单数据的查询
class RankingService {
  static final RankingService _instance = RankingService._internal();
  factory RankingService() => _instance;
  RankingService._internal();

  /// 获取排行榜数据
  ///
  /// [type] 榜单类型
  /// [timeRange] 时间维度
  /// [limit] 返回数量
  /// [offset] 分页偏移
  Future<List<RankingItem>> getRankings({
    required RankingType type,
    required RankingTimeRange timeRange,
    int limit = 20,
    int offset = 0,
  }) async {
    // 构建排序字段
    String orderBy;
    switch (type) {
      case RankingType.read:
        orderBy = _getReadOrderColumn(timeRange);
        break;
      case RankingType.collect:
        orderBy = _getCollectOrderColumn(timeRange);
        break;
      case RankingType.rating:
        orderBy = 'avg_rating.desc';
        break;
      case RankingType.newBook:
        orderBy = _getReadOrderColumn(timeRange);
        break;
      case RankingType.completed:
        orderBy = 'avg_rating.desc';
        break;
    }

    // 构建过滤条件
    final filters = <String, String>{};

    // 评分榜至少需要10人评分
    if (type == RankingType.rating) {
      filters['rating_count'] = 'gte.10';
    }

    // 新书榜只显示最近30天上架的
    if (type == RankingType.newBook) {
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toUtc()
          .toIso8601String();
      filters['created_at'] = 'gte.$thirtyDaysAgo';
    }

    // 完结榜只显示已完结的
    if (type == RankingType.completed) {
      filters['status'] = 'eq.completed';
    }

    final result = await ApiClient.get(
      'mv_novel_rankings',
      filters: filters.isNotEmpty ? filters : null,
      order: orderBy,
      limit: limit,
      offset: offset,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!.map((json) => RankingItem.fromJson(json)).toList();
    }
    return [];
  }

  /// 根据时间维度获取阅读量排序字段
  String _getReadOrderColumn(RankingTimeRange timeRange) {
    switch (timeRange) {
      case RankingTimeRange.daily:
        return 'daily_reads.desc';
      case RankingTimeRange.weekly:
        return 'weekly_reads.desc';
      case RankingTimeRange.monthly:
        return 'monthly_reads.desc';
      case RankingTimeRange.allTime:
        return 'total_reads.desc';
    }
  }

  /// 根据时间维度获取收藏量排序字段
  String _getCollectOrderColumn(RankingTimeRange timeRange) {
    switch (timeRange) {
      case RankingTimeRange.daily:
        return 'daily_collects.desc';
      case RankingTimeRange.weekly:
        return 'weekly_collects.desc';
      case RankingTimeRange.monthly:
        return 'monthly_collects.desc';
      case RankingTimeRange.allTime:
        return 'total_collects.desc';
    }
  }

  /// 获取榜单类型显示名称
  static String getRankingTypeName(RankingType type) {
    switch (type) {
      case RankingType.read:
        return '阅读榜';
      case RankingType.collect:
        return '收藏榜';
      case RankingType.rating:
        return '评分榜';
      case RankingType.newBook:
        return '新书榜';
      case RankingType.completed:
        return '完结榜';
    }
  }

  /// 获取时间维度显示名称
  static String getTimeRangeName(RankingTimeRange range) {
    switch (range) {
      case RankingTimeRange.daily:
        return '日榜';
      case RankingTimeRange.weekly:
        return '周榜';
      case RankingTimeRange.monthly:
        return '月榜';
      case RankingTimeRange.allTime:
        return '总榜';
    }
  }
}
