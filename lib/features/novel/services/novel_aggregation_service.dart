import '../../../services/api_client.dart';

/// 聚合小说去重服务（合规：避免重复导入同一来源书籍）。
///
/// 在 Phase 2 导入元数据时使用：先按来源链接精确去重，再按书名+作者兜底，
/// 返回已存在的小说 id，避免同一本书在 [novels] 表产生多条记录。
class NovelAggregationService {
  NovelAggregationService._();

  static final NovelAggregationService instance = NovelAggregationService._();

  factory NovelAggregationService() => instance;

  /// 按来源链接精确去重，返回已存在的同源小说 id；无则返回 null。
  Future<String?> findExistingBySource(String source, String sourceUrl) async {
    try {
      final res = await ApiClient.get(
        'novels',
        filters: {
          'source': 'eq.$source',
          'source_url': 'eq.$sourceUrl',
        },
        select: 'id',
        limit: 1,
      );
      if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
        return res.data!.first['id']?.toString();
      }
    } catch (_) {
      // 查询失败不阻断导入，交由后续逻辑处理
    }
    return null;
  }

  /// 按书名+作者兜底去重，返回已存在的小说 id；无则返回 null。
  Future<String?> findExistingByTitleAuthor(String title, String author) async {
    try {
      final res = await ApiClient.get(
        'novels',
        filters: {
          'title': 'eq.$title',
          'author': 'eq.$author',
        },
        select: 'id',
        limit: 1,
      );
      if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
        return res.data!.first['id']?.toString();
      }
    } catch (_) {
      // 查询失败不阻断导入
    }
    return null;
  }
}
