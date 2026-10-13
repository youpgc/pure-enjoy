/// 自建后端服务配置（change-server 分支：双端切换本地 Spring Boot 服务）
///
/// 地址解析顺序：
/// 1. `--dart-define=SERVER_BASE_URL=...`（真机联调用局域网 IP）
/// 2. 默认 Android 模拟器地址 10.0.2.2（映射宿主机 localhost）
class ServerConfig {
  ServerConfig._();

  /// 后端服务根地址（不含 /api/v1）
  static const String baseUrl = String.fromEnvironment(
    'SERVER_BASE_URL',
    defaultValue: 'http://10.0.2.2:18080',
  );
}
