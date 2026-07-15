import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'http_client.dart';
import 'cancel_token.dart';

/// 安全日志工具：仅在开发模式下输出日志，生产环境静默处理
class _SecureLogger {
  static void error(String message, {Object? error}) {
    if (kDebugMode) {
      debugPrint(message);
      if (error != null) debugPrint('  详情: $error');
    }
  }

  /// 将异常转换为友好的用户提示语
  /// 开发环境通过 _SecureLogger.error() 输出原始异常详情
  static String userFriendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('deadline exceeded')) {
      return '网络连接超时，请检查网络后重试';
    }
    if (msg.contains('socket') || msg.contains('connection refused')) {
      return '网络连接失败，请检查网络设置';
    }
    if (msg.contains('cancel')) {
      return '请求已取消';
    }
    return '网络异常，请稍后重试';
  }
}

/// API 响应结果
class ApiResponse {
  final bool isSuccess;
  final List<Map<String, dynamic>>? data;
  final int? statusCode;
  final String? error;

  ApiResponse({
    required this.isSuccess,
    this.data,
    this.statusCode,
    this.error,
  });

  factory ApiResponse.success(List<Map<String, dynamic>> data, {int? statusCode}) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }

  /// 兼容旧代码：isError = !isSuccess
  bool get isError => !isSuccess;

  /// 兼容旧代码：errorMessage
  String? get errorMessage => error;
}

/// API 客户端
/// 统一封装 Supabase REST API 调用，默认 limit=10
class ApiClient {
  static String get _baseUrl => AppConfig.supabaseUrl;

  /// UUID 格式正则（8-4-4-4-12）
  static final _uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// 判断字符串是否为 UUID 格式
  static bool _isUuid(String value) => _uuidRegex.hasMatch(value);

  /// 构建 users 表的用户 ID 过滤条件
  /// 管理端创建的用户 ID 为19位自定义格式（如 U1779977270BKK5BK46），存在 public.users.id
  /// App 端注册的用户 ID 为 UUID（auth.users.id），存储在 public.users.auth_id
  /// 混合用 or: '(id.eq.XX,auth_id.eq.XX)' 会在 XX 为非 UUID 时，
  /// 导致 auth_id（UUID 类型）列报类型转换错误
  ///
  /// 用法: filters: {ApiClient.userKey(userId): 'eq.$userId'}
  static String userKey(String userId) => _isUuid(userId) ? 'auth_id' : 'id';

  /// 构建请求 URL
  static String _buildUrl(
    String table, {
    Map<String, String>? filters,
    String? select,
    String? order,
    int? limit = 10,
    int? offset,
    String? search,
    String? searchFields,
  }) {
    final queryParts = <String>[];

    // 选择字段
    if (select != null && select.isNotEmpty) {
      queryParts.add('select=${Uri.encodeComponent(select)}');
    }

    // 过滤条件
    if (filters != null) {
      filters.forEach((key, value) {
        // and/or 操作符的值包含括号与逗号，需保持原样供 PostgREST 解析
        if (key == 'and' || key == 'or') {
          queryParts.add('$key=$value');
        } else {
          queryParts.add('$key=${Uri.encodeComponent(value)}');
        }
      });
    }

    // 搜索
    if (search != null && search.isNotEmpty) {
      if (searchFields != null && searchFields.isNotEmpty) {
        final fields = searchFields.split(',');
        final orConditions = fields.map((field) {
          return '$field.ilike.*${Uri.encodeComponent(search)}*';
        }).join(',');
        queryParts.add('or=($orConditions)');
      }
    }

    // 排序
    if (order != null && order.isNotEmpty) {
      queryParts.add('order=${Uri.encodeComponent(order)}');
    }

    // 分页 - 默认 limit=10，传 null 取消限制
    if (limit != null) {
      queryParts.add('limit=$limit');
    }
    if (offset != null) {
      queryParts.add('offset=$offset');
    }

    final queryString = queryParts.isNotEmpty ? '?${queryParts.join('&')}' : '';
    return '$_baseUrl/rest/v1/$table$queryString';
  }

  /// GET 请求
  /// [columns] 兼容旧代码，等同于 select
  static Future<ApiResponse> get(
    String table, {
    Map<String, String>? filters,
    String? select,
    String? columns, // 兼容旧代码
    String? order,
    int? limit = 10,
    int? offset,
    String? search,
    String? searchFields,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    try {
      final url = _buildUrl(
        table,
        filters: filters,
        select: select ?? columns, // columns 兼容旧代码
        order: order,
        limit: limit,
        offset: offset,
        search: search,
        searchFields: searchFields,
      );

      final response = await HttpClient.instance.get(
        url,
        timeout: timeout ?? RequestTimeout.list,
        cancelToken: cancelToken,
      );

      return _handleResponse(response);
    } on RequestCancelledException {
      return ApiResponse.error('请求已取消');
    } catch (e) {
      _SecureLogger.error('❌ GET 请求失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// POST 请求
  /// [body] 兼容旧代码命名参数
  static Future<ApiResponse> post(
    String table,
    Map<String, dynamic> data, {
    Map<String, dynamic>? body, // 兼容旧代码
    bool returnRepresentation = true, // 兼容旧代码
    Duration? timeout,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/$table';
      final headers = <String, String>{};
      if (!returnRepresentation) {
        headers['Prefer'] = 'return=minimal';
      }
      final payload = body ?? data;
      final response = await HttpClient.instance.post(
        url,
        headers: headers.isNotEmpty ? headers : null,
        body: payload,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ POST 请求失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// PATCH 请求（新API：通过 id 参数指定记录）
  /// [body] 兼容旧代码命名参数
  static Future<ApiResponse> patch(
    String table,
    Map<String, dynamic> data, {
    Map<String, dynamic>? body, // 兼容旧代码
    required String id,
    Duration? timeout,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/$table?id=eq.$id';
      final payload = body ?? data;
      final response = await HttpClient.instance.patch(
        url,
        headers: {'Prefer': 'return=representation'},
        body: payload,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ PATCH 请求失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// PATCH 请求（兼容旧代码：通过 filters 参数过滤）
  static Future<ApiResponse> patchByFilter(
    String table, {
    required Map<String, String> filters,
    required Map<String, dynamic> body,
    Duration? timeout,
  }) async {
    try {
      final url = _buildUrl(
        table,
        filters: filters,
        limit: null,
      );
      final response = await HttpClient.instance.patch(
        url,
        headers: {'Prefer': 'return=representation'},
        body: body,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ PATCH 请求失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// DELETE 请求
  static Future<ApiResponse> delete(
    String table, {
    required String id,
    Duration? timeout,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/$table?id=eq.$id';
      final response = await HttpClient.instance.delete(
        url,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ DELETE 请求失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// 批量删除
  static Future<ApiResponse> batchDelete(
    String table, {
    required List<String> ids,
    Duration? timeout,
  }) async {
    try {
      final idList = ids.map((id) => '"$id"').join(',');
      final url = '$_baseUrl/rest/v1/$table?id=in.($idList)';
      final response = await HttpClient.instance.delete(
        url,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ 批量删除失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// 按条件批量删除
  static Future<ApiResponse> batchDeleteByFilter(
    String table, {
    required Map<String, String> filters,
    Duration? timeout,
  }) async {
    try {
      final url = _buildUrl(
        table,
        filters: filters,
        limit: null,
      );
      final response = await HttpClient.instance.delete(
        url,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ 批量删除失败 [$table]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// 聚合查询：求和
  /// 使用 Supabase 的 select=column.sum() 语法
  /// 返回聚合结果，失败时返回 null
  static Future<double?> sum(
    String table, {
    required String column,
    Map<String, String>? filters,
    Duration? timeout,
  }) async {
    try {
      final queryParts = <String>[
        'select=${Uri.encodeComponent('$column.sum()')}',
      ];
      if (filters != null) {
        filters.forEach((key, value) {
          // and/or 操作符的值包含括号与逗号，需保持原样供 PostgREST 解析
          if (key == 'and' || key == 'or') {
            queryParts.add('$key=$value');
          } else {
            queryParts.add('$key=${Uri.encodeComponent(value)}');
          }
        });
      }
      final queryString = '?${queryParts.join('&')}';
      final url = '$_baseUrl/rest/v1/$table$queryString';

      final response = await HttpClient.instance.get(
        url,
        timeout: timeout ?? RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = response.body;
        if (body.isEmpty) return 0;
        final data = jsonDecode(body) as List<dynamic>;
        if (data.isNotEmpty) {
          final result = data[0] as Map<String, dynamic>;
          final sumKey = column.contains('.') ? column : '$column.sum';
          final value = result[sumKey];
          if (value == null) return 0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value);
        }
        return 0;
      }
      return null;
    } catch (e) {
      _SecureLogger.error('❌ SUM 请求失败 [$table.$column]');
      return null;
    }
  }

  /// 使用 Prefer: count=exact 获取总数（HEAD 请求）
  static Future<int> count(
    String table, {
    Map<String, String>? filters,
    Duration? timeout,
  }) async {
    try {
      final queryParts = <String>[];
      if (filters != null) {
        filters.forEach((key, value) {
          queryParts.add('$key=${Uri.encodeComponent(value)}');
        });
      }
      final queryString = queryParts.isNotEmpty ? '?${queryParts.join('&')}' : '';
      final url = '$_baseUrl/rest/v1/$table$queryString';

      final response = await HttpClient.instance.get(
        url,
        headers: {
          'Prefer': 'count=exact',
          'Range': '0-0',
        },
        timeout: timeout ?? RequestTimeout.simple,
      );

      final contentRange = response.headers['content-range'];
      if (contentRange != null) {
        final match = RegExp(r'/(\d+)').firstMatch(contentRange);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      }
      return 0;
    } catch (e) {
      _SecureLogger.error('❌ COUNT 请求失败 [$table]');
      return 0;
    }
  }

  /// RPC 调用（调用 Supabase PostgreSQL 函数）
  static Future<ApiResponse> rpc(
    String functionName, {
    Map<String, dynamic>? params,
    Duration? timeout,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/rpc/$functionName';
      final response = await HttpClient.instance.post(
        url,
        body: params ?? {},
        timeout: timeout ?? RequestTimeout.simple,
      );
      return _handleResponse(response);
    } catch (e) {
      _SecureLogger.error('❌ RPC 请求失败 [$functionName]', error: e);
      return ApiResponse.error(_SecureLogger.userFriendlyError(e));
    }
  }

  /// 处理响应
  static ApiResponse _handleResponse(dynamic response) {
    if (response == null) {
      return ApiResponse.error('网络请求失败: 无响应', statusCode: 0);
    }
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final body = response.body;
        // PATCH/PUT 带 Prefer: return=representation 时：
        //   200 + 有数据 = 更新成功
        //   204 + 空 body = 无匹配行（RLS 拦截或过滤条件无结果）
        if (body.isEmpty) {
          // 204 No Content：对写操作（PATCH/PUT/DELETE）意味着 0 行被更新
          if (statusCode == 204) {
            return ApiResponse.error('更新失败：未匹配到任何记录', statusCode: statusCode);
          }
          return ApiResponse.success([], statusCode: statusCode);
        }
        final data = jsonDecode(body) as List<dynamic>;
        return ApiResponse.success(
          data.cast<Map<String, dynamic>>(),
          statusCode: statusCode,
        );
      } catch (e) {
        _SecureLogger.error('❌ 响应解析失败', error: e);
        return ApiResponse.error('数据解析异常', statusCode: statusCode);
      }
    } else if (statusCode == 401) {
      return ApiResponse.error('未授权，请重新登录', statusCode: statusCode);
    } else if (statusCode == 404) {
      if (kDebugMode) debugPrint('🔧 [api] 404 响应体: ${response.body}');
      return ApiResponse.error('资源不存在', statusCode: statusCode);
    } else if (statusCode == 409) {
      return ApiResponse.error('数据冲突', statusCode: statusCode);
    } else if (statusCode == 429) {
      return ApiResponse.error('请求过于频繁，请稍后再试', statusCode: statusCode);
    } else {
      _SecureLogger.error('❌ HTTP 错误 [$statusCode]: ${response.body}');
      return ApiResponse.error(
        '服务器响应异常 (HTTP $statusCode)',
        statusCode: statusCode,
      );
    }
  }
}
