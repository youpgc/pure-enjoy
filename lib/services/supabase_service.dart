import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Supabase 配置
class SupabaseConfig {
  static const String url = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1oZHJianBxbXpzd3N3b2F6d2pnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2MjAyMTMsImV4cCI6MjA5NDE5NjIxM30.2qRPz7rB1n_q_8E2Z1F8X3h9Y4Z5a6b7c8d9e0f1a2b';
  
  static Map<String, String> get headers => {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };
}

/// 用户认证服务
class AuthService {
  static AuthService? _instance;
  
  AuthService._();
  
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }
  
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  
  /// 获取当前用户ID
  String? get currentUserId => _user?['id'];
  
  /// 获取当前用户邮箱
  String? get currentUserEmail => _user?['email'];
  
  /// 获取当前用户名
  String? get currentUserName => _user?['user_metadata']?['name'] ?? _user?['email']?.split('@').first;
  
  /// 检查是否已登录
  bool get isAuthenticated => _accessToken != null && _user != null;
  
  /// 初始化（从本地存储恢复会话）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _user = jsonDecode(userJson);
    }
  }
  
  /// 登录
  Future<bool> signIn(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=password'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];
        
        // 保存到本地
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('user', jsonEncode(_user));
        
        return true;
      }
      return false;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }
  
  /// 注册
  Future<bool> signUp(String email, String password, {String? name}) async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {'name': name},
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];
        
        // 保存到本地
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('user', jsonEncode(_user));
        
        return true;
      }
      return false;
    } catch (e) {
      print('Sign up error: $e');
      return false;
    }
  }
  
  /// 退出登录
  Future<void> signOut() async {
    try {
      if (_accessToken != null) {
        await http.post(
          Uri.parse('${SupabaseConfig.url}/auth/v1/logout'),
          headers: {
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer $_accessToken',
          },
        );
      }
    } catch (e) {
      print('Sign out error: $e');
    } finally {
      _accessToken = null;
      _refreshToken = null;
      _user = null;
      
      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user');
    }
  }
  
  /// 获取当前用户的认证 Headers
  Map<String, String> get authHeaders => {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${_accessToken ?? SupabaseConfig.anonKey}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };
}

// 为了兼容旧代码，保留别名
typedef SupabaseService = AuthService;
