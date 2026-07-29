/// API 响应结果（从 api_client 抽取为独立模型，api_client 通过 export 透出）
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
