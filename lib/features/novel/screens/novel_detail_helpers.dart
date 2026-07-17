import '../models/novel_model.dart';
import '../../../services/api_client.dart';

/// 小说章节分页查询结果
class ChapterPage {
  final List<NovelChapterModel> chapters;
  final bool hasMore;
  final bool isSuccess;

  const ChapterPage({
    required this.chapters,
    required this.hasMore,
    required this.isSuccess,
  });
}

/// 查询单页小说章节列表（按章节号升序分页）
Future<ChapterPage> fetchNovelChapterPage(
  String novelId,
  int limit,
  int offset,
) async {
  final result = await ApiClient.get(
    'novel_chapters',
    filters: {
      'novel_id': 'eq.$novelId',
      'chapter_num': 'gte.1',
    },
    columns: 'id,title,chapter_num,word_count',
    order: 'chapter_num.asc',
    limit: limit,
    offset: offset,
  );
  if (result.isSuccess) {
    final data = result.data!;
    final chapters = data.map((json) => NovelChapterModel.fromJson(json)).toList();
    return ChapterPage(
      chapters: chapters,
      hasMore: data.length >= limit,
      isSuccess: true,
    );
  }
  return const ChapterPage(chapters: [], hasMore: false, isSuccess: false);
}

/// 全量加载小说章节（用于弹窗"查看全部"），按批次顺序拉取直到无更多数据
Future<List<NovelChapterModel>> loadAllNovelChapters(String novelId) async {
  const batchSize = 50;
  final allChapters = <NovelChapterModel>[];
  int offset = 0;
  bool hasMore = true;

  while (hasMore) {
    final result = await ApiClient.get(
      'novel_chapters',
      filters: {
        'novel_id': 'eq.$novelId',
        'chapter_num': 'gte.1',
      },
      columns: 'id,title,chapter_num,word_count',
      order: 'chapter_num.asc',
      limit: batchSize,
      offset: offset,
    );

    if (result.isSuccess) {
      final data = result.data!;
      final batch = data.map((json) => NovelChapterModel.fromJson(json)).toList();
      allChapters.addAll(batch);
      hasMore = data.length >= batchSize;
      offset += batchSize;
    } else {
      hasMore = false;
    }
  }

  return allChapters;
}

/// 新增或更新用户对小说的评分
Future<void> upsertNovelRating(String userId, String novelId, double rating) async {
  final existing = await ApiClient.get(
    'novel_ratings',
    filters: {
      'user_id': 'eq.$userId',
      'novel_id': 'eq.$novelId',
    },
    columns: 'id',
    limit: 1,
  );

  if (existing.isSuccess && existing.data != null && existing.data!.isNotEmpty) {
    final id = existing.data!.first['id'] as String;
    await ApiClient.patch('novel_ratings', {'rating': rating}, id: id);
  } else {
    await ApiClient.post('novel_ratings', {
      'user_id': userId,
      'novel_id': novelId,
      'rating': rating,
    });
  }
}
