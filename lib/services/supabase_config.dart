import 'package:flutter/foundation.dart';
import '../env.dart';

/// 安全日志工具：仅在开发模式或调试模式下输出日志
/// 生产环境中所有日志输出都会被静默处理，防止敏感信息泄露
class SecureLogger {
  static void log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static void error(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static void warning(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// 从异常对象中提取可读错误信息
  ///
  /// release 模式下类名会被混淆，需要针对不同异常类型提取有意义的信息。
  /// FormatException.toString() 只返回类名，必须用 .message。
  static String extractError(Object e) {
    if (e is String) return e;
    if (e is FormatException) return e.message;
    // Error 和 Exception 的 toString() 在 release 模式可能返回混淆名
    final msg = e.toString();
    if (msg.startsWith('Instance of ')) return e.runtimeType.toString();
    return msg;
  }
}

/// Supabase 配置（从环境变量读取）
///
/// 优先级：--dart-define > .env 文件 > 开发环境默认值
/// Supabase URL 和 anon key 本就是客户端公开信息（受 RLS 保护），
/// 提供开发环境默认值便于本地开发，生产环境请通过 --dart-define 注入。
class SupabaseConfig {
  // 开发环境默认值（仅用于本地开发，生产环境请通过 --dart-define 覆盖）
  static const String _devDefaultUrl =
      'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String _devDefaultAnonKey =
      'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6';

  static String get url => kDebugMode
      ? Env.get('SUPABASE_URL', fallback: _devDefaultUrl)
      : Env.get('SUPABASE_URL');

  static String get anonKey => kDebugMode
      ? Env.get('SUPABASE_ANON_KEY', fallback: _devDefaultAnonKey)
      : Env.get('SUPABASE_ANON_KEY');

  /// 基础请求头（查询用）
  static Map<String, String> get headers => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      };

  /// 写入请求头（INSERT/UPDATE/DELETE 用，要求返回数据）
  static Map<String, String> get writeHeaders => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      };
}

/// 认证响应（Supabase Auth）
class SupabaseAuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;
  final String? error;

  SupabaseAuthResponse({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.error,
  });

  bool get success => error == null && accessToken != null;
  String? get userId => user?['id'] as String?;
  String? get email => user?['email'] as String?;
  Map<String, dynamic>? get userMetadata =>
      user?['user_metadata'] as Map<String, dynamic>?;
}
