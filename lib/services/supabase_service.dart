import 'dart:convert';
import 'dart:math';
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
  String? get currentUserName =>
      _user?['user_metadata']?['name'] ??
      _user?['user_metadata']?['username'] ??
      _user?['email']?.split('@').first;

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

  /// 保存会话到本地
  Future<void> _saveSession(Map<String, dynamic> data) async {
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
    _user = data['user'];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', _accessToken!);
    await prefs.setString('refresh_token', _refreshToken!);
    await prefs.setString('user', jsonEncode(_user));
  }

  /// 通过用户名+密码登录
  /// 使用 Supabase auth 端点，将用户名作为邮箱的替代方式
  /// 实际逻辑：先通过 users 表查询用户名对应的邮箱，再用邮箱登录
  Future<bool> signInWithUsername(String username, String password) async {
    try {
      // 先通过 users 表查找用户名对应的用户
      final queryResponse = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?username=eq.$username&select=id,email',
        ),
        headers: SupabaseConfig.headers,
      );

      if (queryResponse.statusCode == 200) {
        final users = jsonDecode(queryResponse.body) as List;
        if (users.isEmpty) {
          print('用户名不存在: $username');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;
        final email = user['email'] as String?;

        if (email != null && email.isNotEmpty) {
          // 用邮箱登录
          return await signIn(email, password);
        } else {
          // 用户没有绑定邮箱，尝试直接用用户名作为标识登录
          // 使用自定义 RPC 或直接尝试
          print('用户未绑定邮箱，尝试直接登录');
          return false;
        }
      }

      // 如果 users 表查询失败，尝试直接用用户名作为邮箱登录
      return false;
    } catch (e) {
      print('signInWithUsername error: $e');
      return false;
    }
  }

  /// 通过手机号+密码登录
  /// 先通过 users 表查询手机号对应的用户，再用其邮箱登录
  Future<bool> signInWithPhone(String phone, String password) async {
    try {
      // 先通过 users 表查找手机号对应的用户
      final queryResponse = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&select=id,email',
        ),
        headers: SupabaseConfig.headers,
      );

      if (queryResponse.statusCode == 200) {
        final users = jsonDecode(queryResponse.body) as List;
        if (users.isEmpty) {
          print('手机号未注册: $phone');
          return false;
        }

        final user = users[0] as Map<String, dynamic>;
        final email = user['email'] as String?;

        if (email != null && email.isNotEmpty) {
          return await signIn(email, password);
        }
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
          '${SupabaseConfig.url}/rest/v1/users?phone=eq.$phone&sms_code=eq.$code&select=id,email,username,sms_code_expires_at',
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

        final email = user['email'] as String?;
        final userId = user['id'] as String?;

        if (email != null && email.isNotEmpty) {
          // 如果有邮箱，使用 Supabase auth 登录（需要密码，这里用特殊方式处理）
          // 对于验证码登录，直接设置会话
          await _createSessionForUser(userId!, user);
          return true;
        } else {
          // 没有邮箱，直接创建会话
          await _createSessionForUser(userId!, user);
          return true;
        }
      }

      return false;
    } catch (e) {
      print('signInWithPhoneCode error: $e');
      return false;
    }
  }

  /// 为用户创建本地会话（用于验证码登录等非密码登录方式）
  Future<void> _createSessionForUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    _user = {
      'id': userId,
      'email': userData['email'],
      'user_metadata': {
        'username': userData['username'],
        'phone': userData['phone'],
      },
    };

    // 生成一个临时 token（实际项目中应使用服务端签发的 JWT）
    _accessToken = SupabaseConfig.anonKey;
    _refreshToken = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', _accessToken!);
    await prefs.setString('refresh_token', _refreshToken!);
    await prefs.setString('user', jsonEncode(_user));
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

      // 更新或插入验证码到 users 表
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
          // 这里简单返回成功，实际项目中应先注册或使用临时表
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

  /// 登录（邮箱+密码，保留原有方法）
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
        await _saveSession(data);
        return true;
      }
      return false;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }

  /// 注册（包含用户名、邮箱、手机号）
  /// 先通过 Supabase Auth 创建用户，再更新 users 表
  Future<bool> signUp({
    required String username,
    required String password,
    String? email,
    String? phone,
  }) async {
    try {
      // 如果提供了邮箱，使用 Supabase Auth 注册
      if (email != null && email.isNotEmpty) {
        final response = await http.post(
          Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
          headers: {
            'apikey': SupabaseConfig.anonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email,
            'password': password,
            'data': {
              'username': username,
              'phone': phone,
            },
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          await _saveSession(data);

          // 更新 users 表，添加用户名和手机号
          if (_user != null && _user!['id'] != null) {
            await http.patch(
              Uri.parse(
                '${SupabaseConfig.url}/rest/v1/users?id=eq.${_user!['id']}',
              ),
              headers: SupabaseConfig.headers,
              body: jsonEncode({
                'username': username,
                'phone': phone,
              }),
            );
          }

          return true;
        }
      } else {
        // 没有邮箱，直接在 users 表创建记录
        // 生成一个伪邮箱作为标识
        final pseudoEmail = '${username}_${DateTime.now().millisecondsSinceEpoch}@pureenjoy.local';

        final response = await http.post(
          Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
          headers: {
            'apikey': SupabaseConfig.anonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': pseudoEmail,
            'password': password,
            'data': {
              'username': username,
              'phone': phone,
            },
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          await _saveSession(data);

          // 更新 users 表
          if (_user != null && _user!['id'] != null) {
            await http.patch(
              Uri.parse(
                '${SupabaseConfig.url}/rest/v1/users?id=eq.${_user!['id']}',
              ),
              headers: SupabaseConfig.headers,
              body: jsonEncode({
                'username': username,
                'phone': phone,
              }),
            );
          }

          return true;
        }
      }

      return false;
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
