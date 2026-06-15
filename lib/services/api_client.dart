import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// 统一 API 响应封装
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse._({required this.success, this.data, this.errorMessage, this.statusCode});

  factory ApiResponse.success(T data, {int? statusCode}) =>
      ApiResponse._(success: true, data: data, statusCode: statusCode);

  factory ApiResponse.error(String message, {int? statusCode}) =>
      ApiResponse._(success: false, errorMessage: message, statusCode: statusCode);

  bool get isSuccess => success;
  bool get isError => !success;
}

/// 统一 API 异常
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// 统一 HTTP 状态码处理
String _handleHttpError(int statusCode, String? body) {
  switch (statusCode) {
    case 400:
      return '请求参数错误 (400)';
    case 401:
      return '认证失败，请重新登录 (401)';
    case 403:
      return '没有权限执行此操作 (403)';
    case 404:
      return '请求的资源不存在 (404)';
    case 409:
      return '数据冲突，可能已存在 (409)';
    case 422:
      return '数据格式错误 (422)';
    case 429:
      return '请求过于频繁，请稍后重试 (429)';
    case 500:
      return '服务器内部错误 (500)';
    case 502:
      return '网关错误 (502)';
    case 503:
      return '服务暂不可用 (503)';
    default:
      return '请求失败 (HTTP $statusCode)';
  }
}

/// 检查 HTTP 响应是否成功
bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

/// 统一 API 客户端
/// 封装所有 HTTP 请求，统一处理 headers、异常、状态码
class ApiClient {
  static final String _baseUrl = '${SupabaseConfig.url}/rest/v1';

  /// Supabase 基础 URL（不含 /rest/v1）
  static String get baseUrl => SupabaseConfig.url;

  /// 获取带用户标识的请求头（所有请求都需要 x-user-id 供 RLS 使用）
  static Map<String, String> get _authHeaders {
    final headers = Map<String, String>.from(SupabaseConfig.headers);
    final userId = AuthService.instance.currentUserId;
    if (userId != null) {
      headers['x-user-id'] = userId;
    }
    return headers;
  }

  /// GET 请求
  static Future<ApiResponse<List<Map<String, dynamic>>>> get(
    String table, {
    String? select,
    String? columns,
    Map<String, String>? filters,
    String? order,
    int? limit,
    int? offset,
  }) async {
    try {
      final uri = _buildUri(table, select: select, columns: columns, filters: filters, order: order, limit: limit, offset: offset);
      final response = await http.get(uri, headers: _authHeaders);

      if (_isSuccess(response.statusCode)) {
        final List<dynamic> data = jsonDecode(response.body);
        return ApiResponse.success(
          data.cast<Map<String, dynamic>>(),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.error(
        _handleHttpError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on SocketException {
      return ApiResponse.error('网络连接失败，请检查网络', statusCode: 0);
    } on FormatException {
      return ApiResponse.error('数据解析失败', statusCode: 0);
    } catch (e) {
      return ApiResponse.error('请求异常: $e', statusCode: 0);
    }
  }

  /// GET 单条
  static Future<ApiResponse<Map<String, dynamic>>> getOne(
    String table, {
    required Map<String, String> filters,
    String? select,
  }) async {
    try {
      final uri = _buildUri(table, select: select, filters: filters);
      final response = await http.get(uri, headers: _authHeaders);

      if (_isSuccess(response.statusCode)) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          return ApiResponse.error('数据不存在', statusCode: 404);
        }
        return ApiResponse.success(
          data.first as Map<String, dynamic>,
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.error(
        _handleHttpError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on SocketException {
      return ApiResponse.error('网络连接失败，请检查网络', statusCode: 0);
    } catch (e) {
      return ApiResponse.error('请求异常: $e', statusCode: 0);
    }
  }

  /// POST 请求
  static Future<ApiResponse<Map<String, dynamic>>> post(
    String table, {
    required Map<String, dynamic> body,
    bool returnRepresentation = true,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/$table');
      final headers = Map<String, String>.from(_authHeaders);
      headers['Prefer'] = returnRepresentation ? 'return=representation' : 'return=minimal';
      if (extraHeaders != null) headers.addAll(extraHeaders);

      final response = await http.post(uri, headers: headers, body: jsonEncode(body));

      if (_isSuccess(response.statusCode)) {
        if (response.body.isEmpty) {
          return ApiResponse.success({}, statusCode: response.statusCode);
        }
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return ApiResponse.success(
            data.first as Map<String, dynamic>,
            statusCode: response.statusCode,
          );
        }
        return ApiResponse.success(
          data is Map<String, dynamic> ? data : {},
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.error(
        _handleHttpError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on SocketException {
      return ApiResponse.error('网络连接失败，请检查网络', statusCode: 0);
    } catch (e) {
      return ApiResponse.error('请求异常: $e', statusCode: 0);
    }
  }

  /// PATCH 请求
  static Future<ApiResponse<bool>> patch(
    String table, {
    required Map<String, String> filters,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = _buildUri(table, filters: filters);
      final headers = Map<String, String>.from(_authHeaders);
      headers['Prefer'] = 'return=minimal';

      final response = await http.patch(uri, headers: headers, body: jsonEncode(body));

      if (_isSuccess(response.statusCode)) {
        return ApiResponse.success(true, statusCode: response.statusCode);
      }
      return ApiResponse.error(
        _handleHttpError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on SocketException {
      return ApiResponse.error('网络连接失败，请检查网络', statusCode: 0);
    } catch (e) {
      return ApiResponse.error('请求异常: $e', statusCode: 0);
    }
  }

  /// DELETE 请求
  static Future<ApiResponse<bool>> delete(
    String table, {
    required Map<String, String> filters,
  }) async {
    try {
      final uri = _buildUri(table, filters: filters);
      final response = await http.delete(uri, headers: _authHeaders);

      if (_isSuccess(response.statusCode) || response.statusCode == 404) {
        return ApiResponse.success(true, statusCode: response.statusCode);
      }
      return ApiResponse.error(
        _handleHttpError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on SocketException {
      return ApiResponse.error('网络连接失败，请检查网络', statusCode: 0);
    } catch (e) {
      return ApiResponse.error('请求异常: $e', statusCode: 0);
    }
  }

  /// 构建 URI
  static Uri _buildUri(
    String table, {
    String? select,
    String? columns,
    Map<String, String>? filters,
    String? order,
    int? limit,
    int? offset,
  }) {
    final params = <String, String>{};

    if (filters != null && filters.isNotEmpty) {
      params.addAll(filters);
    }
    if (select != null) {
      params['select'] = select;
    }
    if (columns != null) {
      params['select'] = columns;
    }
    if (order != null) {
      params['order'] = order;
    }
    if (limit != null) {
      params['limit'] = limit.toString();
    }
    if (offset != null) {
      params['offset'] = offset.toString();
    }

    return Uri.parse('$_baseUrl/$table').replace(queryParameters: params);
  }
}
