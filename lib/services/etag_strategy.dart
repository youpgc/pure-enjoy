import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import './etag_cache.dart';

/// ETag 缓存辅助：304 命中构造 + 200 写入。
/// 从 [HttpClient.get] 抽离（治理 §1.5.5 膨胀防御），
/// 配合 [requestWithRetry] 实现「单请求」ETag 流程（修复原实现在 200 时重复发请求的冗余）。
/// 行为与原内联实现逐字节等价（含 📦 日志、X-Cache: HIT 头）。

/// 构造 304 缓存命中的响应（状态码伪 200 + X-Cache: HIT）。
http.Response cachedResponseFromEtag(String path, ETagEntry cached) {
  if (kDebugMode) debugPrint('📦 ETag 304 缓存命中: $path');
  return http.Response(
    cached.body,
    200,
    headers: {'X-Cache': 'HIT'},
  );
}

/// 若响应为 200 且含 etag，写入缓存（持久化异步，不阻塞主流程）。
void storeEtagIfPresent(EtagCache cache, String url, http.Response response) {
  final etag = response.headers['etag'];
  if (etag != null && etag.isNotEmpty) {
    cache.store(url, etag, response.body);
    unawaited(cache.save());
  }
}
