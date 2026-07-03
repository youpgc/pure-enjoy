import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'supabase_config.dart';

/// 纯认证 API：负责与 Supabase Auth 端点的所有通信
///
/// 不包含任何会话管理逻辑，仅返回结果。
/// 调用方（AuthService）负责将结果保存到 SessionManager。
class AuthApi {
  static AuthApi? _instance;
  AuthApi._();

  static AuthApi get instance {
    _instance ??= AuthApi._();
    return _instance!;
  }

  String get _authUrl => '${SupabaseConfig.url}/auth/v1';

  Map<String, String> get _anonHeaders => {
        'apikey': SupabaseConfig.anonKey,
        'Content-Type': 'application/json',
      };

  /// 从 Supabase Auth 响应中提取标准结构
  SupabaseAuthResponse _parseAuthResponse(dynamic data) {
    return SupabaseAuthResponse(
      accessToken: data['access_token'] as String?,
      refreshToken: data['refresh_token'] as String?,
      user: data['user'] as Map<String, dynamic>?,
    );
  }

  SupabaseAuthResponse _parseError(String body, String fallbackMsg) {
    try {
      final error = jsonDecode(body) as Map<String, dynamic>?;
      return SupabaseAuthResponse(
        error: error?['msg'] as String? ??
            error?['error_description'] as String? ??
            fallbackMsg,
      );
    } catch (_) {
      return SupabaseAuthResponse(error: fallbackMsg);
    }
  }

  /// 邮箱+密码登录
  Future<SupabaseAuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      SecureLogger.log('🔐 Supabase Auth 登录请求');
      SecureLogger.log('🔐 URL: $_authUrl/token?grant_type=password');
      SecureLogger.log('🔐 Email: $email');

      final response = await http.post(
        Uri.parse('$_authUrl/token?grant_type=password'),
        headers: _anonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      );

      SecureLogger.log('🔐 响应码: ${response.statusCode}');
      if (response.statusCode == 200) {
        final result = _parseAuthResponse(jsonDecode(response.body));
        SecureLogger.log('✅ 登录成功, userId: ${result.userId}');
        return result;
      }
      SecureLogger.log('❌ 登录失败, body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      return _parseError(response.body, '登录失败');
    } catch (e) {
      SecureLogger.error('❌ 登录异常: ${e.runtimeType} - ${SecureLogger.extractError(e)}');
      return SupabaseAuthResponse(
          error: '登录失败：${SecureLogger.extractError(e)}');
    }
  }

  /// 统一账号登录（邮箱/手机号/用户名/昵称 + 密码）
  Future<SupabaseAuthResponse> signInWithAccount({
    required String account,
    required String password,
  }) async {
    try {
      final accountType = _detectAccountType(account);
      SecureLogger.log('🔐 统一账号登录，类型: $accountType');

      String email;
      if (accountType == 'email') {
        email = account;
      } else {
        SecureLogger.log('🔐 开始解析账号: $account (类型: $accountType)');
      final resolved = await _resolveAccountToEmail(account, accountType);
        if (resolved == null) {
          SecureLogger.log('❌ 未找到账号对应用户');
          return SupabaseAuthResponse(error: '未找到该账号对应的用户');
        }
        SecureLogger.log('✅ 解析成功: $account -> $resolved');
        email = resolved;
      }

      return await signInWithEmail(email: email, password: password);
    } catch (e) {
      return SupabaseAuthResponse(
          error: '登录失败：${SecureLogger.extractError(e)}');
    }
  }

  /// 注册
  Future<SupabaseAuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    try {
      SecureLogger.log('📝 Supabase Auth 注册请求');

      // 校验用户名唯一性
      if (username != null && username.isNotEmpty) {
        final exists = await _checkFieldExists('username', username);
        if (exists) {
          return SupabaseAuthResponse(error: '用户名已被使用');
        }
      }

      // 校验手机号唯一性
      if (phone != null && phone.isNotEmpty) {
        final exists = await _checkFieldExists('phone', phone);
        if (exists) {
          return SupabaseAuthResponse(error: '手机号已被使用');
        }
      }

      final response = await http.post(
        Uri.parse('$_authUrl/signup'),
        headers: _anonHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {
            if (username != null) 'username': username,
            if (phone != null) 'phone': phone,
            'role': roleUser,
          },
        }),
      );

      if (response.statusCode == 200) {
        return _parseAuthResponse(jsonDecode(response.body));
      }
      return _parseError(response.body, '注册失败');
    } catch (e) {
      return SupabaseAuthResponse(
          error: '注册失败：${SecureLogger.extractError(e)}');
    }
  }

  /// 刷新 Token
  Future<SupabaseAuthResponse> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_authUrl/token?grant_type=refresh_token'),
        headers: _anonHeaders,
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        return _parseAuthResponse(jsonDecode(response.body));
      }
      return SupabaseAuthResponse(error: '刷新Token失败');
    } catch (e) {
      SecureLogger.warning(
          '⚠️ 刷新Token失败: ${SecureLogger.extractError(e)}');
      return SupabaseAuthResponse(error: '刷新Token失败');
    }
  }

  /// 获取当前用户信息（需要 accessToken）
  Future<Map<String, dynamic>?> fetchUser({
    required String accessToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_authUrl/user'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      SecureLogger.warning(
          '⚠️ 获取用户信息失败: ${SecureLogger.extractError(e)}');
      return null;
    }
  }

  /// 修改密码（需要 accessToken）
  Future<Map<String, dynamic>> changePassword({
    required String accessToken,
    required String newPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_authUrl/user'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': newPassword}),
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
      return {
        'success': false,
        'message': '修改密码失败：${SecureLogger.extractError(e)}',
      };
    }
  }

  // ==================== 账号解析 ====================

  String _detectAccountType(String account) {
    if (RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(account)) {
      return 'email';
    }
    if (RegExp(r'^1[3-9]\d{9}$').hasMatch(account)) return 'phone';
    return 'username';
  }

  Future<String?> _resolveAccountToEmail(
      String account, String type) async {
    try {
      SecureLogger.log('🔐 解析类型: $type, 账号: $account');
      final filter = type == 'phone'
          ? 'phone=eq.$account'
          : 'username=eq.$account';

      final response = await http.get(
        Uri.parse(
            '${SupabaseConfig.url}/rest/v1/users?$filter&select=email'),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return data[0]['email'] as String?;
        }
        return null;
      }
      SecureLogger.warning(
          '⚠️ 查询用户信息失败: ${response.statusCode}');
      return null;
    } catch (e) {
      SecureLogger.warning(
          '⚠️ 解析账号异常: ${SecureLogger.extractError(e)}');
      return null;
    }
  }

  // ==================== 唯一性校验 ====================

  /// 检查 users 表中指定字段是否已存在（用于注册校验）
  Future<bool> _checkFieldExists(String field, String value) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?$field=eq.${Uri.encodeComponent(value)}&select=id',
        ),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.isNotEmpty;
      }
      return false;
    } catch (e) {
      SecureLogger.warning(
          '⚠️ 校验字段唯一性异常: ${SecureLogger.extractError(e)}');
      return false;
    }
  }
}
