import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 缓存条目
class CacheEntry {
  final String chapterId;
  final String novelId;
  final String title;
  final int chapterOrder;
  final int contentLength;
  final DateTime cachedAt;

  CacheEntry({
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

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    chapterId: json['chapter_id']?.toString() ?? '',
    novelId: json['novel_id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    chapterOrder: json['chapter_order'] is int ? json['chapter_order'] as int : int.tryParse(json['chapter_order']?.toString() ?? '0') ?? 0,
    contentLength: json['content_length'] is int ? json['content_length'] as int : int.tryParse(json['content_length']?.toString() ?? '0') ?? 0,
    cachedAt: DateTime.tryParse(json['cached_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

/// ============================================================
/// 章节三级缓存服务（L1 内存 + L2 磁盘 + L3 网络）
///
/// 优化策略：
/// - L1 内存：LinkedHashMap LRU，容量 50MB，O(1) 访问
/// - L2 磁盘：文件系统缓存，容量 200MB，SharedPreferences 索引
/// - L3 网络：ApiClient 请求，GZIP 压缩
/// - 预加载：阅读进度 ≥70% 时触发，WiFi 预加载 5 章 / 蜂窝 2 章
/// - 去重：Completer Map 防止并发重复加载
/// - 内存保护：didHaveMemoryPressure 时清空 L1（保留当前页）
/// ============================================================
class ChapterCacheService extends WidgetsBindingObserver {
  ChapterCacheService._();
  static final ChapterCacheService instance = ChapterCacheService._();

  // ==================== L2 磁盘缓存（原有）====================
  static const String _cacheIndexKey = 'chapter_cache_index';
  Map<String, CacheEntry>? _diskIndex;

  // ==================== L1 内存缓存（新增）====================
  /// LRU 内存缓存：LinkedHashMap，最近访问的移到末尾
  /// key: chapterId, value: 章节内容
  final Map<String, String> _memoryCache = {};

  /// L1 容量上限：50MB（按字符数估算，UTF-8 中文约 3 字节/字符）
  static const int _maxMemoryCacheBytes = 50 * 1024 * 1024;
  int _currentMemoryCacheBytes = 0;

  /// 当前正在显示的章节 ID，内存压力时保护不清除
  String? _protectedChapterId;

  // ==================== 去重与预加载（新增）====================
  /// 正在进行的加载操作：key=chapterId，value=Completer
  /// 防止并发请求同一章节时重复发起网络调用
  final Map<String, Completer<String?>> _loadingCompleters = {};

  /// 预加载队列：待预加载的章节 ID 列表
  final List<String> _preloadQueue = [];

  /// 是否正在执行预加载
  bool _isPreloading = false;

  /// WiFi 环境下预加载章节数
  static const int _preloadCountWifi = 5;

  /// 蜂窝网络下预加载章节数
  static const int _preloadCountCellular = 2;

  // ==================== 初始化 ====================

  /// 初始化缓存服务（在 App 启动时调用）
  Future<void> initialize() async {
    // 注册 WidgetsBindingObserver 监听内存压力
    WidgetsBinding.instance.addObserver(this);

    // 加载磁盘缓存索引
    final prefs = await SharedPreferences.getInstance();
    final indexJson = prefs.getString(_cacheIndexKey);
    if (indexJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(indexJson);
        _diskIndex = decoded.map((k, v) => MapEntry(k, CacheEntry.fromJson(v as Map<String, dynamic>)));
      } catch (e) {
        if (kDebugMode) debugPrint('❌ 加载缓存索引失败: $e');
        _diskIndex = {};
      }
    } else {
      _diskIndex = {};
    }
    if (kDebugMode) debugPrint('✅ 章节缓存服务初始化完成（L1内存 + L2磁盘）');
  }

  /// 设置当前保护的章节 ID（内存压力时不清理）
  void setProtectedChapter(String? chapterId) {
    _protectedChapterId = chapterId;
  }

  // ==================== L1 内存缓存操作 ====================

  /// 将章节内容放入 L1 内存缓存（LRU 淘汰）
  void _putMemoryCache(String chapterId, String content) {
    // 已存在则先移除（更新访问顺序）
    if (_memoryCache.containsKey(chapterId)) {
      _currentMemoryCacheBytes -= _memoryCache[chapterId]!.length * 3; // UTF-8 估算
      _memoryCache.remove(chapterId);
    }

    final contentBytes = content.length * 3;

    // 容量不足时淘汰最久未访问的
    while (_currentMemoryCacheBytes + contentBytes > _maxMemoryCacheBytes && _memoryCache.isNotEmpty) {
      final oldestKey = _memoryCache.keys.first;
      // 保护当前页不被淘汰
      if (oldestKey == _protectedChapterId) {
        // 如果 oldest 就是保护的页，尝试淘汰第二个
        if (_memoryCache.length > 1) {
          final secondKey = _memoryCache.keys.skip(1).first;
          _currentMemoryCacheBytes -= _memoryCache[secondKey]!.length * 3;
          _memoryCache.remove(secondKey);
        } else {
          break; // 只有保护的页，不淘汰
        }
      } else {
        _currentMemoryCacheBytes -= _memoryCache[oldestKey]!.length * 3;
        _memoryCache.remove(oldestKey);
      }
    }

    _memoryCache[chapterId] = content;
    _currentMemoryCacheBytes += contentBytes;
  }

  /// 从 L1 内存缓存读取
  String? _getMemoryCache(String chapterId) {
    final content = _memoryCache[chapterId];
    if (content != null) {
      // LRU：移除并重新插入，移到末尾（最新）
      _memoryCache.remove(chapterId);
      _memoryCache[chapterId] = content;
    }
    return content;
  }

  /// 清空 L1 内存缓存（保留当前保护页）
  void _clearMemoryCache() {
    if (_protectedChapterId != null && _memoryCache.containsKey(_protectedChapterId!)) {
      final protectedContent = _memoryCache[_protectedChapterId!];
      _memoryCache.clear();
      if (protectedContent != null) {
        _memoryCache[_protectedChapterId!] = protectedContent;
        _currentMemoryCacheBytes = protectedContent.length * 3;
      } else {
        _currentMemoryCacheBytes = 0;
      }
    } else {
      _memoryCache.clear();
      _currentMemoryCacheBytes = 0;
    }
    if (kDebugMode) debugPrint('🧹 L1 内存缓存已清空（保留保护页: $_protectedChapterId）');
  }

  // ==================== 内存压力监听 ====================

  @override
  void didHaveMemoryPressure() {
    if (kDebugMode) debugPrint('⚠️ 收到内存压力警告，清理 L1 缓存');
    _clearMemoryCache();
  }

  /// 销毁时移除观察者
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  // ==================== L2 磁盘缓存（按小说分目录）====================

  /// 获取应用级缓存根目录
  Future<Directory> get _cacheRootDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/chapter_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 获取指定小说的缓存目录
  Future<Directory> _cacheDir(String novelId) async {
    final root = await _cacheRootDir;
    final novelDir = Directory('${root.path}/$novelId');
    if (!await novelDir.exists()) {
      await novelDir.create(recursive: true);
    }
    return novelDir;
  }

  String _cacheFileName(String chapterId) => '${chapterId.replaceAll('-', '')}.txt';

  /// 缓存章节内容（L1 + L2 同时写入）
  Future<void> cacheChapter({
    required String chapterId,
    required String novelId,
    required String title,
    required int chapterOrder,
    required String content,
  }) async {
    // 1. 写入 L1 内存缓存
    _putMemoryCache(chapterId, content);

    // 2. 写入 L2 磁盘缓存（异步，不阻塞）
    unawaited(_writeDiskCache(chapterId, novelId, title, chapterOrder, content));
  }

  Future<void> _writeDiskCache(
    String chapterId,
    String novelId,
    String title,
    int chapterOrder,
    String content,
  ) async {
    try {
      final dir = await _cacheDir(novelId);
      final file = File('${dir.path}/${_cacheFileName(chapterId)}');
      await file.writeAsString(content);

      _diskIndex ??= {};
      _diskIndex![chapterId] = CacheEntry(
        chapterId: chapterId,
        novelId: novelId,
        title: title,
        chapterOrder: chapterOrder,
        contentLength: content.length,
        cachedAt: DateTime.now(),
      );
      await _saveIndex();

      if (kDebugMode) debugPrint('💾 L2 磁盘缓存已保存: $title');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ L2 磁盘缓存写入失败: $e');
    }
  }

  /// 三级缓存读取：L1 → L2 → null
  /// 返回缓存内容（如有），不发起网络请求
  Future<String?> getCachedContent(String chapterId) async {
    // 1. L1 内存缓存（最快）
    final memContent = _getMemoryCache(chapterId);
    if (memContent != null) {
      if (kDebugMode) debugPrint('⚡ L1 内存缓存命中: $chapterId');
      return memContent;
    }

    // 2. L2 磁盘缓存（需从索引中获取 novelId 定位目录）
    try {
      final novelId = _diskIndex?[chapterId]?.novelId;
      if (novelId == null) return null;

      final dir = await _cacheDir(novelId);
      final file = File('${dir.path}/${_cacheFileName(chapterId)}');
      if (await file.exists()) {
        final content = await file.readAsString();
        // 回填 L1 内存缓存
        _putMemoryCache(chapterId, content);
        if (kDebugMode) debugPrint('💿 L2 磁盘缓存命中: $chapterId');
        return content;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ L2 磁盘缓存读取失败: $e');
    }

    return null;
  }

  /// 检查缓存是否在 TTL 有效期内
  /// 返回 true 表示缓存仍新鲜，可跳过网络请求
  static const Duration _cacheTtl = Duration(days: 30);
  bool isCacheFresh(String chapterId) {
    if (_diskIndex == null || !_diskIndex!.containsKey(chapterId)) return false;
    final entry = _diskIndex![chapterId]!;
    return DateTime.now().difference(entry.cachedAt) < _cacheTtl;
  }

  /// 智能加载：三级缓存 + 去重 + 网络回源
  /// 返回 [cachedContent, networkFuture] 元组，允许先展示缓存再等待网络
  Future<String?> fetchWithDeduplication(
    String chapterId,
    Future<String?> networkFetcher,
  ) async {
    // 1. 检查 L1/L2 缓存
    final cached = await getCachedContent(chapterId);
    if (cached != null) return cached;

    // 2. 检查是否已有正在进行的加载（去重）
    if (_loadingCompleters.containsKey(chapterId)) {
      if (kDebugMode) debugPrint('🔄 复用正在进行的加载: $chapterId');
      return _loadingCompleters[chapterId]!.future;
    }

    // 3. 发起新的网络请求
    final completer = Completer<String?>();
    _loadingCompleters[chapterId] = completer;

    try {
      final content = await networkFetcher;
      completer.complete(content);
      return content;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loadingCompleters.remove(chapterId);
    }
  }

  // ==================== 预加载队列（新增）====================

  /// 触发预加载：根据网络环境决定预加载数量
  /// [chapterIds]: 待预加载的章节 ID 列表（按阅读顺序）
  /// [fetcher]: 获取章节内容的回调函数
  void triggerPreload({
    required List<String> chapterIds,
    required Future<String?> Function(String chapterId) fetcher,
  }) {
    if (chapterIds.isEmpty) return;

    // 清空旧队列，加入新队列
    _preloadQueue.clear();
    _preloadQueue.addAll(chapterIds);

    if (!_isPreloading) {
      _processPreloadQueue(fetcher);
    }
  }

  Future<void> _processPreloadQueue(
    Future<String?> Function(String chapterId) fetcher,
  ) async {
    _isPreloading = true;

    // 检测网络类型
    int preloadCount;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.wifi) {
        preloadCount = _preloadCountWifi;
      } else {
        preloadCount = _preloadCountCellular;
      }
    } catch (_) {
      preloadCount = _preloadCountCellular;
    }

    int processed = 0;
    while (_preloadQueue.isNotEmpty && processed < preloadCount) {
      final chapterId = _preloadQueue.removeAt(0);

      // 跳过已缓存的
      if (_memoryCache.containsKey(chapterId) || (_diskIndex?.containsKey(chapterId) ?? false)) {
        continue;
      }

      // fire-and-forget 预加载（吞没错误）
      unawaited(
        fetcher(chapterId).then((content) {
          if (content != null && content.isNotEmpty) {
            _putMemoryCache(chapterId, content);
          }
        }).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ 预加载失败(已忽略): $chapterId');
        }),
      );

      processed++;
    }

    _preloadQueue.clear();
    _isPreloading = false;

    if (kDebugMode && processed > 0) {
      debugPrint('🚀 已触发预加载 $processed 章');
    }
  }

  // ==================== 原有方法（保持不变）====================

  bool isCached(String chapterId) {
    return _memoryCache.containsKey(chapterId) || (_diskIndex?.containsKey(chapterId) ?? false);
  }

  List<CacheEntry> getCachedChapters(String novelId) {
    if (_diskIndex == null) return [];
    return _diskIndex!.values
        .where((entry) => entry.novelId == novelId)
        .toList()
      ..sort((a, b) => a.chapterOrder.compareTo(b.chapterOrder));
  }

  int getCachedCount(String novelId) => getCachedChapters(novelId).length;

  int getCacheSize(String novelId) {
    return getCachedChapters(novelId).fold<int>(0, (sum, entry) => sum + entry.contentLength);
  }

  int getTotalCacheSize() {
    return _diskIndex?.values.fold<int>(0, (sum, entry) => sum + entry.contentLength) ?? 0;
  }

  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 清理指定小说的所有缓存（L1 + L2 一起清理）
  Future<int> clearNovelCache(String novelId) async {
    final chapters = getCachedChapters(novelId);
    if (chapters.isEmpty) return 0;

    // 1. 清理 L1 内存缓存
    for (final chapter in chapters) {
      _memoryCache.remove(chapter.chapterId);
    }
    _recalculateMemoryBytes();

    // 2. 清理 L2 磁盘缓存（直接删除小说目录）
    int count = 0;
    try {
      final root = await _cacheRootDir;
      final novelDir = Directory('${root.path}/$novelId');
      if (await novelDir.exists()) {
        final files = novelDir.listSync();
        await novelDir.delete(recursive: true);
        count = files.whereType<File>().length;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 删除小说缓存目录失败: $e');
    }

    // 3. 更新索引
    for (final chapter in chapters) {
      _diskIndex?.remove(chapter.chapterId);
    }
    await _saveIndex();

    if (kDebugMode) debugPrint('🗑️ 清除小说缓存 $count 章');
    return count;
  }

  /// 清理所有缓存
  Future<int> clearAllCache() async {
    int count = 0;
    try {
      final root = await _cacheRootDir;
      if (await root.exists()) {
        final items = root.listSync();
        for (final item in items) {
          if (item is Directory) {
            final files = item.listSync();
            await item.delete(recursive: true);
            count += files.whereType<File>().length;
          }
        }
      }
      _memoryCache.clear();
      _currentMemoryCacheBytes = 0;
      _diskIndex?.clear();
      await _saveIndex();
      if (kDebugMode) debugPrint('🗑️ 清除所有缓存');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 清除缓存失败: $e');
    }
    return count;
  }

  Future<void> _saveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final indexJson = jsonEncode(_diskIndex?.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_cacheIndexKey, indexJson);
  }

  void _recalculateMemoryBytes() {
    _currentMemoryCacheBytes = _memoryCache.values.fold<int>(
      0, (sum, content) => sum + content.length * 3,
    );
  }
}
