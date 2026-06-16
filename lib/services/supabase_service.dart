import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// 缓存条目
class _CacheEntry {
  final http.Response response;
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

/// 用户认证服务
/// 完全绕过 Supabase Auth，直接使用自定义 users 表进行认证
class AuthService {
  static AuthService? _instance;

  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  Map<String, dynamic>? _user;

  /// 请求缓存（仅 GET 请求）
  final Map<String, _CacheEntry> _cache = {};

  /// 缓存有效期
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// 最大重试次数
  static const int _maxRetries = 3;

  /// 获取当前用户ID
  String? get currentUserId => _user?['id'];

  /// 获取当前用户邮箱
  String? get currentUserEmail => _user?['email'];

  /// 获取当前用户名
  String? get currentUserName =>
      _user?['nickname'] ??
      _user?['email']?.split('@').first;

  /// 获取当前用户头像
  String? get currentUserAvatar => _user?['avatar_url'];

  /// 检查是否已登录
  bool get isAuthenticated => _user != null;

  /// 获取当前用户积分
  int? get currentPoints => _user?['points'] as int?;

  /// 获取当前用户角色
  String? get currentRole => _user?['role'] as String?;

  /// 获取当前用户会员等级
  String? get currentMemberLevel => _user?['member_level'] as String?;

  /// 对密码进行 SHA-256 哈希
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// 生成用户ID（与管理后台格式一致）
  /// 格式：U + 时间戳(10位) + 随机码(6位) + 校验码(2位)
  String _generateUserId() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString()
        .padLeft(10, '0');
    final random = List.generate(
      6,
      (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[Random().nextInt(36)],
    ).join();

    // 校验码
    int sum = 0;
    for (int i = 0; i < (timestamp + random).length; i++) {
      sum += (timestamp + random).codeUnitAt(i);
    }
    final checksum = (sum % 100).toString().padLeft(2, '0');

    return 'U$timestamp$random$checksum';
  }

  /// 初始化（从本地存储恢复会话，并静默刷新用户信息）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _user = jsonDecode(userJson);
      // 静默刷新用户信息（不阻塞启动）
      _silentRefreshUser();
    }
  }

  /// 静默刷新用户信息（从服务器获取最新数据）
  Future<void> _silentRefreshUser() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final result = await ApiClient.get(
        'users',
        filters: {'id': 'eq.$userId'},
        select: 'id,email,nickname,phone,role,member_level,points,status,avatar_url,login_count',
      );

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        await _saveUser(result.data!.first);
        debugPrint('✅ 用户信息已静默刷新');
      }
    } catch (e) {
      debugPrint('⚠️ 静默刷新用户信息失败: $e');
      // 静默失败不影响使用，继续使用本地缓存
    }
  }

  /// 保存用户信息到本地
  Future<void> _saveUser(Map<String, dynamic> userData) async {
    _user = userData;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user));
  }

  /// 通过邮箱+密码登录
  /// 直接查询 users 表验证邮箱+密码
  Future<bool> signIn(String email, String password) async {
    try {
      final passwordHash = _hashPassword(password);

      debugPrint('🔐 登录请求: email=$email, hash=${passwordHash.substring(0, 8)}...');

      final result = await ApiClient.get(
        'users',
        filters: {
          'email': 'eq.$email',
          'password_hash': 'eq.$passwordHash',
        },
        select: 'id,email,nickname,phone,role,member_level,points,status,avatar_url,login_count',
      );

      debugPrint('🔐 登录响应: isSuccess=${result.isSuccess}, data=${result.data}');

      if (result.isSuccess) {
        final users = result.data;
        if (users == null || users.isEmpty) {
          debugPrint('❌ 邮箱或密码错误');
          return false;
        }

        final user = users.first;

        // 检查用户状态
        if (user['status'] != 'active') {
          debugPrint('❌ 用户已被禁用: ${user['status']}');
          return false;
        }

        await _saveUser(user);

        // 更新最后登录信息
        await ApiClient.patch(
          'users',
          filters: {'id': 'eq.${user['id']}'},
          body: {
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'login_count': (user['login_count'] ?? 0) + 1,
          },
        );

        debugPrint('✅ 登录成功: ${user['nickname']}');
        return true;
      } else {
        debugPrint('❌ 登录失败: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      return false;
    }
  }

  /// 统一账号登录（用户名/昵称/邮箱/手机号 + 密码）
  /// 自动识别账号类型并查询对应字段
  Future<bool> signInWithAccount({
    required String account,
    required String password,
  }) async {
    try {
      final passwordHash = _hashPassword(password);

      debugPrint('🔐 账号登录: account=$account, hash=${passwordHash.substring(0, 8)}...');

      // 判断账号类型
      final accountType = _detectAccountType(account);
      String queryField;

      switch (accountType) {
        case 'email':
          queryField = 'email';
          break;
        case 'phone':
          queryField = 'phone';
          break;
        case 'username':
        default:
          // 用户名或昵称，使用 or 查询
          return await _signInWithUsernameOrNickname(
            account: account,
            passwordHash: passwordHash,
          );
      }

      // 邮箱或手机号直接查询
      final result = await ApiClient.get(
        'users',
        filters: {
          queryField: 'eq.${Uri.encodeComponent(account)}',
          'password_hash': 'eq.$passwordHash',
        },
        select: 'id,email,nickname,phone,role,member_level,points,status,avatar_url',
      );

      return await _processLoginResult(result);
    } catch (e) {
      debugPrint('❌ signInWithAccount error: $e');
      return false;
    }
  }

  /// 检测账号类型
  String _detectAccountType(String account) {
    // 邮箱格式
    if (RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(account)) {
      return 'email';
    }
    // 手机号格式
    if (RegExp(r'^1[3-9]\d{9}$').hasMatch(account)) {
      return 'phone';
    }
    // 默认用户名/昵称
    return 'username';
  }

  /// 通过用户名或昵称登录（使用 or 查询）
  Future<bool> _signInWithUsernameOrNickname({
    required String account,
    required String passwordHash,
  }) async {
    try {
      // 使用 or 查询：username=account or nickname=account
      final result = await ApiClient.get(
        'users',
        filters: {
          'or': '(username.eq.${Uri.encodeComponent(account)},nickname.eq.${Uri.encodeComponent(account)})',
          'password_hash': 'eq.$passwordHash',
        },
        select: 'id,email,nickname,phone,role,member_level,points,status,avatar_url',
      );

      return await _processLoginResult(result);
    } catch (e) {
      debugPrint('❌ _signInWithUsernameOrNickname error: $e');
      return false;
    }
  }

  /// 处理登录响应
  Future<bool> _processLoginResult(ApiResponse<List<Map<String, dynamic>>> result) async {
    debugPrint('🔐 登录响应: isSuccess=${result.isSuccess}, data=${result.data}');

    if (result.isSuccess) {
      final users = result.data;
      if (users == null || users.isEmpty) {
        debugPrint('❌ 账号或密码错误');
        return false;
      }

      final user = users.first;

      if (user['status'] != 'active') {
        debugPrint('❌ 用户已被禁用: ${user['status']}');
        return false;
      }

      await _saveUser(user);

      await ApiClient.patch(
        'users',
        filters: {'id': 'eq.${user['id']}'},
        body: {
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
          'login_count': (user['login_count'] ?? 0) + 1,
        },
      );

      debugPrint('✅ 登录成功: ${user['nickname']}');
      return true;
    } else {
      debugPrint('❌ 登录失败: ${result.errorMessage}');
      return false;
    }
  }

  /*
  // ============================================
  // 验证码登录相关方法（已注释，待对接短信平台后启用）
  // ============================================

  /// 通过手机号+验证码登录
  /// 先验证验证码，再通过手机号查找用户并登录
  Future<bool> signInWithPhoneCode(String phone, String code) async {
    try {
      // 验证验证码
      final verifyResponse = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&sms_code=eq.$code&select=id,email,nickname,phone,role,member_level,points,status,avatar_url,sms_code_expires_at',
        ),
        headers: SupabaseConfig.headers,
      );

      if (verifyResponse.statusCode == 200) {
        final users = jsonDecode(verifyResponse.body) as List;
        if (users.isEmpty) {
          debugPrint('验证码错误或手机号未注册');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;
        final expiresAt = user['sms_code_expires_at'] as String?;

        // 检查验证码是否过期
        if (expiresAt != null) {
          final expires = DateTime.parse(expiresAt);
          if (DateTime.now().toUtc().isAfter(expires)) {
            debugPrint('验证码已过期');
            return false;
          }
        }

        // 检查用户状态
        if (user['status'] != 'active') {
          debugPrint('用户已被禁用');
          return false;
        }

        await _saveUser(user);

        // 更新最后登录信息
        await http.patch(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/users?id=eq.${user['id']}',
          ),
          headers: SupabaseConfig.writeHeaders,
          body: jsonEncode({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'login_count': (user['login_count'] ?? 0) + 1,
          }),
        );

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('signInWithPhoneCode error: $e');
      return false;
    }
  }

  /// 发送短信验证码
  /// 生成6位随机验证码，保存到 users 表，有效期5分钟
  Future<bool> sendSmsCode(String phone) async {
    try {
      // 生成6位随机验证码
      final random = Random();
      final code = List.generate(6, (_) => random.nextInt(10)).join();

      // 计算过期时间（5分钟后）
      final expiresAt =
          DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

      // 先检查用户是否存在
      final checkResponse = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&select=id',
        ),
        headers: SupabaseConfig.headers,
      );

      if (checkResponse.statusCode == 200) {
        final users = jsonDecode(checkResponse.body) as List;

        if (users.isNotEmpty) {
          // 用户存在，更新验证码
          final userId = users[0]['id'];
          final updateResponse = await http.patch(
            Uri.parse('${SupabaseConfig.url}/rest/v1/users?id=eq.$userId'),
            headers: SupabaseConfig.writeHeaders,
            body: jsonEncode({
              'sms_code': code,
              'sms_code_expires_at': expiresAt,
            }),
          );

          if (updateResponse.statusCode == 200 ||
              updateResponse.statusCode == 204) {
            debugPrint('验证码已发送到 $phone: $code');
            return true;
          }
        } else {
          // 用户不存在，也可以发送验证码（注册场景）
          debugPrint('手机号未注册，验证码: $code');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('sendSmsCode error: $e');
      return false;
    }
  }
  */

  /// 注册（包含用户名、邮箱、手机号）
  /// 直接 INSERT 到 users 表，密码使用 SHA-256 哈希
  Future<bool> signUp({
    required String username,
    required String password,
    String? email,
    String? phone,
  }) async {
    try {
      final passwordHash = _hashPassword(password);
      final userId = _generateUserId();
      final now = DateTime.now().toUtc().toIso8601String();

      final userEmail = email ?? '${username}_${DateTime.now().millisecondsSinceEpoch}@pureenjoy.local';

      debugPrint('📝 注册请求: username=$username, email=$userEmail, hash=${passwordHash.substring(0, 8)}...');

      final userData = {
        'id': userId,
        'email': userEmail,
        'password_hash': passwordHash,
        'phone': phone,
        'nickname': username,
        'avatar_url': null,
        'role': 'user',
        'member_level': 'normal',
        'points': 0,
        'status': 'active',
        'register_ip': null,
        'last_login_ip': null,
        'last_login_at': now,
        'login_count': 1,
        'created_at': now,
        'updated_at': now,
      };

      final response = await ApiClient.post(
        'users',
        body: userData,
        returnRepresentation: true,
      );

      debugPrint('📝 注册响应: isSuccess=${response.isSuccess}, data=${response.data}');

      if (response.isSuccess) {
        await _saveUser(userData);
        debugPrint('✅ 注册成功: $username');
        return true;
      } else {
        debugPrint('❌ 注册失败: ${response.errorMessage}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      return false;
    }
  }

  /// 注册（保留原有方法签名，兼容旧代码）
  Future<bool> signUpOld(String email, String password, {String? name}) async {
    return signUp(
      username: name ?? email.split('@').first,
      password: password,
      email: email,
    );
  }

  /// 退出登录
  Future<void> signOut() async {
    try {
      // 不再调用 Supabase Auth 的 logout 端点
      // 直接清除本地会话
    } catch (e) {
      debugPrint('Sign out error: $e');
    } finally {
      _user = null;

      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
    }
  }

  /// 重新从 Supabase 加载当前用户数据
  /// 编辑资料后调用此方法刷新本地缓存
  Future<bool> reloadCurrentUser() async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final result = await ApiClient.get(
        'users',
        filters: {'id': 'eq.$userId'},
        select: 'id,email,nickname,phone,role,member_level,points,status,avatar_url',
      );

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        await _saveUser(result.data!.first);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('reloadCurrentUser error: $e');
      return false;
    }
  }

  /// 修改密码
  /// 需要验证旧密码，然后更新为新密码
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {'success': false, 'message': '未登录，无法修改密码'};
      }

      // 1. 验证旧密码
      final oldPasswordHash = _hashPassword(oldPassword);
      final verifyResult = await ApiClient.get(
        'users',
        filters: {
          'id': 'eq.$userId',
          'password_hash': 'eq.$oldPasswordHash',
        },
        select: 'id',
      );

      if (!verifyResult.isSuccess) {
        return {'success': false, 'message': '验证旧密码失败，请重试'};
      }

      final users = verifyResult.data;
      if (users == null || users.isEmpty) {
        return {'success': false, 'message': '旧密码不正确'};
      }

      // 2. 更新为新密码
      final newPasswordHash = _hashPassword(newPassword);
      final updateResult = await ApiClient.patch(
        'users',
        filters: {'id': 'eq.$userId'},
        body: {
          'password_hash': newPasswordHash,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (updateResult.isSuccess) {
        debugPrint('✅ 密码修改成功: $userId');
        return {'success': true, 'message': '密码修改成功'};
      } else {
        debugPrint('❌ 密码修改失败: ${updateResult.errorMessage}');
        return {'success': false, 'message': '密码修改失败，请重试'};
      }
    } catch (e) {
      debugPrint('❌ 修改密码出错: $e');
      return {'success': false, 'message': '修改密码出错: $e'};
    }
  }

  /// 获取当前用户的认证 Headers
  /// 不再使用 Supabase Auth 的 JWT token，使用 anon key
  Map<String, String> get authHeaders => {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
    // 自定义 header 传递当前用户ID（供 RLS 或业务逻辑使用）
    if (_user?['id'] != null) 'x-user-id': _user!['id'] as String,
  };

  /// 生成缓存 key
  String _cacheKey(String method, String url, Map<String, String>? headers, Object? body) {
    return '$method|$url|${jsonEncode(headers)}|${jsonEncode(body)}';
  }

  /// 通用 HTTP 请求方法
  /// - 自动添加 authHeaders
  /// - 自动处理 401 错误（token 过期，此处为静默刷新用户信息）
  /// - 自动重试机制（最多3次）
  /// - GET 请求缓存（5分钟）
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

    // 1. 检查缓存（仅 GET 请求）
    if (method.toUpperCase() == 'GET' && useCache) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired(_cacheTtl)) {
        debugPrint('📦 缓存命中: $url');
        return cached.response;
      }
    }

    // 2. 执行请求（带重试）
    http.Response? response;
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('🌐 HTTP $method $url (attempt $attempt)');

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

        // 3. 处理 401 未授权（用户未登录或会话过期）
        if (response.statusCode == 401) {
          debugPrint('🔒 收到 401，用户未登录或会话过期');
          // 清除本地用户状态，触发重新登录
          _user = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user');
          // 抛出401异常，由上层处理跳转登录页
          throw Exception('401_UNAUTHORIZED');
        }

        // 4. 请求成功，跳出重试循环
        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('⚠️ 请求失败 (attempt $attempt): $e');

        if (attempt < _maxRetries) {
          // 指数退避：1s, 2s, 4s
          final delay = Duration(seconds: 1 << (attempt - 1));
          debugPrint('⏳ ${_maxRetries - attempt} 秒后重试...');
          await Future.delayed(delay);
        }
      }
    }

    // 5. 所有重试都失败
    if (response == null) {
      throw lastError ?? Exception('请求失败: $method $url');
    }

    // 6. 缓存 GET 请求响应
    if (method.toUpperCase() == 'GET' && useCache && response.statusCode >= 200 && response.statusCode < 300) {
      _cache[cacheKey] = _CacheEntry(response, DateTime.now());
      debugPrint('💾 缓存已更新: $url');
    }

    return response;
  }

  /// 清除请求缓存
  void clearCache() {
    _cache.clear();
    debugPrint('🧹 请求缓存已清除');
  }
}

// 为了兼容旧代码，保留别名
typedef SupabaseService = AuthService;
