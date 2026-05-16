import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../features/life/models/expense_model.dart';
import '../features/life/models/mood_diary_model.dart';
import '../features/life/models/note_model.dart';
import '../features/life/models/weight_record_model.dart';
import '../features/novel/models/novel_model.dart';

/// 数据库服务类 - 封装 Supabase 数据库操作
class DatabaseService {
  static DatabaseService? _instance;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  // Supabase 客户端
  SupabaseClient get _client => Supabase.instance.client;

  // ==================== 支出记录 CRUD ====================

  /// 获取用户所有支出
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    try {
      final response = await _client
          .from(AppConfig.expensesTable)
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('获取支出记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取支出记录失败: $e');
      rethrow;
    }
  }

  /// 创建支出
  Future<ExpenseModel> createExpense(ExpenseModel expense) async {
    try {
      final response = await _client
          .from(AppConfig.expensesTable)
          .insert(expense.toJson())
          .select()
          .single();

      return ExpenseModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('创建支出记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('创建支出记录失败: $e');
      rethrow;
    }
  }

  /// 更新支出
  Future<ExpenseModel> updateExpense(ExpenseModel expense) async {
    try {
      final response = await _client
          .from(AppConfig.expensesTable)
          .update({
            ...expense.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', expense.id)
          .select()
          .single();

      return ExpenseModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('更新支出记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('更新支出记录失败: $e');
      rethrow;
    }
  }

  /// 删除支出
  Future<void> deleteExpense(String id) async {
    try {
      await _client
          .from(AppConfig.expensesTable)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint('删除支出记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('删除支出记录失败: $e');
      rethrow;
    }
  }

  // ==================== 心情日记 CRUD ====================

  /// 获取用户所有心情日记
  Future<List<MoodDiaryModel>> getMoodDiaries(String userId) async {
    try {
      final response = await _client
          .from(AppConfig.moodDiariesTable)
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return (response as List<dynamic>)
          .map((json) => MoodDiaryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('获取心情日记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取心情日记失败: $e');
      rethrow;
    }
  }

  /// 创建心情日记
  Future<MoodDiaryModel> createMoodDiary(MoodDiaryModel diary) async {
    try {
      final response = await _client
          .from(AppConfig.moodDiariesTable)
          .insert(diary.toJson())
          .select()
          .single();

      return MoodDiaryModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('创建心情日记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('创建心情日记失败: $e');
      rethrow;
    }
  }

  /// 更新心情日记
  Future<MoodDiaryModel> updateMoodDiary(MoodDiaryModel diary) async {
    try {
      final response = await _client
          .from(AppConfig.moodDiariesTable)
          .update({
            ...diary.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', diary.id)
          .select()
          .single();

      return MoodDiaryModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('更新心情日记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('更新心情日记失败: $e');
      rethrow;
    }
  }

  /// 删除心情日记
  Future<void> deleteMoodDiary(String id) async {
    try {
      await _client
          .from(AppConfig.moodDiariesTable)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint('删除心情日记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('删除心情日记失败: $e');
      rethrow;
    }
  }

  // ==================== 笔记 CRUD ====================

  /// 获取用户所有笔记
  Future<List<NoteModel>> getNotes(String userId) async {
    try {
      final response = await _client
          .from(AppConfig.notesTable)
          .select()
          .eq('user_id', userId)
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('获取笔记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取笔记失败: $e');
      rethrow;
    }
  }

  /// 创建笔记
  Future<NoteModel> createNote(NoteModel note) async {
    try {
      final response = await _client
          .from(AppConfig.notesTable)
          .insert(note.toJson())
          .select()
          .single();

      return NoteModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('创建笔记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('创建笔记失败: $e');
      rethrow;
    }
  }

  /// 更新笔记
  Future<NoteModel> updateNote(NoteModel note) async {
    try {
      final response = await _client
          .from(AppConfig.notesTable)
          .update({
            ...note.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', note.id)
          .select()
          .single();

      return NoteModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('更新笔记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('更新笔记失败: $e');
      rethrow;
    }
  }

  /// 删除笔记
  Future<void> deleteNote(String id) async {
    try {
      await _client
          .from(AppConfig.notesTable)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint('删除笔记失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('删除笔记失败: $e');
      rethrow;
    }
  }

  /// 切换笔记置顶状态
  Future<NoteModel> togglePin(String id, bool isPinned) async {
    try {
      final response = await _client
          .from(AppConfig.notesTable)
          .update({
            'is_pinned': isPinned,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      return NoteModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('切换笔记置顶状态失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('切换笔记置顶状态失败: $e');
      rethrow;
    }
  }

  // ==================== 体重记录 CRUD ====================

  /// 获取用户所有体重记录
  Future<List<WeightRecordModel>> getWeightRecords(String userId) async {
    try {
      final response = await _client
          .from(AppConfig.weightRecordsTable)
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return (response as List<dynamic>)
          .map((json) => WeightRecordModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('获取体重记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取体重记录失败: $e');
      rethrow;
    }
  }

  /// 创建体重记录
  Future<WeightRecordModel> createWeightRecord(WeightRecordModel record) async {
    try {
      final response = await _client
          .from(AppConfig.weightRecordsTable)
          .insert(record.toJson())
          .select()
          .single();

      return WeightRecordModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('创建体重记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('创建体重记录失败: $e');
      rethrow;
    }
  }

  /// 更新体重记录
  Future<WeightRecordModel> updateWeightRecord(WeightRecordModel record) async {
    try {
      final response = await _client
          .from(AppConfig.weightRecordsTable)
          .update({
            ...record.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', record.id)
          .select()
          .single();

      return WeightRecordModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('更新体重记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('更新体重记录失败: $e');
      rethrow;
    }
  }

  /// 删除体重记录
  Future<void> deleteWeightRecord(String id) async {
    try {
      await _client
          .from(AppConfig.weightRecordsTable)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint('删除体重记录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('删除体重记录失败: $e');
      rethrow;
    }
  }

  // ==================== 小说相关 ====================

  /// 获取所有公共小说（user_id is null）
  Future<List<NovelModel>> getNovels() async {
    try {
      final response = await _client
          .from(AppConfig.novelsTable)
          .select()
          .isFilter('user_id', null)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => NovelModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('获取小说列表失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取小说列表失败: $e');
      rethrow;
    }
  }

  /// 获取小说章节
  Future<List<NovelChapterModel>> getNovelChapters(String novelId) async {
    try {
      final response = await _client
          .from(AppConfig.novelChaptersTable)
          .select()
          .eq('novel_id', novelId)
          .order('chapter_order', ascending: true);

      return (response as List<dynamic>)
          .map((json) => NovelChapterModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('获取小说章节失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取小说章节失败: $e');
      rethrow;
    }
  }

  /// 获取章节内容
  Future<NovelChapterModel> getChapterContent(String chapterId) async {
    try {
      final response = await _client
          .from(AppConfig.novelChaptersTable)
          .select()
          .eq('id', chapterId)
          .single();

      return NovelChapterModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('获取章节内容失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取章节内容失败: $e');
      rethrow;
    }
  }

  /// 获取用户书架
  Future<List<Map<String, dynamic>>> getUserNovels(String userId) async {
    try {
      final response = await _client
          .from(AppConfig.userNovelsTable)
          .select('*, novels(*)')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('获取用户书架失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取用户书架失败: $e');
      rethrow;
    }
  }

  /// 添加到书架
  Future<Map<String, dynamic>> addToBookshelf(String userId, String novelId) async {
    try {
      final response = await _client
          .from(AppConfig.userNovelsTable)
          .insert({
            'user_id': userId,
            'novel_id': novelId,
            'added_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('添加到书架失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('添加到书架失败: $e');
      rethrow;
    }
  }

  /// 从书架移除
  Future<void> removeFromBookshelf(String userId, String novelId) async {
    try {
      await _client
          .from(AppConfig.userNovelsTable)
          .delete()
          .eq('user_id', userId)
          .eq('novel_id', novelId);
    } on PostgrestException catch (e) {
      debugPrint('从书架移除失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('从书架移除失败: $e');
      rethrow;
    }
  }

  /// 更新阅读进度
  Future<ReadingProgressModel> updateReadingProgress({
    required String userId,
    required String novelId,
    String? currentChapterId,
    int currentPosition = 0,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'novel_id': novelId,
        'current_chapter_id': currentChapterId,
        'current_position': currentPosition,
        'last_read_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from(AppConfig.readingProgressTable)
          .upsert(data, onConflict: 'user_id,novel_id')
          .select()
          .single();

      return ReadingProgressModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('更新阅读进度失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('更新阅读进度失败: $e');
      rethrow;
    }
  }

  /// 获取阅读进度
  Future<ReadingProgressModel?> getReadingProgress(String userId, String novelId) async {
    try {
      final response = await _client
          .from(AppConfig.readingProgressTable)
          .select()
          .eq('user_id', userId)
          .eq('novel_id', novelId)
          .maybeSingle();

      if (response == null) return null;
      return ReadingProgressModel.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('获取阅读进度失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取阅读进度失败: $e');
      rethrow;
    }
  }

  // ==================== Realtime 订阅 ====================

  /// 订阅支出记录变化
  RealtimeChannel subscribeToExpenses(
    String userId,
    void Function(PostgresChangePayload) callback,
  ) {
    return _client
        .channel('expenses:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConfig.expensesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: callback,
        )
        .subscribe();
  }

  /// 订阅笔记变化
  RealtimeChannel subscribeToNotes(
    String userId,
    void Function(PostgresChangePayload) callback,
  ) {
    return _client
        .channel('notes:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConfig.notesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: callback,
        )
        .subscribe();
  }

  /// 取消订阅
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
