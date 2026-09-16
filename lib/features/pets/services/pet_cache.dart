import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_client.dart';
import '../../../utils/cache_helper.dart';

/// 宠物模块本地缓存层（stale-while-revalidate，与 RequestCache 同策略）
///
/// RequestCache 仅支持 List 形态，而 rpc_pet_summary / pet_config 总开关
/// 均为单对象响应，故此处提供 Map 形态的 SWR 读取：
/// - 有未过期缓存 → 秒开 + 后台静默刷新（不阻塞渲染）
/// - 无缓存/已过期 → 等待网络结果
/// - 写操作后调用 [invalidate] 保证强一致（B4 起各写 RPC 接入）
class PetCache {
  /// 宠物总览缓存键（含用户数据，切号须清除——已加入 CacheHelper.clearAllUserData）
  static const String keySummary = 'cache_pet_summary';

  /// 总开关缓存键（全局配置性质，非用户数据，切号不清除——同 keyGames 策略）
  static const String keyGate = 'cache_pet_gate';

  /// 默认新鲜度窗口：30s 内直接用本地缓存（与 RequestCache.defaultTtl 一致）
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
      // 缓存时间戳写失败不影响主流程
    }
  }

  /// 从 ApiResponse 提取单对象 Map：
  /// - RPC 单对象 / 标量响应 → 承载于 raw；
  /// - 表查询（PostgREST 数组响应，如 pet_config limit=1）→ 数据在 data 列表，
  ///   取首元素。此前仅认 raw，导致表查询门控永远拿到 null（isPetEnabled 恒 false）。
  static Map<String, dynamic>? _extractMap(ApiResponse resp) {
    final raw = resp.raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final data = resp.data;
    if (data != null && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first);
    }
    return null;
  }

  /// 带缓存的 Map 读取。
  ///
  /// 返回 `(data, cached)`：cached=true 表示本次直接用了本地缓存（后台已在刷新）。
  /// [fetcher] 返回 [ApiResponse]，成功时经 [_extractMap] 取单对象缓存。
  static Future<(Map<String, dynamic>?, bool)> getMap(
    String key,
    Future<ApiResponse> Function() fetcher, {
    Duration ttl = defaultTtl,
    bool forceRefresh = false,
  }) async {
    Map<String, dynamic>? memory;
    if (!forceRefresh) {
      final cached = await CacheHelper.instance.loadMap(key);
      if (cached != null && cached.isNotEmpty) {
        final ts = await _readTs(key);
        if (ts == null || DateTime.now().difference(ts) < ttl) {
          memory = cached;
        }
      }
    }

    final refresh = fetcher().then((resp) async {
      final map = resp.isSuccess ? _extractMap(resp) : null;
      if (map != null) {
        await CacheHelper.instance.saveMap(key, map);
        await _writeTs(key);
      }
      return resp;
    });

    // 有缓存：先秒开，后台静默刷新
    if (memory != null) {
      unawaited(refresh);
      return (memory, true);
    }

    // 无缓存：必须等网络
    final resp = await refresh;
    return (resp.isSuccess ? _extractMap(resp) : null, false);
  }

  /// 失效单个缓存键（数据 + 时间戳）
  static Future<void> invalidate(String key) async {
    await CacheHelper.instance.clear(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tsKey(key));
    } catch (_) {
      // 忽略
    }
  }
}
