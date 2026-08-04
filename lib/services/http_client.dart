import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import './cancel_token.dart';
import './supabase_service.dart';
import './etag_cache.dart';
import './http_raw.dart';
import './retry_policy.dart';
import './etag_strategy.dart';

/// 全局 HttpClient 配置（统一引用 SupabaseConfig）
class HttpClientConfig {
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 30);

  static String get baseUrl => SupabaseConfig.url;

  static String get anonKey => SupabaseConfig.anonKey;
}

/// 请求超时时间预设
class RequestTimeout {
  static const Duration list = Duration(seconds: 30);
  static const Duration simple = Duration(seconds: 15);
  static const Duration file = Duration(seconds: 60);
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

  /// 常驻 HTTP Client：复用 TCP/TLS 连接（keep-alive），避免每次请求重建连接
  /// 这是降低海外 Supabase 跨境 RTT 累积延迟的关键——
  /// dart http 包顶层 http.get/post(...) 每次会新建 Client 并在返回后关闭，不跨请求复用连接
  final http.Client _client = http.Client();

  /// 当前 JWT Access Token
  String? _accessToken;

  /// 刷新单飞锁：同一时刻只允许一个真实刷新请求，其余并发 401 复用其结果。
  /// 防止「刷新风暴」——冷启动/会话恢复时大量并发请求同时 401，每个都打一次刷新接口。
  Completer<bool>? _refreshCompleter;

  /// ETag 缓存：URL -> 缓存条目（逻辑已抽取至 [EtagCache]，行为一致）
  final EtagCache _etagCache = EtagCache();

  /// 设置 JWT Access Token
  /// 登录成功后调用，后续请求将自动携带 Authorization: Bearer <token>
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// 加载持久化的 ETag 缓存（委托 [EtagCache]）
  Future<void> _loadETagCache() async => _etagCache.ensureLoaded();

  /// 清空 ETag 缓存（内存 + 持久化）
  /// 切换账号时调用：避免命中 304 后向新用户返回旧用户的缓存响应体
  Future<void> clearEtagCache() async => _etagCache.clear();

  /// 获取认证头
  /// 已登录时返回 JWT 头，未登录时返回 Anon Key
  Map<String, String> get _authHeaders {
    return {
      'apikey': HttpClientConfig.anonKey,
      'Authorization': 'Bearer ${_accessToken ?? HttpClientConfig.anonKey}',
      'Content-Type': 'application/json',
      'Accept-Encoding': 'gzip',
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

  /// 构建请求头，并在每次重试时重新读取 [_accessToken]。
  ///
  /// 关键约束：401 刷新成功后 [_accessToken] 已被更新，重试必须重新构建认证头，
  /// 否则会复用首次请求捕获的旧 token（GET 曾因此导致刷新无效、全部请求 401）。
  /// [etagUrl] 非空且命中 ETag 缓存时附带 If-None-Match。
  Map<String, String> _buildRequestHeaders(
    Map<String, String>? customHeaders, {
    String? etagUrl,
  }) {
    final headers = _mergeHeaders(customHeaders);
    if (etagUrl != null && _etagCache.contains(etagUrl)) {
      final cached = _etagCache.get(etagUrl);
      if (cached != null) headers['If-None-Match'] = cached.etag;
    }
    return headers;
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
    String? note,
  }) async {
    final uri = _buildUri(path, queryParams);
    final url = uri.toString();

    // 加载 ETag 缓存（仅在需要时）
    if (useETag) await _loadETagCache();

    http.Response response;
    try {
      response = await requestWithRetry(
        () => _client.get(
          uri,
          headers: _buildRequestHeaders(headers, etagUrl: useETag ? url : null),
        ),
        timeout: timeout,
        cancelToken: cancelToken,
        logMethod: 'GET',
        logUrl: url,
        logParams: queryParams,
        logNote: note,
        onUnauthorized: _tryRefreshToken,
      );
    } catch (e) {
      // ETag 请求失败：清除该条缓存，回退到普通请求（等价原行为）
      if (useETag && _etagCache.contains(url)) {
        if (kDebugMode) debugPrint('⚠️ ETag 请求失败，回退普通请求: $path');
        _etagCache.remove(url);
        response = await requestWithRetry(
          () => _client.get(uri, headers: _buildRequestHeaders(headers)),
          timeout: timeout,
          cancelToken: cancelToken,
          logMethod: 'GET',
          logUrl: url,
          logParams: queryParams,
          logNote: note,
          onUnauthorized: _tryRefreshToken,
        );
      } else {
        rethrow;
      }
    }

    // 处理缓存：304 返回缓存内容；200 保存 ETag（单请求路径，无冗余）
    if (useETag) {
      if (response.statusCode == 304) {
        final cached = _etagCache.get(url);
        if (cached != null) {
          return cachedResponseFromEtag(path, cached);
        }
      } else if (response.statusCode == 200) {
        storeEtagIfPresent(_etagCache, url, response);
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
    String? note,
  }) async {
    final uri = _buildUri(path, queryParams);
    return requestWithRetry(
      () => _client.post(
        uri,
        headers: _buildRequestHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
      logMethod: 'POST',
      logUrl: uri.toString(),
      logParams: body,
      logNote: note,
      onUnauthorized: _tryRefreshToken,
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
    String? note,
  }) async {
    final uri = _buildUri(path, queryParams);
    return requestWithRetry(
      () => _client.put(
        uri,
        headers: _buildRequestHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
      logMethod: 'PUT',
      logUrl: uri.toString(),
      logParams: body,
      logNote: note,
      onUnauthorized: _tryRefreshToken,
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
    String? note,
  }) async {
    final uri = _buildUri(path, queryParams);
    return requestWithRetry(
      () => _client.patch(
        uri,
        headers: _buildRequestHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
      logMethod: 'PATCH',
      logUrl: uri.toString(),
      logParams: body,
      logNote: note,
      onUnauthorized: _tryRefreshToken,
    );
  }

  /// DELETE 请求
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    CancelToken? cancelToken,
    String? note,
  }) async {
    final uri = _buildUri(path, queryParams);
    return requestWithRetry(
      () => _client.delete(uri, headers: _buildRequestHeaders(headers)),
      timeout: timeout,
      cancelToken: cancelToken,
      logMethod: 'DELETE',
      logUrl: uri.toString(),
      logParams: queryParams,
      logNote: note,
      onUnauthorized: _tryRefreshToken,
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

  /// 原始请求（全 URL，不注入 /rest/v1 前缀，不合并认证头）
  ///
  /// 用于 Supabase Auth 端点（/auth/v1/*）等需要完整自定义 URL 与自定义
  /// 请求头的场景。复用统一重试与超时能力；[handle401] 固定为 false，
  /// 即 401 时返回原始响应交由调用方解析错误体，而非抛 401 异常
  /// （登录失败必须返回 SupabaseAuthResponse 而非抛异常）。
  Future<http.Response> rawRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    String? note,
  }) async {
    final encodedBody =
        body is String ? body : (body != null ? jsonEncode(body) : null);
    return requestWithRetry(
      () => sendRawRequest(_client, method, url, headers, encodedBody),
      timeout: timeout,
      handle401: false,
      logMethod: method,
      logUrl: url,
      logParams: body,
      logNote: note,
      onUnauthorized: _tryRefreshToken,
    );
  }

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

  /// 尝试刷新 Token，成功则更新 _accessToken 并返回 true
  ///
  /// 并发安全（单飞）：多个请求因 401 同时进入时，只有第一个真正调用刷新接口，
  /// 其余请求复用同一个 [_refreshCompleter] 的结果，从而把 N 次刷新请求合并为 1 次。
  Future<bool> _tryRefreshToken() async {
    // 已有刷新在飞，直接复用其结果，避免重复打刷新接口
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final success = await SupabaseService.instance.refreshToken();
      if (success) {
        _accessToken = SupabaseService.instance.accessToken;
      }
      completer.complete(success && _accessToken != null);
    } catch (e) {
      completer.complete(false);
    } finally {
      // 释放锁，允许后续真正需要时再次刷新
      _refreshCompleter = null;
    }
    return completer.future;
  }

}
