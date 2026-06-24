import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';

/// 认证状态
class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final String? role;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.email,
    this.role,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? email,
    String? role,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      error: error,
    );
  }

  AuthState clearError() {
    return AuthState(
      isAuthenticated: isAuthenticated,
      userId: userId,
      email: email,
      role: role,
    );
  }
}

/// 认证状态管理
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  /// 初始化：检查当前登录状态
  void _init() {
    final service = SupabaseService.instance;
    if (service.isLoggedIn) {
      final user = service.currentUser;
      final role = user?['user_metadata']?['role'] as String? ??
          user?['app_metadata']?['role'] as String? ??
          'user';
      state = AuthState(
        isAuthenticated: true,
        userId: service.currentUserId,
        email: user?['email'] as String?,
        role: role,
      );
    }
  }

  /// 使用 Supabase Auth 登录（邮箱+密码）
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      state = state.clearError();
      final response = await SupabaseService.instance.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.success) {
        final user = SupabaseService.instance.currentUser;
        final role = user?['user_metadata']?['role'] as String? ?? 'user';
        state = AuthState(
          isAuthenticated: true,
          userId: response.userId,
          email: response.email,
          role: role,
        );
        return true;
      }
      state = state.copyWith(error: response.error ?? '登录失败');
      return false;
    } catch (e) {
      state = state.copyWith(error: '登录出错：$e');
      return false;
    }
  }

  /// 注册（使用 Supabase Auth）
  Future<bool> signUp({
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    try {
      state = state.clearError();
      final response = await SupabaseService.instance.signUpWithEmail(
        email: email,
        password: password,
        username: username,
        phone: phone,
      );

      if (response.success) {
        final user = SupabaseService.instance.currentUser;
        final role = user?['user_metadata']?['role'] as String? ?? 'user';
        state = AuthState(
          isAuthenticated: true,
          userId: response.userId,
          email: response.email,
          role: role,
        );
        return true;
      }
      state = state.copyWith(error: response.error ?? '注册失败');
      return false;
    } catch (e) {
      state = state.copyWith(error: '注册出错：$e');
      return false;
    }
  }

  /// 登出
  Future<void> signOut() async {
    await SupabaseService.instance.signOut();
    state = const AuthState();
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    final user = await SupabaseService.instance.refreshUser();
    if (user != null) {
      final role = user['user_metadata']?['role'] as String? ?? 'user';
      state = AuthState(
        isAuthenticated: true,
        userId: user['id'] as String?,
        email: user['email'] as String?,
        role: role,
      );
    }
  }
}

/// 认证状态 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// 是否已登录（便捷 Provider）
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// 当前用户 ID（便捷 Provider）
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).userId;
});

/// 当前用户角色（便捷 Provider）
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).role;
});
