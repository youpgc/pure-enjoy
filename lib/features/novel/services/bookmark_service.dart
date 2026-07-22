import '../../../services/api_client.dart';
import '../../../services/session_manager.dart';
import '../models/novel_model.dart';

/// 书签服务
/// 管理小说书签的增删改查，包括自动书签和手动书签
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  String? get _userId => SessionManager.instance.currentUserId;

  /// 获取指定小说的所有书签
  Future<List<NovelBookmark>> getBookmarks(String novelId) async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await ApiClient.get(
      'novel_bookmarks',
      filters: {
        'user_id': 'eq.$userId',
        'novel_id': 'eq.$novelId',
      },
      order: 'chapter_order.asc,char_offset.asc',
      limit: 100,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!.map((json) => NovelBookmark.fromJson(json)).toList();
    }
    return [];
  }

  /// 获取指定章节的单个书签
  Future<NovelBookmark?> getBookmarkAt(
    String novelId,
    String chapterId,
    int charOffset,
  ) async {
    final userId = _userId;
    if (userId == null) return null;

    final result = await ApiClient.get(
      'novel_bookmarks',
      filters: {
        'user_id': 'eq.$userId',
        'novel_id': 'eq.$novelId',
        'chapter_id': 'eq.$chapterId',
        'char_offset': 'eq.$charOffset',
      },
      limit: 1,
    );

    if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
      return NovelBookmark.fromJson(result.data!.first);
    }
    return null;
  }

  /// 检查指定位置是否有书签
  Future<bool> hasBookmark(
    String novelId,
    String chapterId,
    int charOffset,
  ) async {
    final bookmark = await getBookmarkAt(novelId, chapterId, charOffset);
    return bookmark != null;
  }

  /// 添加手动书签
  Future<NovelBookmark?> addBookmark({
    required String novelId,
    required String chapterId,
    required int chapterOrder,
    int charOffset = 0,
    String? note,
  }) async {
    final userId = _userId;
    if (userId == null) return null;

    final bookmark = NovelBookmark(
      id: '',
      userId: userId,
      novelId: novelId,
      chapterId: chapterId,
      chapterOrder: chapterOrder,
      charOffset: charOffset,
      note: note,
      type: BookmarkType.manual,
      createdAt: DateTime.now(),
    );

    final result = await ApiClient.post('novel_bookmarks', bookmark.toJson());
    if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
      return NovelBookmark.fromJson(result.data!.first);
    }
    return null;
  }

  /// 移除书签（通过ID）
  Future<bool> removeBookmark(String bookmarkId) async {
    final result = await ApiClient.delete('novel_bookmarks', id: bookmarkId);
    return result.isSuccess;
  }

  /// 移除指定位置的书签
  Future<bool> removeBookmarkAt(
    String novelId,
    String chapterId,
    int charOffset,
  ) async {
    final bookmark = await getBookmarkAt(novelId, chapterId, charOffset);
    if (bookmark == null) return false;
    return removeBookmark(bookmark.id);
  }

  /// 切换书签（有则删除，无则添加）
  Future<bool> toggleBookmark({
    required String novelId,
    required String chapterId,
    required int chapterOrder,
    int charOffset = 0,
    String? note,
  }) async {
    final exists = await hasBookmark(novelId, chapterId, charOffset);
    if (exists) {
      return removeBookmarkAt(novelId, chapterId, charOffset);
    } else {
      final added = await addBookmark(
        novelId: novelId,
        chapterId: chapterId,
        chapterOrder: chapterOrder,
        charOffset: charOffset,
        note: note,
      );
      return added != null;
    }
  }

}
