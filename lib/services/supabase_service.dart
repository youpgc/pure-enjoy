import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// 获取当前用户ID
  String? get currentUserId => _user?['id'];

  /// 获取当前用户邮箱
  String? get currentUserEmail => _user?['email'];

  /// 获取当前用户名
  String? get currentUserName =>
      _user?['nickname'] ??
      _user?['email']?.split('@').first;

  /// 检查是否已登录
  bool get isAuthenticated => _user != null;

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

  /// 初始化（从本地存储恢复会话）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _user = jsonDecode(userJson);
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

      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?email=eq.$email&password_hash=eq.$passwordHash&select=id,email,nickname,phone,role,member_level,points,status,avatar_url,login_count',
        ),
        headers: SupabaseConfig.headers,
      );

      debugPrint('🔐 登录响应: statusCode=${response.statusCode}, body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isEmpty) {
          debugPrint('❌ 邮箱或密码错误');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;

        // 检查用户状态
        if (user['status'] != 'active') {
          debugPrint('❌ 用户已被禁用: ${user['status']}');
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

        debugPrint('✅ 登录成功: ${user['nickname']}');
        return true;
      } else {
        debugPrint('❌ 登录失败: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      return false;
    }
  }

  /// 通过用户名+密码登录
  /// 注意: users 表没有 username 字段，此方法改用 nickname 查询
  Future<bool> signInWithUsername(String username, String password) async {
    try {
      final passwordHash = _hashPassword(password);

      debugPrint('🔐 用户名登录: nickname=$username, hash=${passwordHash.substring(0, 8)}...');

      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?nickname=eq.$username&password_hash=eq.$passwordHash&select=id,email,nickname,phone,role,member_level,points,status,avatar_url',
        ),
        headers: SupabaseConfig.headers,
      );

      debugPrint('🔐 用户名登录响应: statusCode=${response.statusCode}, body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isEmpty) {
          debugPrint('❌ 用户名或密码错误');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;

        if (user['status'] != 'active') {
          debugPrint('❌ 用户已被禁用: ${user['status']}');
          return false;
        }

        await _saveUser(user);

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

        debugPrint('✅ 用户名登录成功: ${user['nickname']}');
        return true;
      } else {
        debugPrint('❌ 用户名登录失败: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ signInWithUsername error: $e');
      return false;
    }
  }

  /// 通过手机号+密码登录
  /// 先通过 users 表查询手机号对应的用户，再用密码验证
  Future<bool> signInWithPhone(String phone, String password) async {
    try {
      final passwordHash = _hashPassword(password);

      // 直接通过手机号+密码哈希查询
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&password_hash=eq.$passwordHash&select=id,email,nickname,phone,role,member_level,points,status,avatar_url',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isEmpty) {
          debugPrint('手机号或密码错误');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;

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
      debugPrint('signInWithPhone error: $e');
      return false;
    }
  }

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

      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/users'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode(userData),
      );

      debugPrint('📝 注册响应: statusCode=${response.statusCode}, body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveUser(userData);
        debugPrint('✅ 注册成功: $username');
        return true;
      } else {
        debugPrint('❌ 注册失败: ${response.statusCode} ${response.body}');
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

      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?id=eq.$userId&select=id,email,nickname,phone,role,member_level,points,status,avatar_url',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isNotEmpty) {
          await _saveUser(users[0] as Map<String, dynamic>);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('reloadCurrentUser error: $e');
      return false;
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
}

// 为了兼容旧代码，保留别名
typedef SupabaseService = AuthService;
