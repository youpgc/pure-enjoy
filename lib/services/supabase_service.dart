import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Supabase客户端提供者
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Supabase配置服务
class SupabaseService {
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
  
  static bool get isInitialized => Supabase.instance.client.auth.currentSession != null;
}

/// 认证状态
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// 认证状态模型
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  
  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });
  
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
