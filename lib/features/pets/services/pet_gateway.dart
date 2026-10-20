import '../../../services/api_client.dart';
import '../../../services/backend_api.dart';

/// pet 域数据网关（B6 搬迁）：pet 表/RPC 走自建后端 `/pet/**`，
/// 过滤语法保持 PostgREST 口径（表/函数白名单与登录态归属过滤在网关侧）。
///
/// 返回复用 [ApiResponse] 行列表语义：对象响应用 `data.first` 取回
/// （与 Supabase RPC 经 ApiClient 的消费方式一致）。
class PetGateway {
  PetGateway._();

  /// 表查询（等价 ApiClient.get 的 pet 表用法）。
  static Future<ApiResponse> get(
    String table, {
    Map<String, String>? filters,
    String? select,
    String? columns,
    String? order,
    int? limit,
    int? offset,
    String? note,
  }) async {
    final query = <String, String>{
      ...?filters,
      'select': select ?? columns ?? '*',
      if (order != null) 'order': order,
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
    };
    final result = await BackendApi.get('/pet/table/$table', query: query);
    return result.toApiResponse();
  }

  /// RPC 调用（等价 ApiClient.rpc 的 pet 用法；params 键=函数命名参数）。
  static Future<ApiResponse> rpc(
    String fn, {
    Map<String, dynamic>? params,
    String? note,
  }) async {
    final result = await BackendApi.post('/pet/rpc/$fn', body: params ?? {});
    return result.toApiResponse();
  }

  /// 目录表按主键批量拉取（本地网关无 PostgREST 关系嵌套语法，如
  /// `item:pet_items(...)`；嵌套数据一律两段查询后本地组装）。
  ///
  /// 返回 `{主键: 行}`；查询失败返回空表（调用方按缺目录降级，模型侧已有空值兜底）。
  static Future<Map<String, Map<String, dynamic>>> fetchCatalogRows(
    String table, {
    required String keyCol,
    required List<String> ids,
    required String cols,
    Map<String, String>? extraFilters,
    String? note,
  }) async {
    final map = <String, Map<String, dynamic>>{};
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return map;
    final resp = await get(
      table,
      select: '$keyCol,$cols',
      filters: {
        ...?extraFilters,
        keyCol: 'in.(${unique.join(',')})',
      },
      limit: 1000,
      note: note ?? '$table 目录批量查询',
    );
    if (!resp.isSuccess) return map;
    for (final row in (resp.data ?? const <Map<String, dynamic>>[])) {
      final key = row[keyCol]?.toString();
      if (key != null) map[key] = row;
    }
    return map;
  }
}
