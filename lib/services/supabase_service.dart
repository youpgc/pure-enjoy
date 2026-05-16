import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Supabase 认证服务
class SupabaseService {
  static SupabaseService? _instance;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  // Supabase 客户端
  SupabaseClient get _client => Supabase.instance.client;

  // 认证状态流
  Stream<AuthState> get authStateChange => _client.auth.onAuthStateChange;

  /// 获取当前用户
  User? get currentUser => _client.auth.currentUser;

  /// 获取当前用户ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// 获取当前用户邮箱
  String? get currentUserEmail => _client.auth.currentUser?.email;

  /// 获取当前用户元数据
  Map<String, dynamic>? get userMetadata => _client.auth.currentUser?.userMetadata;

  /// 获取当前用户名
  String? get currentUserName {
    final metadata = userMetadata;
    if (metadata != null && metadata['name'] != null) {
      return metadata['name'] as String;
    }
    return currentUserEmail?.split('@').first;
  }

  /// 检查是否已登录
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// 登录
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      debugPrint('登录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('登录失败: $e');
      rethrow;
    }
  }

  /// 注册
  Future<AuthResponse> signUp(String email, String password, {String? name}) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );
      return response;
    } on AuthException catch (e) {
      debugPrint('注册失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('注册失败: $e');
      rethrow;
    }
  }

  /// 退出登录
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      debugPrint('退出登录失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('退出登录失败: $e');
      rethrow;
    }
  }

  /// 更新用户信息
  Future<UserResponse> updateUser({String? name, String? email, String? password}) async {
    try {
      final attributes = UserAttributes(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );
      final response = await _client.auth.updateUser(attributes);
      return response;
    } on AuthException catch (e) {
      debugPrint('更新用户信息失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('更新用户信息失败: $e');
      rethrow;
    }
  }

  /// 发送密码重置邮件
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      debugPrint('发送密码重置邮件失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('发送密码重置邮件失败: $e');
      rethrow;
    }
  }

  /// 刷新会话
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response;
    } on AuthException catch (e) {
      debugPrint('刷新会话失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('刷新会话失败: $e');
      rethrow;
    }
  }
}

/// 为了兼容旧代码，保留 AuthService 别名
@Deprecated('使用 SupabaseService 替代')
typedef AuthService = SupabaseService;
