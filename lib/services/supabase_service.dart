import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
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
      _user?['username'] ??
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

      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?email=eq.$email&password_hash=eq.$passwordHash&select=id,email,username,nickname,phone,role,member_level,points,status,avatar_url',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isEmpty) {
          print('邮箱或密码错误');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;

        // 检查用户状态
        if (user['status'] != 'active') {
          print('用户已被禁用');
          return false;
        }

        await _saveUser(user);

        // 更新最后登录信息
        await http.patch(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/users?id=eq.${user['id']}',
          ),
          headers: SupabaseConfig.headers,
          body: jsonEncode({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'login_count': (user['login_count'] ?? 0) + 1,
          }),
        );

        return true;
      }
      return false;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }

  /// 通过用户名+密码登录
  /// 先通过 users 表查询用户名对应的邮箱，再用邮箱+密码登录
  Future<bool> signInWithUsername(String username, String password) async {
    try {
      final passwordHash = _hashPassword(password);

      // 直接通过用户名+密码哈希查询
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?username=eq.$username&password_hash=eq.$passwordHash&select=id,email,username,nickname,phone,role,member_level,points,status,avatar_url',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isEmpty) {
          print('用户名或密码错误');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;

        // 检查用户状态
        if (user['status'] != 'active') {
          print('用户已被禁用');
          return false;
        }

        await _saveUser(user);

        // 更新最后登录信息
        await http.patch(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/users?id=eq.${user['id']}',
          ),
          headers: SupabaseConfig.headers,
          body: jsonEncode({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'login_count': (user['login_count'] ?? 0) + 1,
          }),
        );

        return true;
      }

      return false;
    } catch (e) {
      print('signInWithUsername error: $e');
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
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&password_hash=eq.$passwordHash&select=id,email,username,nickname,phone,role,member_level,points,status,avatar_url',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final users = jsonDecode(response.body) as List;
        if (users.isEmpty) {
          print('手机号或密码错误');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;

        // 检查用户状态
        if (user['status'] != 'active') {
          print('用户已被禁用');
          return false;
        }

        await _saveUser(user);

        // 更新最后登录信息
        await http.patch(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/users?id=eq.${user['id']}',
          ),
          headers: SupabaseConfig.headers,
          body: jsonEncode({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'login_count': (user['login_count'] ?? 0) + 1,
          }),
        );

        return true;
      }

      return false;
    } catch (e) {
      print('signInWithPhone error: $e');
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
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&sms_code=eq.$code&select=id,email,username,nickname,phone,role,member_level,points,status,avatar_url,sms_code_expires_at',
        ),
        headers: SupabaseConfig.headers,
      );

      if (verifyResponse.statusCode == 200) {
        final users = jsonDecode(verifyResponse.body) as List;
        if (users.isEmpty) {
          print('验证码错误或手机号未注册');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;
        final expiresAt = user['sms_code_expires_at'] as String?;

        // 检查验证码是否过期
        if (expiresAt != null) {
          final expires = DateTime.parse(expiresAt);
          if (DateTime.now().toUtc().isAfter(expires)) {
            print('验证码已过期');
            return false;
          }
        }

        // 检查用户状态
        if (user['status'] != 'active') {
          print('用户已被禁用');
          return false;
        }

        await _saveUser(user);

        // 更新最后登录信息
        await http.patch(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/users?id=eq.${user['id']}',
          ),
          headers: SupabaseConfig.headers,
          body: jsonEncode({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
            'login_count': (user['login_count'] ?? 0) + 1,
          }),
        );

        return true;
      }

      return false;
    } catch (e) {
      print('signInWithPhoneCode error: $e');
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
            headers: SupabaseConfig.headers,
            body: jsonEncode({
              'sms_code': code,
              'sms_code_expires_at': expiresAt,
            }),
          );

          if (updateResponse.statusCode == 200 ||
              updateResponse.statusCode == 204) {
            print('验证码已发送到 $phone: $code');
            return true;
          }
        } else {
          // 用户不存在，也可以发送验证码（注册场景）
          print('手机号未注册，验证码: $code');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('sendSmsCode error: $e');
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

      final userData = {
        'id': userId,
        'email': email ?? '${username}_${DateTime.now().millisecondsSinceEpoch}@pureenjoy.local',
        'username': username,
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
        headers: SupabaseConfig.headers,
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 注册成功，自动登录
        await _saveUser(userData);
        return true;
      } else {
        print('注册失败: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Sign up error: $e');
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
      print('Sign out error: $e');
    } finally {
      _user = null;

      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
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
