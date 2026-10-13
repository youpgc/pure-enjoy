import 'dart:convert';
import '../constants/app_constants.dart';
import './supabase_config.dart';
import './server_config.dart';
import './http_client.dart';

/// 纯认证 API：负责与自建后端（Spring Boot）认证端点的所有通信
///
/// change-server 分支：认证平面由 Supabase Auth 切换为本地后端
/// （POST /api/v1/auth/login|register|refresh、GET /api/v1/auth/me）。
///
/// 不包含任何会话管理逻辑，仅返回结果。
/// 调用方（AuthService）负责将结果保存到 SessionManager。
///
/// 对外仍返回 [SupabaseAuthResponse]（字段映射兼容），下游无需感知协议切换：
/// - 后端 TokenVO.accessToken/refreshToken → accessToken/refreshToken
/// - 后端 LoginUserVO → user + user_metadata（snake_case，与 Supabase 形态一致）
class AuthApi {
  static AuthApi? _instance;
  AuthApi._();

  static AuthApi get instance {
    _instance ??= AuthApi._();
    return _instance!;
  }

  String get _apiBase => '${ServerConfig.baseUrl}/api/v1';

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  /// 后端统一响应体 {code, message, data} → SupabaseAuthResponse
  SupabaseAuthResponse _parseEnvelope(String body, String fallbackMsg) {
    try {
      final envelope = jsonDecode(body) as Map<String, dynamic>;
      final code = envelope['code'];
      if (code == 200) {
        final data = envelope['data'];
        if (data is Map<String, dynamic>) {
          return SupabaseAuthResponse(
            accessToken: data['access_token'] as String?,
            refreshToken: data['refresh_token'] as String?,
            user: data['user'] is Map<String, dynamic>
                ? data['user'] as Map<String, dynamic>
                : null,
          );
        }
        return SupabaseAuthResponse();
      }
      return SupabaseAuthResponse(
        error: (envelope['message'] as String?) ?? fallbackMsg,
      );
    } catch (_) {
      return SupabaseAuthResponse(error: fallbackMsg);
    }
  }

  /// 后端 LoginUserVO → 认证用户 Map（含合成 user_metadata，snake_case 兼容）
  Map<String, dynamic> _loginUserVoToAuthUser(Map<String, dynamic> vo) {
    return {
      'id': vo['id'],
      'email': vo['email'],
      'username': vo['username'],
      'phone': vo['phone'],
      'user_metadata': {
        'role': vo['role'] ?? roleUser,
        'username': vo['username'],
        'nickname': vo['nickname'],
        if (vo['avatar_url'] != null) 'avatar_url': vo['avatar_url'],
      },
    };
  }

  /// 拉取当前登录主体（GET /auth/me），失败返回 null
  Future<Map<String, dynamic>?> _fetchMe(String accessToken) async {
    try {
      final response = await HttpClient.instance.rawRequest(
        '$_apiBase/auth/me',
        method: 'GET',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        timeout: RequestTimeout.simple,
        note: '获取当前登录主体',
      );
      if (response.statusCode != 200) return null;
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      if (envelope['code'] != 200) return null;
      final data = envelope['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return _loginUserVoToAuthUser(data);
    } catch (e) {
      SecureLogger.warning(
          '⚠️ 获取当前主体失败: ${SecureLogger.extractError(e)}');
      return null;
    }
  }

  /// 统一账号登录（邮箱 / 手机号 / 用户名 + 密码）
  ///
  /// 三标识识别与匹配由后端完成（AccountType 自动判定），App 无需预解析。
  Future<SupabaseAuthResponse> signInWithAccount({
    required String account,
    required String password,
  }) async {
    return _login(account: account, password: password);
  }

  /// 邮箱+密码登录（兼容旧调用方，内部同统一登录）
  Future<SupabaseAuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _login(account: email, password: password);
  }

  Future<SupabaseAuthResponse> _login({
    required String account,
    required String password,
  }) async {
    try {
      SecureLogger.log('🔐 后端登录请求: ${ServerConfig.baseUrl}');
      final response = await HttpClient.instance.rawRequest(
        '$_apiBase/auth/login',
        method: 'POST',
        headers: _jsonHeaders,
        body: {'account': account, 'password': password, 'realm': 'app'},
        timeout: RequestTimeout.simple,
        note: '账号密码登录',
      );

      SecureLogger.log('🔐 响应码: ${response.statusCode}');
      final result = _parseEnvelope(
          response.body, response.statusCode == 401 ? '账号或密码错误' : '登录失败');
      if (!result.success) {
        SecureLogger.log('❌ 登录失败: ${result.error}');
        return result;
      }

      // TokenVO 不含用户信息，补充 /auth/me 合成 user（失败不阻断登录）
      final user = await _fetchMe(result.accessToken!);
      return SupabaseAuthResponse(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: user,
      );
    } catch (e) {
      SecureLogger.error('❌ 登录异常: ${e.runtimeType} - ${SecureLogger.extractError(e)}');
      return SupabaseAuthResponse(
          error: '登录失败：${SecureLogger.extractError(e)}');
    }
  }

  /// 注册（邮箱 / 手机号 / 用户名三选一 + 密码 + 昵称）
  ///
  /// 唯一性与合法性由后端 register 校验；注册成功后自动登录换取 token。
  Future<SupabaseAuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    try {
      SecureLogger.log('📝 后端注册请求');
      final response = await HttpClient.instance.rawRequest(
        '$_apiBase/auth/register',
        method: 'POST',
        headers: _jsonHeaders,
        body: {
          'account': email,
          'password': password,
          if (username != null && username.isNotEmpty) 'nickname': username,
        },
        timeout: RequestTimeout.simple,
        note: '注册新账号',
      );

      final result = _parseEnvelope(response.body, '注册失败');
      if (result.error != null) {
        // 后端 register 校验失败（账号已存在/格式非法等）
        return result;
      }

      // 注册成功 → 自动登录
      SecureLogger.log('✅ 注册成功，自动登录');
      return await _login(account: email, password: password);
    } catch (e) {
      return SupabaseAuthResponse(
          error: '注册失败：${SecureLogger.extractError(e)}');
    }
  }

  /// 刷新 Token（POST /auth/refresh）
  Future<SupabaseAuthResponse> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await HttpClient.instance.rawRequest(
        '$_apiBase/auth/refresh',
        method: 'POST',
        headers: _jsonHeaders,
        body: {'refresh_token': refreshToken},
        timeout: RequestTimeout.simple,
        note: '刷新访问令牌',
      );

      if (response.statusCode != 200) {
        return SupabaseAuthResponse(error: '刷新Token失败');
      }
      final result = _parseEnvelope(response.body, '刷新Token失败');
      if (!result.success) return result;
      // 刷新后旧 access token 已失效，无法再查 me；user 留空由调用方重新拉取
      return SupabaseAuthResponse(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    } catch (e) {
      SecureLogger.warning(
          '⚠️ 刷新Token失败: ${SecureLogger.extractError(e)}');
      return SupabaseAuthResponse(error: '刷新Token失败');
    }
  }

  /// 获取当前用户信息（GET /auth/me，需要 accessToken）
  Future<Map<String, dynamic>?> fetchUser({
    required String accessToken,
  }) async {
    return _fetchMe(accessToken);
  }

  /// 修改密码（PUT /users/me/password，需要 accessToken）
  Future<Map<String, dynamic>> changePassword({
    required String accessToken,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await HttpClient.instance.rawRequest(
        '$_apiBase/users/me/password',
        method: 'PUT',
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: {'old_password': oldPassword, 'new_password': newPassword},
        timeout: RequestTimeout.simple,
        note: '修改密码',
      );

      if (response.statusCode == 200) {
        SecureLogger.log('✅ 密码修改成功');
        return {'success': true, 'message': '密码修改成功'};
      }
      final error = _parseEnvelope(response.body, '密码修改失败，请重试');
      return {'success': false, 'message': error.error ?? '密码修改失败，请重试'};
    } catch (e) {
      return {
        'success': false,
        'message': '修改密码失败：${SecureLogger.extractError(e)}',
      };
    }
  }
}
