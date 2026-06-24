import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 全局 HttpClient 配置
class HttpClientConfig {
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 30);
  static const String baseUrl = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String anonKey = 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6';
}

/// 请求超时时间预设
class RequestTimeout {
  static const Duration list = Duration(seconds: 30);
  static const Duration simple = Duration(seconds: 15);
  static const Duration file = Duration(seconds: 60);
}

/// 统一的 HTTP 客户端
/// 所有 API 请求都通过此类发送，自动处理认证头、超时、重试等
class HttpClient {
  static HttpClient? _instance;

  HttpClient._();

  static HttpClient get instance {
    _instance ??= HttpClient._();
    return _instance!;
  }

  /// 当前 JWT Access Token
  String? _accessToken;

  /// 设置 JWT Access Token
  /// 登录成功后调用，后续请求将自动携带 Authorization: Bearer <token>
  void setAccessToken(String? token) {
    _accessToken = token;
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

  /// GET 请求
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.get(uri, headers: _mergeHeaders(headers)),
      timeout: timeout,
    );
  }

  /// POST 请求
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.post(
        uri,
        headers: _mergeHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
    );
  }

  /// PUT 请求
  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.put(
        uri,
        headers: _mergeHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
    );
  }

  /// PATCH 请求
  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.patch(
        uri,
        headers: _mergeHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      timeout: timeout,
    );
  }

  /// DELETE 请求
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _requestWithRetry(
      () => http.delete(uri, headers: _mergeHeaders(headers)),
      timeout: timeout,
    );
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
  }) async {
    http.Response? response;
    Exception? lastError;
    final requestTimeout = timeout ?? HttpClientConfig.timeout;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        response = await request().timeout(requestTimeout);

        // 处理 401：Token 失效
        if (response.statusCode == 401) {
          _accessToken = null;
          throw HttpException('401_UNAUTHORIZED');
        }

        return response;
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
}
