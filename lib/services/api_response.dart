/// API 响应结果（从 api_client 抽取为独立模型，api_client 通过 export 透出）
class ApiResponse {
  final bool isSuccess;
  final List<Map<String, dynamic>>? data;

  /// 非数组响应（RPC 返回单对象 / 标量，如 grant_game_reward 的 jsonb）承载于此。
  /// 数组响应仍走 [data]，二者互斥（数组响应时本字段为 null）。
  final Object? raw;
  final int? statusCode;
  final String? error;

  ApiResponse({
    required this.isSuccess,
    this.data,
    this.raw,
    this.statusCode,
    this.error,
  });

  factory ApiResponse.success(
    List<Map<String, dynamic>> data, {
    int? statusCode,
    Object? raw,
  }) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      raw: raw,
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
