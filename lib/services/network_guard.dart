import 'package:connectivity_plus/connectivity_plus.dart';

/// 离线异常：设备无可用网络接口（飞行模式 / 真无网）。
/// 由 [assertOnline] 抛出，页面层可作为「网络已断开」友好提示。
class NetworkOfflineException implements Exception {
  const NetworkOfflineException();
  @override
  String toString() => '网络连接已断开，请检查网络设置';
}

/// 离线短路预检：发请求前确认存在可用网络接口。
///
/// connectivity_plus 仅判断「是否有网络接口」，无法判定「能否真正连通外网」，
/// 故弱网 / 跨境丢包仍依赖 requestWithRetry 的总耗时预算兜底；
/// 此处只拦截「真无网 / 飞行模式」场景，使其秒级失败而非烧满预算。
/// 插件不可用（权限缺失 / 平台异常）时不拦截正常请求。
Future<void> assertOnline() async {
  try {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      throw const NetworkOfflineException();
    }
  } on NetworkOfflineException {
    rethrow;
  } catch (_) {
    // 插件异常不阻断请求（如权限缺失、平台不支持）
  }
}
