import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'http_client.dart';

/// 安全日志工具：仅在开发模式或调试模式下输出日志
/// 生产环境中所有日志输出都会被静默处理，防止敏感信息泄露
class SecureLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

/// 缓存条目
class _CacheEntry {
  final dynamic response;
  final DateTime cachedAt;

  _CacheEntry(this.response, this.cachedAt);

  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}

/// Supabase 配置
class SupabaseConfig {
  static const String url = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String anonKey = 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6';

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
  final String? userId;
  final String? email;
  final Map<String, dynamic>? userMetadata;
  final String? error;

  SupabaseAuthResponse({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.email,
    this.userMetadata,
    this.error,
  });

  bool get success => error == null && accessToken != null;
}

/// 用户认证服务
///
/// 仅使用 Supabase Auth（邮箱+密码），JWT Token 认证
/// 不再支持自定义认证（users表 + SHA-256 + x-user-id）
class AuthService {
  static AuthService? _instance;

  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  /// 请求缓存（仅 GET 请求）
  final Map<String, _CacheEntry> _cache = {};

  /// 缓存有效期
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// 最大重试次数
  static const int _maxRetries = 3;

  // ==================== Supabase Auth 状态 ====================

  /// 当前 JWT Token
  String? _accessToken;

  /// 当前 Refresh Token
  String? _refreshToken;

  /// 当前 Supabase Auth 用户信息
  Map<String, dynamic>? _authUser;

  // ==================== 通用 Getter ====================

  /// 获取当前用户ID
  String? get currentUserId => _authUser?['id'] as String?;

  /// 获取当前用户邮箱
  String? get currentUserEmail => _authUser?['email'] as String?;

  /// 获取当前用户名
  String? get currentUserName {
    final nickname = _authUser?['user_metadata']?['username'] as String?;
    return nickname ?? currentUserEmail?.split('@').first ?? '用户';
  }

  /// 获取当前用户头像
  String? get currentUserAvatar => _authUser?['user_metadata']?['avatar_url'] as String?;

  /// 检查是否已登录
  bool get isAuthenticated => _authUser != null;

  /// 兼容旧代码：isLoggedIn 别名
  bool get isLoggedIn => isAuthenticated;

  /// 获取当前用户
  Map<String, dynamic>? get currentUser => _authUser;

  /// 获取当前用户积分
  int? get currentPoints => _authUser?['user_metadata']?['points'] as int?;

  /// 获取当前用户角色
  String? get currentRole => _authUser?['user_metadata']?['role'] as String?;

  /// 获取当前用户会员等级
  String? get currentMemberLevel => _authUser?['user_metadata']?['member_level'] as String?;

  /// 获取当前 JWT Token
  String? get accessToken => _accessToken;

  // ==================== 初始化 ====================

  /// 初始化（恢复 Supabase Auth 会话）
  Future<void> initialize() async {
    await _restoreSupabaseAuthSession();
  }

  /// 恢复 Supabase Auth 会话
  Future<void> _restoreSupabaseAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('sb_access_token');
      _refreshToken = prefs.getString('sb_refresh_token');
      final userJson = prefs.getString('sb_user');

      if (_accessToken != null && userJson != null) {
        _authUser = jsonDecode(userJson) as Map<String, dynamic>;
        _syncAuthToHttpClient();
        SecureLogger.log('🔐 Supabase Auth 会话已恢复: ${_authUser!['id']}');
      }
    } catch (e) {
      SecureLogger.warning('⚠️ 恢复 Supabase Auth 会话失败: $e');
    }
  }

  // ==================== Supabase Auth 认证 ====================

  /// Auth API URL
  String get _authUrl => '${SupabaseConfig.url}/auth/v1';

  /// 使用邮箱+密码登录（Supabase Auth）
  Future<SupabaseAuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      SecureLogger.log('🔐 Supabase Auth 登录请求');

      final response = await http.post(
        Uri.parse('$_authUrl/token?grant_type=password'),
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        _authUser = data['user'] as Map<String, dynamic>?;

        _syncAuthToHttpClient();
        await _saveSupabaseAuthSession();

        SecureLogger.log('✅ Supabase Auth 登录成功');
        return SupabaseAuthResponse(
          accessToken: _accessToken,
          refreshToken: _refreshToken,
          userId: _authUser?['id'] as String?,
          email: _authUser?['email'] as String?,
          userMetadata: _authUser?['user_metadata'] as Map<String, dynamic>?,
        );
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        return SupabaseAuthResponse(
          error: error?['msg'] as String? ?? error?['error_description'] as String? ?? '登录失败',
        );
      }
    } catch (e) {
      return SupabaseAuthResponse(error: '登录出错: $e');
    }
  }

  /// 注册（Supabase Auth）
  Future<SupabaseAuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    try {
      SecureLogger.log('📝 Supabase Auth 注册请求');

      final response = await http.post(
        Uri.parse('$_authUrl/signup'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {
            if (username != null) 'username': username,
            if (phone != null) 'phone': phone,
            'role': 'user',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        _authUser = data['user'] as Map<String, dynamic>?;

        _syncAuthToHttpClient();
        await _saveSupabaseAuthSession();

        SecureLogger.log('✅ Supabase Auth 注册成功');
        return SupabaseAuthResponse(
          accessToken: _accessToken,
          refreshToken: _refreshToken,
          userId: _authUser?['id'] as String?,
          email: _authUser?['email'] as String?,
          userMetadata: _authUser?['user_metadata'] as Map<String, dynamic>?,
        );
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        return SupabaseAuthResponse(
          error: error?['msg'] as String? ?? error?['error_description'] as String? ?? '注册失败',
        );
      }
    } catch (e) {
      return SupabaseAuthResponse(error: '注册出错: $e');
    }
  }

  /// 刷新 Token
  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_authUrl/token?grant_type=refresh_token'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': _refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        _authUser = data['user'] as Map<String, dynamic>?;
        _syncAuthToHttpClient();
        await _saveSupabaseAuthSession();
        return true;
      }
      return false;
    } catch (e) {
      SecureLogger.warning('⚠️ 刷新Token失败: $e');
      return false;
    }
  }

  /// 刷新用户信息
  Future<Map<String, dynamic>?> refreshUser() async {
    return refreshAuthUser();
  }

  /// 刷新用户信息（Supabase Auth）
  Future<Map<String, dynamic>?> refreshAuthUser() async {
    if (_accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_authUrl/user'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        _authUser = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSupabaseAuthSession();
        return _authUser;
      }
      return null;
    } catch (e) {
      SecureLogger.warning('⚠️ 刷新用户信息失败: $e');
      return null;
    }
  }

  /// 同步 Supabase Auth 用户到 HttpClient
  void _syncAuthToHttpClient() {
    HttpClient.instance.setAccessToken(_accessToken);
  }

  /// 保存 Supabase Auth 会话
  Future<void> _saveSupabaseAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString('sb_access_token', _accessToken!);
      } else {
        await prefs.remove('sb_access_token');
      }
      if (_refreshToken != null) {
        await prefs.setString('sb_refresh_token', _refreshToken!);
      } else {
        await prefs.remove('sb_refresh_token');
      }
      if (_authUser != null) {
        await prefs.setString('sb_user', jsonEncode(_authUser));
      } else {
        await prefs.remove('sb_user');
      }
    } catch (e) {
      SecureLogger.warning('⚠️ 保存 Supabase Auth 会话失败: $e');
    }
  }

  /// 退出登录
  Future<void> signOut() async {
    try {
      // 清除 Supabase Auth 状态
      _accessToken = null;
      _refreshToken = null;
      _authUser = null;

      // 清除 HttpClient
      HttpClient.instance.setAccessToken(null);

      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sb_access_token');
      await prefs.remove('sb_refresh_token');
      await prefs.remove('sb_user');
    } catch (e) {
      SecureLogger.error('Sign out error');
    }
  }

  /// 重新加载当前用户数据
  Future<bool> reloadCurrentUser() async {
    try {
      final user = await refreshAuthUser();
      return user != null;
    } catch (e) {
      SecureLogger.error('reloadCurrentUser error');
      return false;
    }
  }

  /// 修改密码（Supabase Auth）
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      if (_accessToken == null) {
        return {'success': false, 'message': '未登录，无法修改密码'};
      }

      // 使用 Supabase Auth API 更新密码
      final response = await http.put(
        Uri.parse('$_authUrl/user'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        SecureLogger.log('✅ 密码修改成功');
        return {'success': true, 'message': '密码修改成功'};
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        return {
          'success': false,
          'message': error?['msg'] as String? ?? '密码修改失败，请重试',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '修改密码出错: $e'};
    }
  }

  /// 获取当前用户的认证 Headers
  Map<String, String> get authHeaders => {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${_accessToken ?? SupabaseConfig.anonKey}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // ==================== HTTP 请求工具 ====================

  /// 生成缓存 key
  String _cacheKey(String method, String url, Map<String, String>? headers, Object? body) {
    return '$method|$url|${jsonEncode(headers)}|${jsonEncode(body)}';
  }

  /// 通用 HTTP 请求方法
  Future<http.Response> httpRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
    bool useCache = false,
  }) async {
    final mergedHeaders = {
      ...authHeaders,
      ...?headers,
    };

    final cacheKey = _cacheKey(method, url, mergedHeaders, body);

    // 检查缓存（仅 GET）
    if (method.toUpperCase() == 'GET' && useCache) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired(_cacheTtl)) {
        SecureLogger.log('📦 缓存命中');
        return cached.response;
      }
    }

    // 执行请求（带重试）
    http.Response? response;
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final uri = Uri.parse(url);
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: mergedHeaders);
            break;
          case 'POST':
            response = await http.post(uri, headers: mergedHeaders, body: body);
            break;
          case 'PATCH':
            response = await http.patch(uri, headers: mergedHeaders, body: body);
            break;
          case 'PUT':
            response = await http.put(uri, headers: mergedHeaders, body: body);
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: mergedHeaders);
            break;
          default:
            throw Exception('不支持的 HTTP 方法: $method');
        }

        // 处理 401
        if (response.statusCode == 401) {
          _authUser = null;
          _accessToken = null;
          _refreshToken = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('sb_access_token');
          await prefs.remove('sb_refresh_token');
          await prefs.remove('sb_user');
          throw Exception('401_UNAUTHORIZED');
        }

        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }

    if (response == null) {
      throw lastError ?? Exception('请求失败: $method $url');
    }

    // 缓存 GET 响应
    if (method.toUpperCase() == 'GET' && useCache && response.statusCode >= 200 && response.statusCode < 300) {
      _cache[cacheKey] = _CacheEntry(response, DateTime.now());
    }

    return response;
  }

  /// 清除请求缓存
  void clearCache() {
    _cache.clear();
    SecureLogger.log('🧹 请求缓存已清除');
  }
}

// 为了兼容旧代码，保留别名
typedef SupabaseService = AuthService;
