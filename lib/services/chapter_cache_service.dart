import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 缓存条目
class _CacheEntry {
  final String chapterId;
  final String novelId;
  final String title;
  final int chapterOrder;
  final int contentLength;
  final DateTime cachedAt;

  _CacheEntry({
    required this.chapterId,
    required this.novelId,
    required this.title,
    required this.chapterOrder,
    required this.contentLength,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'chapter_id': chapterId,
    'novel_id': novelId,
    'title': title,
    'chapter_order': chapterOrder,
    'content_length': contentLength,
    'cached_at': cachedAt.toIso8601String(),
  };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
    chapterId: json['chapter_id'] as String,
    novelId: json['novel_id'] as String,
    title: json['title'] as String,
    chapterOrder: json['chapter_order'] as int,
    contentLength: json['content_length'] as int,
    cachedAt: DateTime.parse(json['cached_at'] as String),
  );
}

/// 章节缓存服务
/// 将小说章节内容缓存到本地文件，支持离线阅读
class ChapterCacheService {
  ChapterCacheService._();
  static final ChapterCacheService instance = ChapterCacheService._();

  static const String _cacheIndexKey = 'chapter_cache_index';
  Map<String, _CacheEntry>? _index;

  /// 初始化缓存索引
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final indexJson = prefs.getString(_cacheIndexKey);
    if (indexJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(indexJson);
        _index = decoded.map((k, v) => MapEntry(k, _CacheEntry.fromJson(v as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('❌ 加载缓存索引失败: $e');
        _index = {};
      }
    } else {
      _index = {};
    }
    debugPrint('✅ 缓存服务初始化完成，已缓存 ${_index!.length} 个章节');
  }

  /// 获取缓存目录
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/chapter_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 生成缓存文件名
  String _cacheFileName(String chapterId) => 'chapter_${chapterId.replaceAll('-', '')}.txt';

  /// 缓存章节内容
  Future<void> cacheChapter({
    required String chapterId,
    required String novelId,
    required String title,
    required int chapterOrder,
    required String content,
  }) async {
    try {
      final dir = await _cacheDir;
      final file = File('${dir.path}/${_cacheFileName(chapterId)}');
      await file.writeAsString(content);

      // 更新索引
      _index ??= {};
      _index![chapterId] = _CacheEntry(
        chapterId: chapterId,
        novelId: novelId,
        title: title,
        chapterOrder: chapterOrder,
        contentLength: content.length,
        cachedAt: DateTime.now(),
      );
      await _saveIndex();

      debugPrint('💾 缓存章节: $title (${content.length}字)');
    } catch (e) {
      debugPrint('❌ 缓存章节失败: $e');
    }
  }

  /// 获取缓存的章节内容
  Future<String?> getCachedContent(String chapterId) async {
    try {
      final dir = await _cacheDir;
      final file = File('${dir.path}/${_cacheFileName(chapterId)}');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('❌ 读取缓存失败: $e');
    }
    return null;
  }

  /// 检查章节是否已缓存
  bool isCached(String chapterId) {
    return _index?.containsKey(chapterId) ?? false;
  }

  /// 获取某本小说的已缓存章节列表
  List<_CacheEntry> getCachedChapters(String novelId) {
    if (_index == null) return [];
    return _index!.values
        .where((entry) => entry.novelId == novelId)
        .toList()
      ..sort((a, b) => a.chapterOrder.compareTo(b.chapterOrder));
  }

  /// 获取某本小说的缓存章节数
  int getCachedCount(String novelId) {
    return getCachedChapters(novelId).length;
  }

  /// 获取某本小说的总缓存大小（字节数）
  int getCacheSize(String novelId) {
    return getCachedChapters(novelId).fold(0, (sum, entry) => sum + entry.contentLength);
  }

  /// 获取全部缓存大小（字节数）
  int getTotalCacheSize() {
    return _index?.values.fold(0, (sum, entry) => sum + entry.contentLength) ?? 0;
  }

  /// 格式化缓存大小
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 删除某本小说的所有缓存
  Future<int> clearNovelCache(String novelId) async {
    final chapters = getCachedChapters(novelId);
    int count = 0;
    for (final chapter in chapters) {
      try {
        final dir = await _cacheDir;
        final file = File('${dir.path}/${_cacheFileName(chapter.chapterId)}');
        if (await file.exists()) {
          await file.delete();
          count++;
        }
        _index!.remove(chapter.chapterId);
      } catch (e) {
        debugPrint('❌ 删除缓存失败: $e');
      }
    }
    await _saveIndex();
    debugPrint('🗑️ 清除小说缓存: $count 个章节');
    return count;
  }

  /// 清除所有缓存
  Future<int> clearAllCache() async {
    int count = 0;
    try {
      final dir = await _cacheDir;
      if (await dir.exists()) {
        final files = dir.listSync();
        for (final file in files) {
          if (file is File) {
            await file.delete();
            count++;
          }
        }
      }
      _index?.clear();
      await _saveIndex();
      debugPrint('🗑️ 清除所有缓存: $count 个文件');
    } catch (e) {
      debugPrint('❌ 清除缓存失败: $e');
    }
    return count;
  }

  /// 保存索引到 SharedPreferences
  Future<void> _saveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final indexJson = jsonEncode(_index?.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_cacheIndexKey, indexJson);
  }
}
