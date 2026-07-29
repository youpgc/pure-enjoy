import 'package:flutter/foundation.dart';

/// API 层安全日志工具（从 api_client 抽取）。
/// 仅在开发模式下输出日志，生产环境静默处理。
class ApiLogger {
  static void error(String message, {Object? error}) {
    if (kDebugMode) {
      debugPrint(message);
      if (error != null) debugPrint('  详情: $error');
    }
  }

  /// 将异常转换为友好的用户提示语
  /// 开发环境通过 ApiLogger.error() 输出原始异常详情
  static String userFriendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('deadline exceeded')) {
      return '网络连接超时，请检查网络后重试';
    }
    if (msg.contains('socket') || msg.contains('connection refused')) {
      return '网络连接失败，请检查网络设置';
    }
    if (msg.contains('cancel')) {
      return '请求已取消';
    }
    return '网络异常，请稍后重试';
  }
}
