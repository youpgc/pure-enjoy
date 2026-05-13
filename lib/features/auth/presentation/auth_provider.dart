import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../services/storage_service.dart';
import '../data/user_model.dart';

/// 认证状态Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// 认证状态管理器
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  
  AuthNotifier(this._ref) : super(AuthState()) {
    _init();
  }
  
  void _init() {
    // 监听认证状态变化
    final client = _ref.read(supabaseClientProvider);
    client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: session.user,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
        );
      }
    });
    
    // 检查当前状态
    final currentSession = client.auth.currentSession;
    if (currentSession != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: currentSession.user,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }
  
  /// 邮箱注册
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
  
  /// 邮箱登录
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
  
  /// 手机号登录/注册
  Future<bool> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client.auth.signInWithPassword(
        email: '$phone@pure-enjoy.com', // 使用手机号作为虚拟邮箱
        password: password,
      );
      if (response.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
  
  /// 发送验证码
  Future<bool> sendOtp(String phone) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.auth.signInWithOtp(
        phone: phone,
        options: OtpOptions(
          emailRedirectTo: 'pure-enjoy://auth',
        ),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
  
  /// 验证OTP
  Future<bool> verifyOtp(String phone, String token) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client.auth.verifyOTP(
        phone: phone,
        token: token,
      );
      if (response.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
  
  /// 退出登录
  Future<void> signOut() async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.auth.signOut();
      
      // 清空本地数据
      await StorageService().clearAll();
      
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
  
  /// 获取当前用户
  User? get currentUser => state.user;
}
