import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
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

  /// 登录/注册成功后重挂当前账号的本地横幅提醒。
  /// 冷启动时 main 的 arm* 若在未登录态执行会直接空转，
  /// 登录成功必须补挂，否则历史提醒要等下次冷启动才生效。
  void _armLocalReminders() {
    unawaited(NotificationService.instance
        .armHabitRemindersFromRemote()
        .catchError((_) {}));
    unawaited(NotificationService.instance
        .armRemindersFromRemote()
        .catchError((_) {}));
    unawaited(NotificationService.instance
        .armAnniversariesFromRemote()
        .catchError((_) {}));
  }

  /// 初始化：检查当前登录状态
  void _init() {
    // 注册 Token 刷新成功回调：401→刷新后重同步 Riverpod 鉴权镜像，闭合 refreshUser 钩子。
    SupabaseService.instance.setOnTokenRefreshed(_onTokenRefreshed);
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
          userId: SupabaseService.instance.currentUserId,
          email: response.email,
          role: role,
        );
        _armLocalReminders();
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
        // 注册成功但当前 UX 为「需手动登录」（技能 §4.5 产品决策），
        // 故不置 isAuthenticated=true，使 authProvider 与「请登录」UI 一致，
        // 避免路由守卫误判已登录而错误跳转。
        state = AuthState(
          isAuthenticated: false,
          userId: SupabaseService.instance.currentUserId,
          email: response.email,
          role: role,
        );
        _armLocalReminders();
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

  /// Token 刷新成功后由 SupabaseService 回调触发：重同步 Riverpod 鉴权镜像。
  /// 不阻塞刷新链（调用方不 await），异常仅调试日志输出，绝不抛出影响主流程。
  Future<void> _onTokenRefreshed() async {
    try {
      await refreshUser();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 [Provider] Token 刷新后同步鉴权状态失败: $e');
      }
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    final user = await SupabaseService.instance.refreshUser();
    if (user != null) {
      final role = _resolveRole(user);
      state = AuthState(
        isAuthenticated: true,
        userId: SupabaseService.instance.currentUserId,
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
