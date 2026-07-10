import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/novel/models/novel_model.dart';
import 'api_client.dart';
import 'chapter_cache_service.dart';

/// 离线阅读服务
/// 管理小说的离线下载、下载进度跟踪、无网络阅读支持
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  static OfflineService get instance => _instance;
  OfflineService._internal();

  /// 下载任务状态
  final Map<String, _DownloadTask> _tasks = {};

  /// 下载状态流（供UI监听）
  final _statusController = StreamController<Map<String, DownloadStatus>>.broadcast();
  Stream<Map<String, DownloadStatus>> get statusStream => _statusController.stream;

  static const String _offlineMetaKey = 'offline_novel_meta';
  static const int _downloadBatchSize = 10; // 并行下载批次大小

  // ==================== 下载管理 ====================

  /// 开始下载小说所有章节
  /// [novel] 小说信息
  /// [chapterIds] 需要下载的章节ID列表（可选，默认全部）
  Future<void> startDownload(NovelModel novel, {List<String>? chapterIds}) async {
    final novelId = novel.id;

    // 取消已有任务
    if (_tasks.containsKey(novelId)) {
      await cancelDownload(novelId);
    }

    // 获取章节列表
    final ids = chapterIds ?? await _fetchAllChapterIds(novelId);
    if (ids.isEmpty) return;

    final task = _DownloadTask(
      novelId: novelId,
      novelTitle: novel.title,
      totalChapters: ids.length,
      pendingIds: List.from(ids),
    );
    _tasks[novelId] = task;
    _notifyStatus();

    // 开始下载
    unawaited(_processDownload(task));
  }

  /// 批量下载处理
  Future<void> _processDownload(_DownloadTask task) async {
    try {
      while (task.pendingIds.isNotEmpty && !task.isCancelled) {
        // 取出一批
        final batch = task.pendingIds.take(_downloadBatchSize).toList();
        task.pendingIds.removeWhere((id) => batch.contains(id));

        // 并行下载
        await Future.wait(
          batch.map((chapterId) => _downloadSingleChapter(task, chapterId)),
        );

        if (task.isCancelled) break;
        _notifyStatus();
      }

      // 下载完成：更新元数据
      if (!task.isCancelled) {
        await _saveOfflineMeta(task.novelId, task.completedIds.length);
        if (kDebugMode) debugPrint('✅ 离线下载完成: ${task.novelTitle} (${task.completedIds.length}章)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 离线下载异常: $e');
    } finally {
      _tasks.remove(task.novelId);
      _notifyStatus();
    }
  }

  /// 下载单章内容
  Future<void> _downloadSingleChapter(_DownloadTask task, String chapterId) async {
    try {
      // 检查是否已缓存
      if (ChapterCacheService.instance.isCached(chapterId)) {
        task.completedIds.add(chapterId);
        return;
      }

      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.$chapterId'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final data = result.data!.first;
        final content = (data['content'] as String? ?? '')
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n');

        if (content.isNotEmpty) {
          await ChapterCacheService.instance.cacheChapter(
            chapterId: chapterId,
            novelId: task.novelId,
            title: data['title'] as String? ?? '',
            chapterOrder: data['chapter_num'] as int? ?? 0,
            content: content,
          );
          task.completedIds.add(chapterId);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 章节下载失败: $chapterId');
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String novelId) async {
    _tasks[novelId]?.isCancelled = true;
    _tasks.remove(novelId);
    _notifyStatus();
  }

  /// 删除离线数据
  Future<void> deleteOfflineData(String novelId) async {
    await cancelDownload(novelId);
    await ChapterCacheService.instance.clearNovelCache(novelId);
    await _removeOfflineMeta(novelId);
    _notifyStatus();
  }

  // ==================== 查询状态 ====================

  /// 获取小说下载状态
  DownloadStatus getStatus(String novelId) {
    final task = _tasks[novelId];
    if (task != null) {
      return DownloadStatus(
        novelId: novelId,
        state: task.isCancelled ? DownloadState.cancelled : DownloadState.downloading,
        totalChapters: task.totalChapters,
        downloadedChapters: task.completedIds.length,
        progress: task.totalChapters > 0 ? task.completedIds.length / task.totalChapters : 0,
      );
    }

    // 检查是否已下载
    final meta = _getOfflineMeta(novelId);
    if (meta != null && meta['downloaded'] > 0) {
      return DownloadStatus(
        novelId: novelId,
        state: DownloadState.completed,
        totalChapters: meta['total'] ?? 0,
        downloadedChapters: meta['downloaded'] ?? 0,
        progress: 1.0,
      );
    }

    return DownloadStatus(
      novelId: novelId,
      state: DownloadState.none,
      totalChapters: 0,
      downloadedChapters: 0,
      progress: 0,
    );
  }

  /// 小说是否已离线可用（至少部分章节已下载）
  bool isOfflineAvailable(String novelId) {
    final status = getStatus(novelId);
    return status.state == DownloadState.completed ||
        (status.state == DownloadState.downloading && status.downloadedChapters > 0);
  }

  /// 获取所有已下载小说
  Future<List<Map<String, dynamic>>> getDownloadedNovels() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_offlineMetaKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final Map<String, dynamic> meta = jsonDecode(jsonStr);
      return meta.entries
          .where((e) => (e.value['downloaded'] ?? 0) > 0)
          .map((e) => {
                'novelId': e.key,
                ...e.value,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== 内部辅助 ====================

  Future<List<String>> _fetchAllChapterIds(String novelId) async {
    final result = await ApiClient.get(
      'novel_chapters',
      filters: {'novel_id': 'eq.$novelId'},
      columns: 'id,chapter_num',
      order: 'chapter_num.asc',
      limit: 10000, // 大数获取全部
    );

    if (result.isSuccess && result.data != null) {
      return result.data!
          .map((d) => d['id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  Future<void> _saveOfflineMeta(String novelId, int downloadedCount) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_offlineMetaKey) ?? '{}';
    final Map<String, dynamic> meta = jsonDecode(jsonStr);

    meta[novelId] = {
      'downloaded': downloadedCount,
      'total': meta[novelId]?['total'] ?? downloadedCount,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_offlineMetaKey, jsonEncode(meta));
  }

  Future<void> _removeOfflineMeta(String novelId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_offlineMetaKey) ?? '{}';
    final Map<String, dynamic> meta = jsonDecode(jsonStr);
    meta.remove(novelId);
    await prefs.setString(_offlineMetaKey, jsonEncode(meta));
  }

  Map<String, dynamic>? _getOfflineMeta(String novelId) {
    // 异步读取转为同步（使用上次缓存）
    // 实际调用应使用 getStatus 的异步版本
    return null;
  }

  void _notifyStatus() {
    final statusMap = <String, DownloadStatus>{};
    for (final entry in _tasks.entries) {
      statusMap[entry.key] = getStatus(entry.key);
    }
    _statusController.add(statusMap);
  }
}

// ==================== 数据模型 ====================

enum DownloadState { none, downloading, paused, completed, cancelled, error }

class DownloadStatus {
  final String novelId;
  final DownloadState state;
  final int totalChapters;
  final int downloadedChapters;
  final double progress;

  const DownloadStatus({
    required this.novelId,
    required this.state,
    required this.totalChapters,
    required this.downloadedChapters,
    required this.progress,
  });
}

class _DownloadTask {
  final String novelId;
  final String novelTitle;
  final int totalChapters;
  final List<String> pendingIds;
  final List<String> completedIds = [];
  bool isCancelled = false;

  _DownloadTask({
    required this.novelId,
    required this.novelTitle,
    required this.totalChapters,
    required this.pendingIds,
  });
}
