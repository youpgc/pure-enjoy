import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 排版缓存服务
/// 参考微信读书方案，将排版结果（分页数量、每页文本范围）持久化到磁盘
/// 避免每次打开同一章节都重新计算排版，提升翻页帧率
class LayoutCacheService {
  static final LayoutCacheService _instance = LayoutCacheService._internal();
  static LayoutCacheService get instance => _instance;
  LayoutCacheService._internal();

  /// 内存缓存：章节ID -> 排版结果
  final Map<String, LayoutResult> _memoryCache = {};

  /// 磁盘索引键
  static const String _indexKey = 'layout_cache_index_v1';

  /// 磁盘索引：{chapterId: {fontHash, fileName, cachedAt}}
  Map<String, Map<String, dynamic>>? _diskIndex;

  /// 获取排版缓存目录
  Future<Directory> _cacheDir(String novelId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/layout_cache/$novelId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 加载磁盘索引
  Future<void> _loadIndex() async {
    if (_diskIndex != null) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_indexKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        _diskIndex = decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
      } catch (e) {
        _diskIndex = {};
      }
    } else {
      _diskIndex = {};
    }
  }

  /// 保存磁盘索引
  Future<void> _saveIndex() async {
    if (_diskIndex == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(_diskIndex));
  }

  // ==================== 核心接口 ====================

  /// 获取排版结果
  /// [chapterId] 章节ID
  /// [fontStyleHash] 字体样式哈希（字体大小、行高、屏幕宽度等影响排版的参数）
  /// 返回 null 表示无缓存或样式不匹配
  Future<LayoutResult?> getLayout({
    required String chapterId,
    required String novelId,
    required String fontStyleHash,
  }) async {
    // 1. 检查内存缓存
    final mem = _memoryCache[chapterId];
    if (mem != null && mem.fontStyleHash == fontStyleHash) {
      return mem;
    }

    // 2. 检查磁盘缓存
    await _loadIndex();
    final entry = _diskIndex?[chapterId];
    if (entry == null) return null;

    // 字体样式不匹配：排版参数变化，缓存失效
    if (entry['fontHash'] != fontStyleHash) return null;

    try {
      final dir = await _cacheDir(novelId);
      final fileName = entry['fileName'] as String?;
      if (fileName == null) return null;

      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) {
        _diskIndex?.remove(chapterId);
        await _saveIndex();
        return null;
      }

      final content = await file.readAsString();
      final result = LayoutResult.fromJson(jsonDecode(content));

      // 回填内存缓存
      _memoryCache[chapterId] = result;
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 读取排版缓存失败: $chapterId');
      return null;
    }
  }

  /// 保存排版结果
  Future<void> saveLayout({
    required String chapterId,
    required String novelId,
    required String fontStyleHash,
    required LayoutResult layout,
  }) async {
    // 1. 写入内存缓存
    _memoryCache[chapterId] = layout;

    // 2. 写入磁盘缓存（异步）
    unawaited(_writeDiskCache(chapterId, novelId, fontStyleHash, layout));
  }

  Future<void> _writeDiskCache(
    String chapterId,
    String novelId,
    String fontStyleHash,
    LayoutResult layout,
  ) async {
    try {
      final dir = await _cacheDir(novelId);
      final fileName = '${chapterId.replaceAll('-', '')}.layout';
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(jsonEncode(layout.toJson()));

      await _loadIndex();
      _diskIndex![chapterId] = {
        'fontHash': fontStyleHash,
        'fileName': fileName,
        'cachedAt': DateTime.now().toIso8601String(),
        'novelId': novelId,
      };
      await _saveIndex();

      if (kDebugMode) debugPrint('💾 排版缓存已保存: $chapterId (${layout.totalPages}页)');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 排版缓存写入失败: $e');
    }
  }

  /// 清理指定小说的排版缓存
  Future<void> clearNovelCache(String novelId) async {
    _memoryCache.removeWhere((k, v) => v.novelId == novelId);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/layout_cache/$novelId');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 清理排版缓存目录失败: $e');
    }

    await _loadIndex();
    _diskIndex?.removeWhere((k, v) => v['novelId'] == novelId);
    await _saveIndex();
  }

  /// 清理所有排版缓存
  Future<void> clearAllCache() async {
    _memoryCache.clear();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/layout_cache');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 清理排版缓存失败: $e');
    }

    _diskIndex?.clear();
    await _saveIndex();
  }
}

// ==================== 数据模型 ====================

/// 排版结果
class LayoutResult {
  /// 总页数
  final int totalPages;

  /// 每页文本范围 [startOffset, endOffset]
  final List<PageRange> pageRanges;

  /// 字体样式哈希（用于缓存失效判断）
  final String fontStyleHash;

  /// 所属小说ID
  final String novelId;

  /// 章节ID
  final String chapterId;

  /// 排版时间
  final DateTime layoutAt;

  const LayoutResult({
    required this.totalPages,
    required this.pageRanges,
    required this.fontStyleHash,
    required this.novelId,
    required this.chapterId,
    required this.layoutAt,
  });

  factory LayoutResult.fromJson(Map<String, dynamic> json) {
    return LayoutResult(
      totalPages: json['totalPages'] as int,
      pageRanges: (json['pageRanges'] as List)
          .map((e) => PageRange.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      fontStyleHash: json['fontStyleHash'] as String,
      novelId: json['novelId'] as String,
      chapterId: json['chapterId'] as String,
      layoutAt: DateTime.parse(json['layoutAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPages': totalPages,
        'pageRanges': pageRanges.map((e) => e.toJson()).toList(),
        'fontStyleHash': fontStyleHash,
        'novelId': novelId,
        'chapterId': chapterId,
        'layoutAt': layoutAt.toIso8601String(),
      };
}

/// 单页文本范围
class PageRange {
  /// 页码索引（0-based）
  final int pageIndex;

  /// 本章内文本起始偏移量
  final int startOffset;

  /// 本章内文本结束偏移量
  final int endOffset;

  const PageRange({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
  });

  factory PageRange.fromJson(Map<String, dynamic> json) {
    return PageRange(
      pageIndex: json['pageIndex'] as int,
      startOffset: json['startOffset'] as int,
      endOffset: json['endOffset'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'pageIndex': pageIndex,
        'startOffset': startOffset,
        'endOffset': endOffset,
      };
}
