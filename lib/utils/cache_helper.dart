import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地缓存辅助类 - 用于数据无感加载
class CacheHelper {
  static final CacheHelper _instance = CacheHelper._internal();
  factory CacheHelper() => _instance;
  CacheHelper._internal();

  static CacheHelper get instance => _instance;

  /// 缓存键名常量
  static const String keyBookshelf = 'cache_bookshelf';
  static const String keyNovelList = 'cache_novel_list';
  static const String keyDiaries = 'cache_diaries';
  static const String keyExpenses = 'cache_expenses';
  static const String keyWeightRecords = 'cache_weight_records';
  static const String keyNotes = 'cache_notes';
  static const String keyFavorites = 'cache_favorites';
  static const String keyReminders = 'cache_reminders';
  static const String keyHabits = 'cache_habits';

  /// 保存 JSON 列表缓存
  Future<void> saveList(String key, List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  /// 读取 JSON 列表缓存
  Future<List<dynamic>> loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 保存单个对象缓存
  Future<void> saveMap(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  /// 读取单个对象缓存
  Future<Map<String, dynamic>?> loadMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 清除指定缓存
  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
