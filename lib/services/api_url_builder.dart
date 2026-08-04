import '../config.dart';

/// 构建请求 URL（从 ApiClient._buildUrl 抽出，纯函数）
String buildApiUrl(
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
  return '${AppConfig.supabaseUrl}/rest/v1/$table$queryString';
}
