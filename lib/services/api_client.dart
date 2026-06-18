import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'http_client.dart';

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
        queryParts.add('$key=${Uri.encodeComponent(value)}');
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
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ GET 请求失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
      debugPrint('❌ POST 请求失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
        body: payload,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ PATCH 请求失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
        body: body,
        timeout: timeout ?? RequestTimeout.simple,
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ PATCH 请求失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
      debugPrint('❌ DELETE 请求失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
      debugPrint('❌ 批量删除失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
      debugPrint('❌ 批量删除失败 [$table]: $e');
      return ApiResponse.error('请求失败: $e');
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
      debugPrint('❌ COUNT 请求失败 [$table]: $e');
      return 0;
    }
  }

  /// 处理响应
  static ApiResponse _handleResponse(dynamic response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final body = response.body;
        if (body.isEmpty) {
          return ApiResponse.success([], statusCode: statusCode);
        }
        final data = jsonDecode(body) as List<dynamic>;
        return ApiResponse.success(
          data.cast<Map<String, dynamic>>(),
          statusCode: statusCode,
        );
      } catch (e) {
        return ApiResponse.error('解析响应失败: $e', statusCode: statusCode);
      }
    } else if (statusCode == 401) {
      return ApiResponse.error('未授权，请重新登录', statusCode: statusCode);
    } else if (statusCode == 404) {
      return ApiResponse.error('资源不存在', statusCode: statusCode);
    } else if (statusCode == 409) {
      return ApiResponse.error('数据冲突', statusCode: statusCode);
    } else if (statusCode == 429) {
      return ApiResponse.error('请求过于频繁，请稍后再试', statusCode: statusCode);
    } else {
      return ApiResponse.error(
        '请求失败 (HTTP $statusCode): ${response.body}',
        statusCode: statusCode,
      );
    }
  }
}
