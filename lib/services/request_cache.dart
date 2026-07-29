import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/cache_helper.dart';
import './api_client.dart';

/// 请求缓存层（stale-while-revalidate）
///
/// 针对读多写少、可短暂陈旧的数据（首页聚合、列表）做本地缓存：
/// - 有未过期缓存时**先返回缓存秒开 UI**，后台静默刷新并回写（不阻塞渲染）
/// - 无缓存/已过期时等待网络结果
/// - 写操作后调用 [invalidate] / [invalidateAll] 使对应缓存失效，保证强一致
///
/// 合规说明：仅缓存业务元数据（小说/记录等 JSON），聚合书不存正文，符合合规红线。
class RequestCache {
  /// 默认缓存新鲜度窗口：30s 内视为新鲜，直接使用本地缓存
  static const Duration defaultTtl = Duration(seconds: 30);

  static String _tsKey(String key) => '${key}__ts';

  static Future<DateTime?> _readTs(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_tsKey(key));
      return v == null ? null : DateTime.tryParse(v);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeTs(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tsKey(key), DateTime.now().toIso8601String());
    } catch (_) {
      if (kDebugMode) debugPrint('❌ 写入缓存时间戳失败: $key');
    }
  }

  /// 带缓存的列表读取。
  ///
  /// 返回元组 `(data, cached)`：
  /// - `cached == true`：本次直接用了本地缓存，未等待网络（后台已在刷新）
  /// - `cached == false`：等待了网络结果（无缓存或已过期）
  ///
  /// [fetcher] 返回 [ApiResponse]，成功时将其 `data` 缓存。
  static Future<(List<Map<String, dynamic>> data, bool cached)> getList(
    String key,
    Future<ApiResponse> Function() fetcher, {
    Duration ttl = defaultTtl,
    bool forceRefresh = false,
  }) async {
    List<Map<String, dynamic>>? memory;
    if (!forceRefresh) {
      final list = await CacheHelper.instance.loadList(key);
      if (list.isNotEmpty) {
        final ts = await _readTs(key);
        if (ts == null || DateTime.now().difference(ts) < ttl) {
          memory = list.cast<Map<String, dynamic>>();
        }
      }
    }

    final refresh = fetcher().then((resp) async {
      if (resp.isSuccess && resp.data != null && resp.data!.isNotEmpty) {
        await CacheHelper.instance.saveList(key, resp.data!);
        await _writeTs(key);
      }
      return resp;
    });

    // 有缓存：先秒开，后台静默刷新（不 await）
    if (memory != null) {
      unawaited(refresh);
      return (memory, true);
    }

    // 无缓存：必须等网络
    final resp = await refresh;
    if (resp.isSuccess && resp.data != null) {
      return (resp.data!, false);
    }
    return (<Map<String, dynamic>>[], false);
  }

  /// 失效单个缓存键（清除数据与时间戳）
  static Future<void> invalidate(String key) async {
    await CacheHelper.instance.clear(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tsKey(key));
    } catch (_) {
      // 忽略
    }
  }

  /// 失效多个缓存键
  static Future<void> invalidateAll(List<String> keys) async {
    for (final k in keys) {
      await invalidate(k);
    }
  }
}
