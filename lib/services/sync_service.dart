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

/// 数据同步服务
/// 将本地数据同步到 Supabase 服务器
class SyncService {
  static SyncService? _instance;
  
  SyncService._();
  
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }
  
  /// 获取 REST API 基础 URL
  String get _restUrl => '${SupabaseConfig.url}/rest/v1';
  
  /// 获取认证 Headers
  Map<String, String> get _headers => AuthService.instance.authHeaders;
  
  /// 本地数据 Key 前缀
  static const String _localDataKey = 'local_data_';
  
  /// 最后同步时间 Key
  static const String _lastSyncKey = 'last_sync_';
  
  // ==================== 通用同步方法 ====================
  
  /// 保存数据到本地
  Future<void> _saveToLocal(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localDataKey + key, jsonEncode(data));
    await prefs.setString(_lastSyncKey + key, DateTime.now().toIso8601String());
  }
  
  /// 从本地加载数据
  Future<List<Map<String, dynamic>>> _loadFromLocal(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_localDataKey + key);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final time = prefs.getString(_lastSyncKey + table);
    if (time != null) {
      return DateTime.parse(time);
    }
    return null;
  }
  
  // ==================== 消费记录同步 ====================
  
  /// 同步支出数据
  Future<bool> syncExpenses(List<ExpenseModel> localExpenses) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncExpenses: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final expense in localExpenses) {
        // 构造完整数据
        final expenseData = {
          'id': expense.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'amount': expense.amount,
          'category': expense.category,
          'description': expense.description,
          'date': expense.date.toIso8601String().split('T').first,
          'created_at': expense.createdAt.toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/expenses'),
          headers: _headers,
          body: jsonEncode(expenseData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncExpenses: 同步失败 ${expense.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncExpenses: 成功同步 $successCount/${localExpenses.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncExpenses error: $e');
      return false;
    }
  }
  
  // ==================== 心情日记同步 ====================
  
  /// 同步心情日记
  Future<bool> syncMoodDiaries(List<MoodDiaryModel> localDiaries) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncMoodDiaries: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final diary in localDiaries) {
        // 构造完整数据，使用数据库字段名 date
        final diaryData = {
          'id': diary.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'mood': diary.mood,
          'mood_label': diary.moodScore.toString(),
          'content': diary.content,
          'tags': diary.tags,
          'date': diary.entryDate.toIso8601String().split('T').first,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/mood_diaries'),
          headers: _headers,
          body: jsonEncode(diaryData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncMoodDiaries: 同步失败 ${diary.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncMoodDiaries: 成功同步 $successCount/${localDiaries.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncMoodDiaries error: $e');
      return false;
    }
  }
  
  // ==================== 笔记同步 ====================
  
  /// 同步笔记
  Future<bool> syncNotes(List<NoteModel> localNotes) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncNotes: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final note in localNotes) {
        final noteData = {
          'id': note.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'title': note.title,
          'content': note.content,
          'is_pinned': note.isPinned,
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt.toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/notes'),
          headers: _headers,
          body: jsonEncode(noteData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncNotes: 同步失败 ${note.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncNotes: 成功同步 $successCount/${localNotes.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncNotes error: $e');
      return false;
    }
  }
  
  // ==================== 体重记录同步 ====================
  
  /// 同步体重记录
  Future<bool> syncWeightRecords(List<WeightRecordModel> localRecords) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncWeightRecords: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final record in localRecords) {
        final recordData = {
          'id': record.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'weight': record.weight,
          'unit': record.unit,
          'body_fat': record.bodyFat,
          'note': record.note,
          'date': record.date.toIso8601String().split('T').first,
          'created_at': record.createdAt.toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/weight_records'),
          headers: _headers,
          body: jsonEncode(recordData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncWeightRecords: 同步失败 ${record.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncWeightRecords: 成功同步 $successCount/${localRecords.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncWeightRecords error: $e');
      return false;
    }
  }
  
  // ==================== 收藏夹同步 ====================
  
  /// 同步收藏
  Future<bool> syncFavorites(List<FavoriteModel> localFavorites) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncFavorites: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final favorite in localFavorites) {
        final favoriteData = {
          'id': favorite.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'title': favorite.title,
          'url': favorite.url,
          'description': favorite.description,
          'category': favorite.category,
          'is_pinned': favorite.isPinned,
          'created_at': favorite.createdAt.toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/user_favorites'),
          headers: _headers,
          body: jsonEncode(favoriteData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncFavorites: 同步失败 ${favorite.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncFavorites: 成功同步 $successCount/${localFavorites.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncFavorites error: $e');
      return false;
    }
  }
  
  // ==================== 提醒事项同步 ====================
  
  /// 同步提醒
  Future<bool> syncReminders(List<ReminderModel> localReminders) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncReminders: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final reminder in localReminders) {
        final reminderData = {
          'id': reminder.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'title': reminder.title,
          'description': reminder.description,
          'remind_at': reminder.remindAt.toIso8601String(),
          'is_completed': reminder.isCompleted,
          'repeat_type': reminder.repeatType,
          'created_at': reminder.createdAt.toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/user_reminders'),
          headers: _headers,
          body: jsonEncode(reminderData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncReminders: 同步失败 ${reminder.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncReminders: 成功同步 $successCount/${localReminders.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncReminders error: $e');
      return false;
    }
  }
  
  // ==================== 习惯打卡同步 ====================
  
  /// 同步习惯
  Future<bool> syncHabits(List<HabitModel> localHabits) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        print('❌ syncHabits: 用户未登录');
        return false;
      }
      
      int successCount = 0;
      for (final habit in localHabits) {
        final habitData = {
          'id': habit.id,
          'user_id': userId,
          'user_nickname': AuthService.instance.currentUserName,
          'name': habit.name,
          'description': habit.description,
          'frequency': habit.frequency,
          'target_days': habit.targetDays,
          'start_date': habit.startDate.toIso8601String().split('T').first,
          'is_active': habit.isActive,
          'created_at': habit.createdAt.toIso8601String(),
        };
        
        final response = await http.post(
          Uri.parse('$_restUrl/user_habits'),
          headers: _headers,
          body: jsonEncode(habitData),
        );
        
        if (response.statusCode == 201) {
          successCount++;
        } else {
          print('❌ syncHabits: 同步失败 ${habit.id}, status=${response.statusCode}, body=${response.body}');
        }
      }
      
      print('✅ syncHabits: 成功同步 $successCount/${localHabits.length} 条');
      return successCount > 0;
    } catch (e) {
      print('❌ syncHabits error: $e');
      return false;
    }
  }
  
  // ==================== 批量同步 ====================
  
  /// 同步所有本地数据到服务器
  Future<Map<String, bool>> syncAll({
    List<ExpenseModel>? expenses,
    List<MoodDiaryModel>? moodDiaries,
    List<NoteModel>? notes,
    List<WeightRecordModel>? weightRecords,
    List<FavoriteModel>? favorites,
    List<ReminderModel>? reminders,
    List<HabitModel>? habits,
  }) async {
    final results = <String, bool>{};
    
    if (expenses != null && expenses.isNotEmpty) {
      results['expenses'] = await syncExpenses(expenses);
    }
    
    if (moodDiaries != null && moodDiaries.isNotEmpty) {
      results['moodDiaries'] = await syncMoodDiaries(moodDiaries);
    }
    
    if (notes != null && notes.isNotEmpty) {
      results['notes'] = await syncNotes(notes);
    }
    
    if (weightRecords != null && weightRecords.isNotEmpty) {
      results['weightRecords'] = await syncWeightRecords(weightRecords);
    }
    
    if (favorites != null && favorites.isNotEmpty) {
      results['favorites'] = await syncFavorites(favorites);
    }
    
    if (reminders != null && reminders.isNotEmpty) {
      results['reminders'] = await syncReminders(reminders);
    }
    
    if (habits != null && habits.isNotEmpty) {
      results['habits'] = await syncHabits(habits);
    }
    
    return results;
  }
}
