import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../env.dart';
import 'cancel_token.dart';
import 'supabase_service.dart';

/// 全局 HttpClient 配置（从环境变量读取）
class HttpClientConfig {
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 30);

  static String get baseUrl => Env.get('SUPABASE_URL');

  static String get anonKey => Env.get('SUPABASE_ANON_KEY');
}

/// 请求超时时间预设
class RequestTimeout {
  static const Duration list = Duration(seconds: 30);
  static const Duration simple = Duration(seconds: 15);
  static const Duration file = Duration(seconds: 60);
}

/// ETag 缓存条目
class _ETagEntry {
  final String etag;
  final String body;
  final DateTime cachedAt;

  _ETagEntry({required this.etag, required this.body, required this.cachedAt});

  Map<String, dynamic> toJson() => {
        'etag': etag,
        'body': body,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory _ETagEntry.fromJson(Map<String, dynamic> json) {
    return _ETagEntry(
      etag: json['etag'] as String,
      body: json['body'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }
}

/// 统一的 HTTP 客户端
/// 所有 API 请求都通过此类发送，自动处理认证头、超时、重试、ETag 缓存等
class HttpClient {
  static HttpClient? _instance;

  HttpClient._();

  static HttpClient get instance {
    _instance ??= HttpClient._();
    return _instance!;
  }

  /// 当前 JWT Access Token
  String? _accessToken;

  /// ETag 缓存：URL -> 缓存条目
  final Map<String, _ETagEntry> _etagCache = {};

  /// ETag 缓存是否已加载
  bool _etagLoaded = false;

  static const String _etagPrefsKey = 'http_etag_cache_v1';

  /// 设置 JWT Access Token
  /// 登录成功后调用，后续请求将自动携带 Authorization: Bearer <token>
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// 加载持久化的 ETag 缓存
  Future<void> _loadETagCache() async {
    if (_etagLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_etagPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        _etagCache.clear();
        for (final entry in decoded.entries) {
          try {
            final cacheEntry = _ETagEntry.fromJson(Map<String, dynamic>.from(entry.value));
            // 只加载30天内的缓存
            if (DateTime.now().difference(cacheEntry.cachedAt) < const Duration(days: 30)) {
              _etagCache[entry.key] = cacheEntry;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 加载 ETag 缓存失败: $e');
    }
    _etagLoaded = true;
  }

  /// 保存 ETag 缓存到磁盘
  Future<void> _saveETagCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> encoded = _etagCache.map(
        (k, v) => MapEntry(k, v.toJson()),
      );
      await prefs.setString(_etagPrefsKey, jsonEncode(encoded));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 保存 ETag 缓存失败: $e');
    }
  }

  /// 获取认证头
  /// 已登录时返回 JWT 头，未登录时返回 Anon Key
  Map<String, String> get _authHeaders {
    return {
      'apikey': HttpClientConfig.anonKey,
      'Authorization': 'Bearer ${_accessToken ?? HttpClientConfig.anonKey}',
      'Content-Type': 'application/json',
    };
  }

  /// 合并请求头（认证头 + 自定义头）
  Map<String, String> _mergeHeaders(Map<String, String>? customHeaders) {
    if (customHeaders == null) return _authHeaders;
    return {
      ..._authHeaders,
      ...customHeaders,
    };
  }

  // ==================== HTTP 方法 ====================

  /// GET 请求（支持 ETag/304 缓存，默认关闭，仅对章节内容等不常变的数据启用）
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    CancelToken? cancelToken,
    bool useETag = false,
  }) async {
    final uri = _buildUri(path, queryParams);
    final url = uri.toString();

    // 加载 ETag 缓存（仅在需要时）
    if (useETag) await _loadETagCache();

    // 构建请求头（如有 ETag 则带上 If-None-Match）
    final requestHeaders = _mergeHeaders(headers);
    if (useETag && _etagCache.containsKey(url)) {
      requestHeaders['If-None-Match'] = _etagCache[url]!.etag;
    }

    http.Response response;
    if (useETag && _etagCache.containsKey(url)) {
      // 有 ETag 缓存时：先尝试带 If-None-Match 请求
      try {
        response = await _requestWithRetry(
          () => http.get(uri, headers: requestHeaders),
          timeout: timeout,
          cancelToken: cancelToken,
        );

        // 处理 304 Not Modified：返回缓存内容
        if (response.statusCode == 304) {
          final cached = _etagCache[url];
          if (cached != null) {
            if (kDebugMode) debugPrint('📦 ETag 304 缓存命中: $path');
            return http.Response(
              cached.body,
              200,
              headers: {'X-Cache': 'HIT'},
            );
          }
        }
      } catch (e) {
        // ETag 请求失败：清除该条缓存，回退到普通请求
        if (kDebugMode) debugPrint('⚠️ ETag 请求失败，回退普通请求: $path');
        _etagCache.remove(url);
      }
    }

    // 普通请求（无 ETag 或 ETag 未命中）
    response = await _requestWithRetry(
      () => http.get(uri, headers: _mergeHeaders(headers)),
      timeout: timeout,
      cancelToken: cancelToken,
    );

    // 处理 200 OK：保存 ETag 缓存（仅当 useETag 启用时）
    if (useETag && response.statusCode == 200) {
      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        _etagCache[url] = _ETagEntry(
          etag: etag,
          body: response.body,
          cachedAt: DateTime.now(),
        );
        unawaited(_saveETagCache());
      }
    }

    return response;
  }

  /// POST 请求
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.post(
        uri,
        headers: _mergeHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  /// PUT 请求
  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.put(
        uri,
        headers: _mergeHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  /// PATCH 请求
  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.patch(
        uri,
        headers: _mergeHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  /// DELETE 请求
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.delete(uri, headers: _mergeHeaders(headers)),
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  /// Multipart 请求（文件上传等）
  Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request, {
    Duration? timeout,
  }) async {
    // 注入认证头
    final authHeaders = _authHeaders;
    authHeaders.forEach((key, value) {
      if (!request.headers.containsKey(key)) {
        request.headers[key] = value;
      }
    });

    final requestTimeout = timeout ?? HttpClientConfig.timeout;
    try {
      final response = await request.send().timeout(requestTimeout);
      return response;
    } catch (e) {
      throw e is Exception ? e : Exception(e.toString());
    }
  }

  /// 原始 GET 流式请求（不注入 Supabase 认证头，用于外部资源下载）
  Future<http.StreamedResponse> getRawStream(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri);
    request.headers['Accept'] = '*/*';
    request.headers['User-Agent'] = 'PureEnjoy/1.0';
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final requestTimeout = timeout ?? HttpClientConfig.timeout;
    final response = await request.send().timeout(requestTimeout);
    return response;
  }

  // ==================== 工具方法 ====================

  /// 构建完整 URI
  Uri _buildUri(String path, Map<String, dynamic>? queryParams) {
    String url = path;
    if (!path.startsWith('http')) {
      url = '${HttpClientConfig.baseUrl}/rest/v1/$path';
    }

    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      url = '$url?$queryString';
    }

    return Uri.parse(url);
  }

  /// 带重试的请求执行
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = HttpClientConfig.maxRetries,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    http.Response? response;
    Exception? lastError;
    final requestTimeout = timeout ?? HttpClientConfig.timeout;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      // 请求前检查是否已取消
      if (cancelToken?.isCancelled == true) {
        throw RequestCancelledException();
      }

      try {
        response = await request().timeout(requestTimeout);

        // 响应后检查是否已取消（防止旧响应覆盖新数据）
        if (cancelToken?.isCancelled == true) {
          throw RequestCancelledException();
        }

        // 处理 401：尝试刷新 Token，失败才清空
        if (response.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            continue; // Token 已刷新，重试当前请求
          }
          _accessToken = null;
          throw const HttpException('401_UNAUTHORIZED');
        }

        return response;
      } on RequestCancelledException {
        rethrow; // 取消异常不重试，直接抛出
      } on SocketException catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      } on HttpException catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }

    throw lastError ?? Exception('请求失败，已重试 $maxRetries 次');
  }

  /// 尝试刷新 Token，成功则更新 _accessToken 并返回 true
  Future<bool> _tryRefreshToken() async {
    try {
      final success = await SupabaseService.instance.refreshToken();
      if (success) {
        _accessToken = SupabaseService.instance.accessToken;
        return _accessToken != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

}
