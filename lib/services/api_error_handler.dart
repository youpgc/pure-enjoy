import 'dart:convert';
import 'package:http/http.dart' as http;

/// API 错误处理器
/// 统一处理 HTTP 错误状态码，提供友好的错误消息
class ApiErrorHandler {
  /// HTTP 状态码对应的错误消息
  static const Map<int, String> _errorMessages = {
    400: '请求参数错误，请检查输入数据',
    401: '未授权，请重新登录',
    403: '没有权限执行此操作',
    404: '请求的数据不存在',
    409: '数据冲突（可能已存在）',
    422: '数据验证失败',
    429: '请求过于频繁，请稍后再试',
    500: '服务器内部错误',
    502: '网关错误',
    503: '服务暂时不可用',
    504: '网关超时',
  };

  /// 处理 HTTP 响应
  /// 返回 null 表示成功，否则返回错误消息
  static String? handleResponse(http.Response response) {
    // 成功状态码
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return null;
    }

    // 尝试解析错误详情
    String detail = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        detail = body['message'] ?? body['error'] ?? body['detail'] ?? '';
      }
    } catch (_) {
      // 解析失败，使用默认消息
    }

    // 获取错误消息
    final message = _errorMessages[response.statusCode] ?? '请求失败 (HTTP ${response.statusCode})';
    
    if (detail.isNotEmpty) {
      return '$message: $detail';
    }
    return message;
  }

  /// 处理异常
  static String handleException(dynamic error) {
    if (error is http.ClientException) {
      return '网络连接失败，请检查网络设置';
    } else if (error is FormatException) {
      return '数据解析错误';
    } else if (error is TimeoutException) {
      return '请求超时，请稍后重试';
    } else {
      return '发生未知错误: ${error.toString()}';
    }
  }

  /// 检查响应是否成功
  static bool isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// 检查是否是客户端错误 (4xx)
  static bool isClientError(http.Response response) {
    return response.statusCode >= 400 && response.statusCode < 500;
  }

  /// 检查是否是服务器错误 (5xx)
  static bool isServerError(http.Response response) {
    return response.statusCode >= 500 && response.statusCode < 600;
  }

  /// 检查是否需要重新登录 (401)
  static bool needReLogin(http.Response response) {
    return response.statusCode == 401;
  }

  /// 获取建议的重试延迟（指数退避）
  static Duration getRetryDelay(int attempt) {
    // 指数退避: 1s, 2s, 4s, 8s, max 30s
    final seconds = (1 << attempt).clamp(1, 30);
    return Duration(seconds: seconds);
  }
}

/// 带重试的 API 请求
class RetryableApiRequest {
  final int maxRetries;
  final Duration timeout;

  RetryableApiRequest({
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
  });

  /// 执行带重试的请求
  Future<http.Response> execute(
    Future<http.Response> Function() request,
  ) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        final response = await request().timeout(timeout);
        
        // 成功或客户端错误（4xx）不重试
        if (ApiErrorHandler.isSuccess(response) || 
            ApiErrorHandler.isClientError(response)) {
          return response;
        }
        
        // 服务器错误，继续重试
        attempts++;
        if (attempts < maxRetries) {
          final delay = ApiErrorHandler.getRetryDelay(attempts);
          await Future.delayed(delay);
        }
      } on TimeoutException {
        attempts++;
        if (attempts < maxRetries) {
          final delay = ApiErrorHandler.getRetryDelay(attempts);
          await Future.delayed(delay);
        }
      } catch (e) {
        // 其他异常，继续重试
        attempts++;
        if (attempts < maxRetries) {
          final delay = ApiErrorHandler.getRetryDelay(attempts);
          await Future.delayed(delay);
        }
      }
    }
    
    // 重试次数用完，抛出异常
    throw Exception('请求失败，已重试 $maxRetries 次');
  }
}
