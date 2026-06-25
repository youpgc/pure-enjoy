import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 统一环境变量读取
///
/// 优先级：
/// 1. `--dart-define` 编译时注入（生产环境推荐）
/// 2. `.env` 文件（flutter_dotenv 加载，开发环境推荐）
/// 3. fallback 默认值（可选）
class Env {
  Env._();

  /// 读取环境变量
  static String get(String key, {String? fallback}) {
    // 1. 优先从 --dart-define 读取
    final fromDefine = String.fromEnvironment(key);
    if (fromDefine.isNotEmpty) return fromDefine;

    // 2. 其次从 flutter_dotenv 读取
    final fromDotenv = dotenv.env[key];
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;

    // 3. 使用 fallback 默认值
    if (fallback != null) return fallback;

    throw StateError(
      'Environment variable "$key" not found. '
      'Please set via --dart-define=$key=xxx or add to .env file.',
    );
  }

  /// 读取环境变量（允许为空，返回空字符串而非抛异常）
  static String getOrEmpty(String key) {
    try {
      return get(key);
    } catch (_) {
      return '';
    }
  }
}
