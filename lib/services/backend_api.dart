import 'dart:convert';
import './api_response.dart';
import './server_config.dart';
import './http_client.dart';
import './session_manager.dart';
import './supabase_config.dart';

/// 自建后端 REST 访问端（change-server 分支）
///
/// 统一职责：
/// - 基址 `ServerConfig.baseUrl/api/v1`
/// - Bearer 注入（SessionManager.accessToken）
/// - 后端信封 `{code, message, data}` 解包为 [BackendResult]
///
/// 401 刷新仍由 [HttpClient] 统一处理（AuthApi 已指向后端 refresh）。
/// 数据面各服务从 PostgREST 迁移到本类（逐模块进行，见 docs/change-server-覆盖率清单.md）。
class BackendApi {
  BackendApi._();

  static String get _base => '${ServerConfig.baseUrl}/api/v1';

  /// 已切换到后端的表 → 端点前缀（混合期路由表，逐表迁入）。
  /// ApiClient 写入口（post/patchByFilter/batchDeleteByFilter）据此自动转发，
  /// 包括 offline_sync 离线队列回放；未列出的表仍走 Supabase。
  static const Map<String, String> routedTables = {
    'notes': '/users/notes',
    'habits': '/users/habits',
    'reminders': '/users/reminders',
    'reminder_schedules': '/users/reminder-schedules',
    'mood_diaries': '/users/mood-diaries',
    'expenses': '/users/expenses',
    'weight_records': '/users/weight-records',
    'user_favorites': '/users/favorites',
    'user_anniversaries': '/users/anniversaries',
  };

  static bool isRouted(String table) => routedTables.containsKey(table);

  static Map<String, String> _headers() {
    final token = SessionManager.instance.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET（query 值经 URL 编码）
  static Future<BackendResult> get(String path, {Map<String, String>? query}) {
    return _request('GET', path, query: query);
  }

  static Future<BackendResult> post(String path, {Map<String, dynamic>? body}) {
    return _request('POST', path, body: body);
  }

  static Future<BackendResult> put(String path, {Map<String, dynamic>? body}) {
    return _request('PUT', path, body: body);
  }

  static Future<BackendResult> delete(String path) {
    return _request('DELETE', path);
  }

  static Future<BackendResult> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    try {
      var url = '$_base$path';
      if (query != null && query.isNotEmpty) {
        final qs = query.entries
            .where((e) => e.value.isNotEmpty)
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        if (qs.isNotEmpty) url = '$url?$qs';
      }

      final response = await HttpClient.instance.rawRequest(
        url,
        method: method,
        headers: _headers(),
        body: body,
        timeout: RequestTimeout.simple,
        note: '$method $path',
      );

      return _parse(response.body, response.statusCode);
    } catch (e) {
      return BackendResult(
        success: false,
        error: SecureLogger.extractError(e),
      );
    }
  }

  /// 后端信封解析：code==200 → success + data；否则 error=message
  static BackendResult _parse(String body, int statusCode) {
    try {
      final envelope = jsonDecode(body) as Map<String, dynamic>;
      final code = envelope['code'];
      if (code == 200) {
        return BackendResult(success: true, data: envelope['data']);
      }
      return BackendResult(
        success: false,
        error: (envelope['message'] as String?) ?? '请求失败($code)',
        statusCode: statusCode,
      );
    } catch (_) {
      return BackendResult(
        success: false,
        error: '响应解析失败($statusCode)',
        statusCode: statusCode,
      );
    }
  }
}

/// 后端调用结果（data 已解包；分页端点 data 为 {list,total,page,page_size}）
class BackendResult {
  final bool success;
  final dynamic data;
  final String? error;
  final int statusCode;

  const BackendResult({
    required this.success,
    this.data,
    this.error,
    this.statusCode = 0,
  });

  /// 分页数据便捷取列表（data['list']）
  List<dynamic> get list =>
      data is Map<String, dynamic> ? (data['list'] as List<dynamic>? ?? []) : [];

  /// 分页数据便捷取总数
  int get total =>
      data is Map<String, dynamic> ? ((data['total'] as num?) ?? 0).toInt() : 0;

  /// 转换为旧 ApiResponse（行数组语义），供 ApiClient 路由转发复用
  ApiResponse toApiResponse() {
    if (!success) {
      return ApiResponse.error(error ?? '请求失败', statusCode: statusCode);
    }
    List<Map<String, dynamic>> rows;
    if (data is List) {
      rows = data.cast<Map<String, dynamic>>();
    } else if (data is Map<String, dynamic>) {
      final map = data as Map<String, dynamic>;
      rows = map['list'] is List
          ? (map['list'] as List).cast<Map<String, dynamic>>()
          : [map];
    } else {
      rows = [];
    }
    return ApiResponse.success(rows, statusCode: statusCode, raw: data);
  }
}
