import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// 统一的 Supabase HTTP 请求封装
/// 消除所有手动 URL 拼接和 headers 构建
class SupabaseHttp {
  static final String _baseUrl = '${SupabaseConfig.url}/rest/v1';

  /// GET 请求
  static Future<http.Response> get(
    String table, {
    String? select,
    Map<String, String>? filters,
    String? order,
    int? limit,
    int? offset,
  }) async {
    final uri = _buildUri(table, select: select, filters: filters, order: order, limit: limit, offset: offset);
    return http.get(uri, headers: SupabaseConfig.headers);
  }

  /// POST 请求
  static Future<http.Response> post(
    String table, {
    required Map<String, dynamic> body,
    bool returnRepresentation = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/$table');
    final headers = Map<String, String>.from(SupabaseConfig.headers);
    if (returnRepresentation) {
      headers['Prefer'] = 'return=representation';
    } else {
      headers['Prefer'] = 'return=minimal';
    }
    return http.post(uri, headers: headers, body: jsonEncode(body));
  }

  /// PATCH 请求
  static Future<http.Response> patch(
    String table, {
    required Map<String, dynamic> body,
    Map<String, String>? filters,
  }) async {
    final uri = _buildUri(table, filters: filters);
    return http.patch(uri, headers: SupabaseConfig.headers, body: jsonEncode(body));
  }

  /// DELETE 请求
  static Future<http.Response> delete(
    String table, {
    Map<String, String>? filters,
  }) async {
    final uri = _buildUri(table, filters: filters);
    return http.delete(uri, headers: SupabaseConfig.headers);
  }

  /// 构建 URI
  static Uri _buildUri(
    String table, {
    String? select,
    Map<String, String>? filters,
    String? order,
    int? limit,
    int? offset,
  }) {
    final buffer = StringBuffer('$_baseUrl/$table');

    // filters
    if (filters != null && filters.isNotEmpty) {
      filters.forEach((key, value) {
        buffer.write('?');
        // 如果已经有参数了，用 & 连接
        if (buffer.toString().contains('?') && !buffer.toString().endsWith('?')) {
          buffer.write('&');
        }
        buffer.write('$key=$value');
      });
    }

    // select
    if (select != null) {
      if (buffer.toString().contains('?')) {
        buffer.write('&select=$select');
      } else {
        buffer.write('?select=$select');
      }
    }

    // order
    if (order != null) {
      if (buffer.toString().contains('?')) {
        buffer.write('&order=$order');
      } else {
        buffer.write('?order=$order');
      }
    }

    // limit
    if (limit != null) {
      if (buffer.toString().contains('?')) {
        buffer.write('&limit=$limit');
      } else {
        buffer.write('?limit=$limit');
      }
    }

    // offset
    if (offset != null) {
      if (buffer.toString().contains('?')) {
        buffer.write('&offset=$offset');
      } else {
        buffer.write('?offset=$offset');
      }
    }

    return Uri.parse(buffer.toString());
  }
}
