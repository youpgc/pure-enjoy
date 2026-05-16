import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import '../features/life/models/expense_model.dart';
import '../features/life/models/mood_diary_model.dart';
import '../features/life/models/note_model.dart';
import '../features/life/models/weight_record_model.dart';
import '../features/life/models/favorite_model.dart';
import '../features/life/models/reminder_model.dart';
import '../features/life/models/habit_model.dart';
import '../features/novel/models/novel_model.dart';

/// 数据库服务
class DatabaseService {
  static DatabaseService? _instance;
  
  DatabaseService._();
  
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }
  
  /// 获取 REST API 基础 URL
  String get _restUrl => '${SupabaseConfig.url}/rest/v1';
  
  /// 获取认证 Headers
  Map<String, String> get _headers => AuthService.instance.authHeaders;
  
  // ==================== 支出记录 CRUD ====================
  
  /// 获取用户的所有支出记录
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/expenses?user_id=eq.$userId&order=date.desc'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ExpenseModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get expenses error: $e');
      return [];
    }
  }
  
  /// 创建支出记录
  Future<ExpenseModel?> createExpense(ExpenseModel expense) async {
    try {
      final response = await http.post(
        Uri.parse('$_restUrl/expenses'),
        headers: _headers,
        body: jsonEncode(expense.toJson()),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return ExpenseModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Create expense error: $e');
      return null;
    }
  }
  
  /// 更新支出记录
  Future<ExpenseModel?> updateExpense(ExpenseModel expense) async {
    try {
      final response = await http.patch(
        Uri.parse('$_restUrl/expenses?id=eq.${expense.id}'),
        headers: _headers,
        body: jsonEncode(expense.toJson()),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return ExpenseModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Update expense error: $e');
      return null;
    }
  }
  
  /// 删除支出记录
  Future<bool> deleteExpense(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_restUrl/expenses?id=eq.$id'),
        headers: _headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Delete expense error: $e');
      return false;
    }
  }
  
  // ==================== 心情日记 CRUD ====================
  
  /// 获取用户的所有心情日记
  Future<List<MoodDiaryModel>> getMoodDiaries(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/mood_diaries?user_id=eq.$userId&order=date.desc'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MoodDiaryModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get mood diaries error: $e');
      return [];
    }
  }
  
  /// 创建心情日记
  Future<MoodDiaryModel?> createMoodDiary(MoodDiaryModel diary) async {
    try {
      final response = await http.post(
        Uri.parse('$_restUrl/mood_diaries'),
        headers: _headers,
        body: jsonEncode(diary.toJson()),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return MoodDiaryModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Create mood diary error: $e');
      return null;
    }
  }
  
  /// 更新心情日记
  Future<MoodDiaryModel?> updateMoodDiary(MoodDiaryModel diary) async {
    try {
      final response = await http.patch(
        Uri.parse('$_restUrl/mood_diaries?id=eq.${diary.id}'),
        headers: _headers,
        body: jsonEncode(diary.toJson()),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return MoodDiaryModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Update mood diary error: $e');
      return null;
    }
  }
  
  /// 删除心情日记
  Future<bool> deleteMoodDiary(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_restUrl/mood_diaries?id=eq.$id'),
        headers: _headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Delete mood diary error: $e');
      return false;
    }
  }
  
  // ==================== 笔记 CRUD ====================
  
  /// 获取用户的所有笔记
  Future<List<NoteModel>> getNotes(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/notes?user_id=eq.$userId&order=is_pinned.desc,created_at.desc'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => NoteModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get notes error: $e');
      return [];
    }
  }
  
  /// 创建笔记
  Future<NoteModel?> createNote(NoteModel note) async {
    try {
      final response = await http.post(
        Uri.parse('$_restUrl/notes'),
        headers: _headers,
        body: jsonEncode(note.toJson()),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return NoteModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Create note error: $e');
      return null;
    }
  }
  
  /// 更新笔记
  Future<NoteModel?> updateNote(NoteModel note) async {
    try {
      final response = await http.patch(
        Uri.parse('$_restUrl/notes?id=eq.${note.id}'),
        headers: _headers,
        body: jsonEncode(note.toJson()),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return NoteModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Update note error: $e');
      return null;
    }
  }
  
  /// 删除笔记
  Future<bool> deleteNote(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_restUrl/notes?id=eq.$id'),
        headers: _headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Delete note error: $e');
      return false;
    }
  }
  
  /// 切换笔记置顶状态
  Future<bool> togglePin(String id, bool isPinned) async {
    try {
      final response = await http.patch(
        Uri.parse('$_restUrl/notes?id=eq.$id'),
        headers: _headers,
        body: jsonEncode({'is_pinned': isPinned}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Toggle pin error: $e');
      return false;
    }
  }
  
  // ==================== 体重记录 CRUD ====================
  
  /// 获取用户的所有体重记录
  Future<List<WeightRecordModel>> getWeightRecords(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/weight_records?user_id=eq.$userId&order=date.desc'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WeightRecordModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get weight records error: $e');
      return [];
    }
  }
  
  /// 创建体重记录
  Future<WeightRecordModel?> createWeightRecord(WeightRecordModel record) async {
    try {
      final response = await http.post(
        Uri.parse('$_restUrl/weight_records'),
        headers: _headers,
        body: jsonEncode(record.toJson()),
      );
      
      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        return WeightRecordModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Create weight record error: $e');
      return null;
    }
  }
  
  /// 更新体重记录
  Future<WeightRecordModel?> updateWeightRecord(WeightRecordModel record) async {
    try {
      final response = await http.patch(
        Uri.parse('$_restUrl/weight_records?id=eq.${record.id}'),
        headers: _headers,
        body: jsonEncode(record.toJson()),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return WeightRecordModel.fromJson(data.first);
      }
      return null;
    } catch (e) {
      print('Update weight record error: $e');
      return null;
    }
  }
  
  /// 删除体重记录
  Future<bool> deleteWeightRecord(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_restUrl/weight_records?id=eq.$id'),
        headers: _headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Delete weight record error: $e');
      return false;
    }
  }
  
  // ==================== 小说相关 ====================
  
  /// 获取所有公共小说（user_id is null）
  Future<List<NovelModel>> getNovels() async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/novels?user_id=is.null&order=created_at.desc'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => NovelModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get novels error: $e');
      return [];
    }
  }
  
  /// 获取小说章节列表
  Future<List<NovelChapterModel>> getNovelChapters(String novelId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/novel_chapters?novel_id=eq.$novelId&order=chapter_num.asc'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => NovelChapterModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get novel chapters error: $e');
      return [];
    }
  }
  
  /// 获取章节内容
  Future<NovelChapterModel?> getChapterContent(String chapterId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/novel_chapters?id=eq.$chapterId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return NovelChapterModel.fromJson(data.first);
        }
      }
      return null;
    } catch (e) {
      print('Get chapter content error: $e');
      return null;
    }
  }
  
  /// 获取用户书架
  Future<List<Map<String, dynamic>>> getUserNovels(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/user_novels?user_id=eq.$userId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get user novels error: $e');
      return [];
    }
  }
  
  /// 添加到书架
  Future<bool> addToBookshelf(String userId, String novelId) async {
    try {
      final response = await http.post(
        Uri.parse('$_restUrl/user_novels'),
        headers: _headers,
        body: jsonEncode({
          'user_id': userId,
          'novel_id': novelId,
          'is_collected': true,
        }),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Add to bookshelf error: $e');
      return false;
    }
  }
  
  /// 从书架移除
  Future<bool> removeFromBookshelf(String userId, String novelId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_restUrl/user_novels?user_id=eq.$userId&novel_id=eq.$novelId'),
        headers: _headers,
      );
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Remove from bookshelf error: $e');
      return false;
    }
  }
  
  /// 更新阅读进度
  Future<bool> updateReadingProgress({
    required String userId,
    required String novelId,
    required String chapterId,
    required int position,
    required double progress,
  }) async {
    try {
      // 先检查是否已有记录
      final checkResponse = await http.get(
        Uri.parse('$_restUrl/user_novels?user_id=eq.$userId&novel_id=eq.$novelId'),
        headers: _headers,
      );
      
      if (checkResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(checkResponse.body);
        
        if (data.isNotEmpty) {
          // 更新现有记录
          final response = await http.patch(
            Uri.parse('$_restUrl/user_novels?user_id=eq.$userId&novel_id=eq.$novelId'),
            headers: _headers,
            body: jsonEncode({
              'last_chapter': chapterId,
              'progress': progress,
              'last_read_at': DateTime.now().toIso8601String(),
            }),
          );
          return response.statusCode == 200;
        } else {
          // 创建新记录
          final response = await http.post(
            Uri.parse('$_restUrl/user_novels'),
            headers: _headers,
            body: jsonEncode({
              'user_id': userId,
              'novel_id': novelId,
              'last_chapter': chapterId,
              'progress': progress,
              'last_read_at': DateTime.now().toIso8601String(),
              'is_collected': false,
            }),
          );
          return response.statusCode == 201;
        }
      }
      return false;
    } catch (e) {
      print('Update reading progress error: $e');
      return false;
    }
  }
  
  /// 获取阅读进度
  Future<Map<String, dynamic>?> getReadingProgress(String userId, String novelId) async {
    try {
      final response = await http.get(
        Uri.parse('$_restUrl/user_novels?user_id=eq.$userId&novel_id=eq.$novelId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first;
        }
      }
      return null;
    } catch (e) {
      print('Get reading progress error: $e');
      return null;
    }
  }

  // ==================== 收藏夹 CRUD ====================

  /// 获取用户的所有收藏
  Future<List<FavoriteModel>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('favorites') ?? [];
      return data.map((json) => FavoriteModel.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      print('Get favorites error: $e');
      return [];
    }
  }

  /// 添加收藏
  Future<void> insertFavorite(FavoriteModel favorite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      favorites.add(favorite);
      await prefs.setStringList(
        'favorites',
        favorites.map((f) => jsonEncode(f.toJson())).toList(),
      );
    } catch (e) {
      print('Insert favorite error: $e');
      throw e;
    }
  }

  /// 更新收藏
  Future<void> updateFavorite(FavoriteModel favorite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      final index = favorites.indexWhere((f) => f.id == favorite.id);
      if (index != -1) {
        favorites[index] = favorite;
        await prefs.setStringList(
          'favorites',
          favorites.map((f) => jsonEncode(f.toJson())).toList(),
        );
      }
    } catch (e) {
      print('Update favorite error: $e');
      throw e;
    }
  }

  /// 删除收藏
  Future<void> deleteFavorite(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      favorites.removeWhere((f) => f.id == id);
      await prefs.setStringList(
        'favorites',
        favorites.map((f) => jsonEncode(f.toJson())).toList(),
      );
    } catch (e) {
      print('Delete favorite error: $e');
      throw e;
    }
  }

  // ==================== 提醒事项 CRUD ====================

  /// 获取用户的所有提醒
  Future<List<ReminderModel>> getReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('reminders') ?? [];
      return data.map((json) => ReminderModel.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      print('Get reminders error: $e');
      return [];
    }
  }

  /// 添加提醒
  Future<void> insertReminder(ReminderModel reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = await getReminders();
      reminders.add(reminder);
      await prefs.setStringList(
        'reminders',
        reminders.map((r) => jsonEncode(r.toJson())).toList(),
      );
    } catch (e) {
      print('Insert reminder error: $e');
      throw e;
    }
  }

  /// 更新提醒
  Future<void> updateReminder(ReminderModel reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = await getReminders();
      final index = reminders.indexWhere((r) => r.id == reminder.id);
      if (index != -1) {
        reminders[index] = reminder;
        await prefs.setStringList(
          'reminders',
          reminders.map((r) => jsonEncode(r.toJson())).toList(),
        );
      }
    } catch (e) {
      print('Update reminder error: $e');
      throw e;
    }
  }

  /// 删除提醒
  Future<void> deleteReminder(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = await getReminders();
      reminders.removeWhere((r) => r.id == id);
      await prefs.setStringList(
        'reminders',
        reminders.map((r) => jsonEncode(r.toJson())).toList(),
      );
    } catch (e) {
      print('Delete reminder error: $e');
      throw e;
    }
  }

  // ==================== 习惯打卡 CRUD ====================

  /// 获取用户的所有习惯
  Future<List<HabitModel>> getHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('habits') ?? [];
      return data.map((json) => HabitModel.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      print('Get habits error: $e');
      return [];
    }
  }

  /// 添加习惯
  Future<void> insertHabit(HabitModel habit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habits = await getHabits();
      habits.add(habit);
      await prefs.setStringList(
        'habits',
        habits.map((h) => jsonEncode(h.toJson())).toList(),
      );
    } catch (e) {
      print('Insert habit error: $e');
      throw e;
    }
  }

  /// 更新习惯
  Future<void> updateHabit(HabitModel habit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habits = await getHabits();
      final index = habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        habits[index] = habit;
        await prefs.setStringList(
          'habits',
          habits.map((h) => jsonEncode(h.toJson())).toList(),
        );
      }
    } catch (e) {
      print('Update habit error: $e');
      throw e;
    }
  }

  /// 删除习惯
  Future<void> deleteHabit(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habits = await getHabits();
      habits.removeWhere((h) => h.id == id);
      await prefs.setStringList(
        'habits',
        habits.map((h) => jsonEncode(h.toJson())).toList(),
      );
      // 同时删除相关的打卡记录
      await prefs.remove('habit_checkins_$id');
    } catch (e) {
      print('Delete habit error: $e');
      throw e;
    }
  }

  /// 获取习惯的打卡记录
  Future<List<HabitCheckinModel>> getHabitCheckins(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('habit_checkins_$habitId') ?? [];
      return data.map((json) => HabitCheckinModel.fromJson(jsonDecode(json))).toList();
    } catch (e) {
      print('Get habit checkins error: $e');
      return [];
    }
  }

  /// 添加打卡记录
  Future<void> insertHabitCheckin(HabitCheckinModel checkin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checkins = await getHabitCheckins(checkin.habitId);
      checkins.add(checkin);
      await prefs.setStringList(
        'habit_checkins_${checkin.habitId}',
        checkins.map((c) => jsonEncode(c.toJson())).toList(),
      );
    } catch (e) {
      print('Insert habit checkin error: $e');
      throw e;
    }
  }
}
