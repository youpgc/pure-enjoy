import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 纪念日列表缓存辅助（SharedPreferences，非 CacheHelper）。
/// 从 [AnniversariesScreen] 抽离（治理 §1.5.5 膨胀防御）。
/// 行为与原内联实现逐字节等价。

/// 加载缓存列表（按自定义 key 隔离 anniversary/birthday）。
Future<List<dynamic>> loadAnniversaryCache(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final decoded = jsonDecode(jsonStr);
    if (decoded is List) return decoded;
    return [];
  } catch (e) {
    if (kDebugMode) {
      debugPrint('错误');
    }
    return [];
  }
}

/// 保存缓存列表（仅当 refresh 时由调用方触发）。
Future<void> saveAnniversaryCache(String key, List<dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  } catch (e) {
    if (kDebugMode) {
      debugPrint('错误');
    }
  }
}

/// 保存时日期强制当天 12:00（农历项经转换后存公历）。
DateTime normalizeAnniversaryDate(DateTime date) =>
    DateTime(date.year, date.month, date.day, 12);
