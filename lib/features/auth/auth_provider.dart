import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';

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

  /// 角色三档回退：user_metadata.role → app_metadata.role → roleUser
  /// 登录/注册/刷新路径统一调用，避免漏掉 app_metadata 中间档导致
  /// 「登录态有角色、刷新后无角色」类不一致（纯享 auth 技能铁律②③）
  String _resolveRole(Map<String, dynamic>? user) {
    if (user == null) return roleUser;
    final userMeta = user['user_metadata'];
    final appMeta = user['app_metadata'];
    final userRole = userMeta is Map ? userMeta['role'] : null;
    final appRole = appMeta is Map ? appMeta['role'] : null;
    if (userRole is String && userRole.isNotEmpty) return userRole;
    if (appRole is String && appRole.isNotEmpty) return appRole;
    return roleUser;
  }

  /// 初始化：检查当前登录状态
  void _init() {
    final service = SupabaseService.instance;
    if (service.isLoggedIn) {
      final user = service.currentUser;
      final role = _resolveRole(user);
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
      if (kDebugMode) debugPrint('🔐 [Provider] 开始邮箱登录: $email');
      final response = await SupabaseService.instance.signInWithEmail(
        email: email,
        password: password,
      );
      if (kDebugMode) debugPrint('🔐 [Provider] 结果: success=${response.success}, error=${response.error}');

      if (response.success) {
        final user = SupabaseService.instance.currentUser;
        final role = _resolveRole(user);
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
      state = state.copyWith(error: '登录失败：${SecureLogger.extractError(e)}');
      return false;
    }
  }

/// 统一账号登录（邮箱 / 手机号 / 用户名 + 密码）
/// 注：昵称(nickname)可重复，不能作为登录标识；登录标识仅 email/phone/username。
  Future<bool> signInWithAccount({
    required String account,
    required String password,
  }) async {
    try {
      state = state.clearError();
      if (kDebugMode) debugPrint('🔐 [Provider] 开始登录: $account');
      final response = await SupabaseService.instance.signInWithAccount(
        account: account,
        password: password,
      );
      if (kDebugMode) debugPrint('🔐 [Provider] 结果: success=${response.success}, error=${response.error}');

      if (response.success) {
        final user = SupabaseService.instance.currentUser;
        final role = _resolveRole(user);
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
      state = state.copyWith(error: '登录失败：${SecureLogger.extractError(e)}');
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
        final role = _resolveRole(user);
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
      state = state.copyWith(error: '注册失败：${SecureLogger.extractError(e)}');
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
      final role = _resolveRole(user);
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
