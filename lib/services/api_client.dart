import 'dart:convert';
import '../config.dart';
import './http_client.dart';
import './cancel_token.dart';
import './api_response.dart';
import './api_logger.dart';
import './api_url_builder.dart';
import './api_response_handler.dart';

export './api_response.dart';

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
    String? note,
  }) async {
    try {
      final url = buildApiUrl(
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
        note: note ?? table,
      );

      return handleApiResponse(response);
    } on RequestCancelledException {
      return ApiResponse.error('请求已取消');
    } catch (e) {
      ApiLogger.error('❌ GET 请求失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
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
    String? note,
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
        note: note ?? table,
      );

      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ POST 请求失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
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
    String? note,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/$table?id=eq.$id';
      final payload = body ?? data;
      final response = await HttpClient.instance.patch(
        url,
        headers: {'Prefer': 'return=representation'},
        body: payload,
        timeout: timeout ?? RequestTimeout.simple,
        note: note ?? table,
      );

      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ PATCH 请求失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
    }
  }

  /// PATCH 请求（兼容旧代码：通过 filters 参数过滤）
  static Future<ApiResponse> patchByFilter(
    String table, {
    required Map<String, String> filters,
    required Map<String, dynamic> body,
    Duration? timeout,
    String? note,
  }) async {
    try {
      final url = buildApiUrl(
        table,
        filters: filters,
        limit: null,
      );
      final response = await HttpClient.instance.patch(
        url,
        headers: {'Prefer': 'return=representation'},
        body: body,
        timeout: timeout ?? RequestTimeout.simple,
        note: note ?? table,
      );

      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ PATCH 请求失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
    }
  }

  /// DELETE 请求
  static Future<ApiResponse> delete(
    String table, {
    required String id,
    Duration? timeout,
    String? note,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/$table?id=eq.$id';
      final response = await HttpClient.instance.delete(
        url,
        headers: {'Prefer': 'return=representation'},
        timeout: timeout ?? RequestTimeout.simple,
        note: note ?? table,
      );

      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ DELETE 请求失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
    }
  }

  /// 批量删除
  static Future<ApiResponse> batchDelete(
    String table, {
    required List<String> ids,
    Duration? timeout,
    String? note,
  }) async {
    try {
      final idList = ids.map((id) => '"$id"').join(',');
      final url = '$_baseUrl/rest/v1/$table?id=in.($idList)';
      final response = await HttpClient.instance.delete(
        url,
        headers: {'Prefer': 'return=representation'},
        timeout: timeout ?? RequestTimeout.simple,
        note: note ?? table,
      );

      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ 批量删除失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
    }
  }

  /// 按条件批量删除
  static Future<ApiResponse> batchDeleteByFilter(
    String table, {
    required Map<String, String> filters,
    Duration? timeout,
    String? note,
  }) async {
    try {
      final url = buildApiUrl(
        table,
        filters: filters,
        limit: null,
      );
      final response = await HttpClient.instance.delete(
        url,
        headers: {'Prefer': 'return=representation'},
        timeout: timeout ?? RequestTimeout.simple,
        note: note ?? table,
      );

      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ 批量删除失败 [$table]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
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
    String? note,
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
        note: note ?? table,
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
      ApiLogger.error('❌ SUM 请求失败 [$table.$column]');
      return null;
    }
  }

  /// 使用 Prefer: count=exact 获取总数（HEAD 请求）
  static Future<int> count(
    String table, {
    Map<String, String>? filters,
    Duration? timeout,
    String? note,
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
        note: note ?? table,
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
      ApiLogger.error('❌ COUNT 请求失败 [$table]');
      return 0;
    }
  }

  /// RPC 调用（调用 Supabase PostgreSQL 函数）
  static Future<ApiResponse> rpc(
    String functionName, {
    Map<String, dynamic>? params,
    Duration? timeout,
    String? note,
  }) async {
    try {
      final url = '$_baseUrl/rest/v1/rpc/$functionName';
      final response = await HttpClient.instance.post(
        url,
        body: params ?? {},
        timeout: timeout ?? RequestTimeout.simple,
        note: note ?? 'rpc/$functionName',
      );
      return handleApiResponse(response);
    } catch (e) {
      ApiLogger.error('❌ RPC 请求失败 [$functionName]', error: e);
      return ApiResponse.error(ApiLogger.userFriendlyError(e));
    }
  }

}
