import 'package:flutter/foundation.dart';

import 'network_guard.dart';

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
    // 真无网 / 飞行模式：异常本身已带准确文案，不能被下面的通用兜底覆盖成
    // 一句含糊的「网络异常」，否则用户分不清是没网、超时还是被取消。
    if (e is NetworkOfflineException) return e.toString();
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
