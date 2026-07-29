import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ETag 缓存条目（从 http_client 抽取，持久化于 SharedPreferences）
class ETagEntry {
  final String etag;
  final String body;
  final DateTime cachedAt;

  ETagEntry({required this.etag, required this.body, required this.cachedAt});

  Map<String, dynamic> toJson() => {
        'etag': etag,
        'body': body,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory ETagEntry.fromJson(Map<String, dynamic> json) {
    return ETagEntry(
      etag: json['etag'] as String,
      body: json['body'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }
}

/// ETag/304 缓存容器（封装原 http_client 的内存缓存 + 持久化逻辑，行为一致）
class EtagCache {
  final Map<String, ETagEntry> _cache = {};
  bool _loaded = false;
  static const String _prefsKey = 'http_etag_cache_v1';

  /// 加载持久化的 ETag 缓存（仅首次调用真正读取，之后直接返回）
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        _cache.clear();
        for (final entry in decoded.entries) {
          try {
            final cacheEntry = ETagEntry.fromJson(Map<String, dynamic>.from(entry.value));
            // 只加载30天内的缓存
            if (DateTime.now().difference(cacheEntry.cachedAt) <
                const Duration(days: 30)) {
              _cache[entry.key] = cacheEntry;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 加载 ETag 缓存失败: $e');
    }
    _loaded = true;
  }

  /// 保存 ETag 缓存到磁盘
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> encoded = _cache.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_prefsKey, jsonEncode(encoded));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 保存 ETag 缓存失败: $e');
    }
  }

  /// 清空 ETag 缓存（内存 + 持久化）
  Future<void> clear() async {
    _cache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 清空 ETag 缓存失败: $e');
    }
  }

  ETagEntry? get(String url) => _cache[url];
  bool contains(String url) => _cache.containsKey(url);
  void remove(String url) => _cache.remove(url);
  void store(String url, String etag, String body) {
    _cache[url] = ETagEntry(etag: etag, body: body, cachedAt: DateTime.now());
  }
}
