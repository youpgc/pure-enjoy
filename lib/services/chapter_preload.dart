import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 章节预加载管理器（从 ChapterCacheService 抽出，组合式复用）
///
/// 持有预加载队列与进行中状态，行为与原 `_processPreloadQueue` 逐字节一致：
/// - 网络类型决定预加载数量（WiFi 5 / 蜂窝 2）
/// - 已缓存章节跳过且不计入 processed 上限
/// - fire-and-forget 预加载，错误吞没
/// - 完成后清空队列并复位 _isPreloading
class ChapterPreloadManager {
  final List<String> _queue = [];
  bool _isPreloading = false;

  /// WiFi 环境下预加载章节数
  static const int _preloadCountWifi = 5;

  /// 蜂窝网络下预加载章节数
  static const int _preloadCountCellular = 2;

  bool get isPreloading => _isPreloading;

  /// 清空旧队列，加入新队列
  void enqueue(List<String> chapterIds) {
    _queue.clear();
    _queue.addAll(chapterIds);
  }

  /// 执行预加载（异步，不等待）
  ///
  /// [fetcher] 获取章节内容；[isCached] 判断章节是否已缓存（跳过）；
  /// [onCache] 预加载成功后回写 L1 内存缓存。
  Future<void> run({
    required Future<String?> Function(String) fetcher,
    required bool Function(String) isCached,
    required void Function(String, String) onCache,
  }) async {
    _isPreloading = true;

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
    while (_queue.isNotEmpty && processed < preloadCount) {
      final chapterId = _queue.removeAt(0);
      if (isCached(chapterId)) {
        continue;
      }

      unawaited(
        fetcher(chapterId).then((content) {
          if (content != null && content.isNotEmpty) {
            onCache(chapterId, content);
          }
        }).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ 预加载失败(已忽略): $chapterId');
        }),
      );

      processed++;
    }

    _queue.clear();
    _isPreloading = false;

    if (kDebugMode && processed > 0) {
      debugPrint('🚀 已触发预加载 $processed 章');
    }
  }
}
