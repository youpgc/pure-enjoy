import '../config.dart';
import './http_client.dart';
import './cancel_token.dart';
import './api_response.dart';
import './api_logger.dart';
import './api_url_builder.dart';
import './api_response_handler.dart';
import './backend_api.dart';

export './api_response.dart';

/// API 客户端
/// 统一封装 Supabase REST API 调用，默认 limit=10
class ApiClient {
  static String get _baseUrl => AppConfig.supabaseUrl;

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
    bool useETag = false, // 低频变更数据的 304 缓存（如游戏配置表），默认关闭
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
        useETag: useETag,
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
    // change-server: 已切换表自动路由到本地后端（含离线队列回放）
    final route = BackendApi.routedTables[table];
    if (route != null) {
      return (await BackendApi.post(route, body: body ?? data)).toApiResponse();
    }
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


  /// PATCH 请求（兼容旧代码：通过 filters 参数过滤）
  static Future<ApiResponse> patchByFilter(
    String table, {
    required Map<String, String> filters,
    required Map<String, dynamic> body,
    Duration? timeout,
    String? note,
  }) async {
    // change-server: 已切换表按 id 路由到后端 PUT /{path}/{id}
    final route = BackendApi.routedTables[table];
    if (route != null) {
      final id = _extractId(filters);
      if (id == null) {
        return ApiResponse.error('本地后端模式仅支持按 id 更新 [$table]');
      }
      return (await BackendApi.put('$route/$id', body: body)).toApiResponse();
    }
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



  /// 按条件批量删除
  ///
  /// [bypassRouting] 强制走 Supabase 直连（注销流程用：后端新数据由
  /// 专用清空端点处理，此处仍需清理云端遗留历史数据）
  static Future<ApiResponse> batchDeleteByFilter(
    String table, {
    required Map<String, String> filters,
    bool bypassRouting = false,
    Duration? timeout,
    String? note,
  }) async {
    // change-server: 已切换表按 id 路由到后端 DELETE /{path}/{id}（多 id 循环）
    final route = BackendApi.routedTables[table];
    if (route != null && !bypassRouting) {
      return _routedBatchDelete(route, filters);
    }
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




  // ---------------- change-server 后端路由辅助 ----------------

  /// 从 PostgREST filters 中提取 id（eq. 单值），供后端路由使用
  static String? _extractId(Map<String, String> filters) {
    final raw = filters['id'];
    if (raw == null) return null;
    final v = raw.startsWith('eq.') ? raw.substring(3) : raw;
    return v.contains(',') ? null : v; // 多值不支持
  }

  /// 从 filters 提取 id 列表（in.(a,b,c) 或 eq.单值），供批量删除路由
  static List<String>? _extractIdList(Map<String, String> filters) {
    final raw = filters['id'];
    if (raw == null) return null;
    if (raw.startsWith('in.(') && raw.endsWith(')')) {
      final inner = raw.substring(4, raw.length - 1);
      return inner
          .split(',')
          .map((e) => e.replaceAll('"', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final one = _extractId(filters);
    return one == null ? null : [one];
  }

  /// 已切换表的批量删除：解析 id 列表循环单删（后端为单条 DELETE 语义）
  static Future<ApiResponse> _routedBatchDelete(
      String route, Map<String, String> filters) async {
    final ids = _extractIdList(filters);
    if (ids == null || ids.isEmpty) {
      return ApiResponse.error('本地后端模式仅支持按 id 批量删除');
    }
    final rows = <Map<String, dynamic>>[];
    for (final id in ids) {
      final r = await BackendApi.delete('$route/$id');
      if (!r.success) return r.toApiResponse();
      rows.addAll(r.toApiResponse().data ?? []);
    }
    return ApiResponse.success(rows);
  }

}
