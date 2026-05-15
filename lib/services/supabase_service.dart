import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 服务
class SupabaseService {
  static SupabaseService? _instance;
  late final SupabaseClient _client;
  
  SupabaseService._() {
    _client = Supabase.instance.client;
  }
  
  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }
  
  SupabaseClient get client => _client;
  
  /// 获取当前用户ID
  String? get currentUserId => _client.auth.currentUser?.id;
  
  /// 获取当前用户
  User? get currentUser => _client.auth.currentUser;
  
  /// 检查是否已登录
  bool get isAuthenticated => _client.auth.currentUser != null;
  
  /// 登录
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// 注册
  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }
  
  /// 退出登录
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  /// 重置密码
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
  
  /// 更新用户信息
  Future<User> updateUser(Map<String, dynamic> data) async {
    return await _client.auth.updateUser(
      UserAttributes(data: data),
    );
  }
  
  /// 监听认证状态变化
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
