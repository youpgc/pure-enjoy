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

  /// 从异常对象中提取可读错误信息（避免 release 模式下显示 Instance of 'Xxx'）
  static String extractError(Object e) {
    if (e is String) return e;
    final s = e.toString();
    if (s.startsWith('Instance of ')) return e.runtimeType.toString();
    return s;
  }
}

/// Supabase 配置（从环境变量读取）
class SupabaseConfig {
  static String get url => Env.get(
        'SUPABASE_URL',
        fallback: 'https://mhdrbjpqmzswswoazwjg.supabase.co',
      );

  static String get anonKey => Env.get(
        'SUPABASE_ANON_KEY',
        fallback:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1oZHJianBxbXpzd3N3b2F6d2pnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2MjAyMTMsImV4cCI6MjA5NDE5NjIxM30.VCMNj6BaSwiMRhTCXF52Ftbs2-gRgDkVZd8fTTT0g_E',
      );

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
