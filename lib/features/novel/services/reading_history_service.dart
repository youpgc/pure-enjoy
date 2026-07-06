import '../../../services/api_client.dart';
import '../../../services/session_manager.dart';
import '../models/novel_model.dart';

/// 阅读历史明细服务
/// 记录用户的阅读行为明细，用于支撑排行榜和推荐算法
class ReadingHistoryService {
  static final ReadingHistoryService _instance = ReadingHistoryService._internal();
  factory ReadingHistoryService() => _instance;
  ReadingHistoryService._internal();

  String? get _userId => SessionManager.instance.currentUserId;

  /// 记录阅读历史
  Future<bool> recordReading({
    required String novelId,
    required String? chapterId,
    required int chapterOrder,
    required int readDurationSeconds,
    required double progress,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    final record = ReadingHistoryRecord(
      id: '',
      userId: userId,
      novelId: novelId,
      chapterId: chapterId,
      chapterOrder: chapterOrder,
      readDurationSeconds: readDurationSeconds,
      progress: progress,
      createdAt: DateTime.now(),
    );

    final result = await ApiClient.post('reading_history', record.toJson());
    return result.isSuccess;
  }

  /// 获取用户的阅读历史（分页）
  Future<List<ReadingHistoryRecord>> getUserHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await ApiClient.get(
      'reading_history',
      filters: {'user_id': 'eq.$userId'},
      order: 'created_at.desc',
      limit: limit,
      offset: offset,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => ReadingHistoryRecord.fromJson(json))
          .toList();
    }
    return [];
  }

  /// 获取指定小说的阅读历史
  Future<List<ReadingHistoryRecord>> getNovelHistory(String novelId) async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await ApiClient.get(
      'reading_history',
      filters: {
        'user_id': 'eq.$userId',
        'novel_id': 'eq.$novelId',
      },
      order: 'created_at.desc',
      limit: 100,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((json) => ReadingHistoryRecord.fromJson(json))
          .toList();
    }
    return [];
  }
}
