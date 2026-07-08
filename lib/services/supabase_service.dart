/// Supabase 服务门面
///
/// 将 SessionManager（会话管理）和 AuthApi（认证逻辑）组合为统一入口。
/// 所有外部代码通过 AuthService.instance 访问，保持向后兼容。
library;

import 'supabase_config.dart';
import 'session_manager.dart';
import 'auth_api.dart';
import '../utils/cache_helper.dart';
import 'chapter_cache_service.dart';
import 'package:flutter/foundation.dart';

// 重新导出，保持向后兼容
export 'supabase_config.dart';

// 为了兼容旧代码，保留别名
typedef SupabaseService = AuthService;

/// 用户认证服务（门面）
///
/// 委托 SessionManager 处理会话，委托 AuthApi 处理认证请求。
class AuthService {
  static AuthService? _instance;
  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  final _session = SessionManager.instance;
  final _auth = AuthApi.instance;

  // ==================== 用户信息代理 ====================

  String? get currentUserId => _session.currentUserId;
  String? get currentUserEmail => _session.currentUserEmail;
  String? get currentUserName => _session.currentUserName;
  String? get currentUserAvatar => _session.currentUserAvatar;
  int? get currentPoints => _session.currentPoints;
  String? get currentRole => _session.currentRole;
  String? get currentMemberLevel => _session.currentMemberLevel;
  bool get isAuthenticated => _session.isAuthenticated;
  bool get isLoggedIn => _session.isLoggedIn;
  Map<String, dynamic>? get currentUser => _session.authUser;
  String? get accessToken => _session.accessToken;

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    final restored = await _session.restoreSession();
    if (restored) {
      SecureLogger.log(
          '🔐 Supabase Auth 会话已恢复: ${_session.currentUserId}');
    }
  }

  // ==================== 认证代理 ====================

  /// 保存认证结果到会话
  Future<void> _saveAuthResult(SupabaseAuthResponse result) async {
    if (result.success && result.user != null) {
      await _session.saveSession(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
        authUser: result.user!,
      );
    }
  }

  /// 邮箱+密码登录
  Future<SupabaseAuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmail(
        email: email, password: password);
    await _saveAuthResult(result);
    return result;
  }

  /// 统一账号登录
  Future<SupabaseAuthResponse> signInWithAccount({
    required String account,
    required String password,
  }) async {
    final result = await _auth.signInWithAccount(
        account: account, password: password);
    await _saveAuthResult(result);
    return result;
  }

  /// 注册
  Future<SupabaseAuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    final result = await _auth.signUpWithEmail(
      email: email,
      password: password,
      username: username,
      phone: phone,
    );
    await _saveAuthResult(result);
    return result;
  }

  /// 退出登录
  Future<void> signOut() async {
    // 切换账号前清除本地缓存数据，防止旧账号数据残留
    try {
      await CacheHelper.instance.clearAllUserData();
    } catch (e) {
      debugPrint('清理缓存失败: $e');
    }
    try {
      await ChapterCacheService.instance.clearAllCache();
    } catch (e) {
      debugPrint('清理缓存失败: $e');
    }
    await _session.clearSession();
  }

  /// 刷新 Token
  Future<bool> refreshToken() async {
    final currentRefresh = _session.refreshToken;
    if (currentRefresh == null) return false;

    final result =
        await _auth.refreshToken(refreshToken: currentRefresh);
    if (result.success) {
      await _session.updateTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
        authUser: result.user,
      );
      return true;
    }
    return false;
  }

  /// 刷新用户信息
  Future<Map<String, dynamic>?> refreshUser() async {
    return refreshAuthUser();
  }

  /// 刷新用户信息（Supabase Auth）
  Future<Map<String, dynamic>?> refreshAuthUser() async {
    final token = _session.accessToken;
    if (token == null) return null;

    final user = await _auth.fetchUser(accessToken: token);
    if (user != null) {
      await _session.updateAuthUser(user);
    }
    return user;
  }

  /// 重新加载当前用户数据
  Future<bool> reloadCurrentUser() async {
    final user = await refreshAuthUser();
    return user != null;
  }

  /// 修改密码
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = _session.accessToken;
    if (token == null) {
      return {'success': false, 'message': '未登录，无法修改密码'};
    }
    return _auth.changePassword(
      accessToken: token,
      newPassword: newPassword,
    );
  }

  /// 获取当前用户的认证 Headers
  Map<String, String> get authHeaders => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization':
            'Bearer ${_session.accessToken ?? SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };
}
