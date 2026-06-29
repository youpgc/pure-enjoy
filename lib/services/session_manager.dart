import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_client.dart';

/// 会话管理器：负责 Token 的内存缓存与本地持久化
///
/// 职责单一：
/// - 内存中维护 accessToken / refreshToken / authUser
/// - 通过 SharedPreferences 持久化会话
/// - 登录成功后同步 Token 到 HttpClient
class SessionManager {
  static SessionManager? _instance;
  SessionManager._();

  static SessionManager get instance {
    _instance ??= SessionManager._();
    return _instance!;
  }

  /// 当前 JWT Access Token
  String? _accessToken;

  /// 当前 Refresh Token
  String? _refreshToken;

  /// 当前 Supabase Auth 用户信息
  Map<String, dynamic>? _authUser;

  // ==================== Getter ====================

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get authUser => _authUser;

  String? get currentUserId => _authUser?['id'] as String?;
  String? get currentUserEmail => _authUser?['email'] as String?;

  String? get currentUserName {
    final nickname = _authUser?['user_metadata']?['username'] as String?;
    return nickname ?? currentUserEmail?.split('@').first ?? '用户';
  }

  String? get currentUserAvatar =>
      _authUser?['user_metadata']?['avatar_url'] as String?;

  int? get currentPoints => _authUser?['user_metadata']?['points'] as int?;
  String? get currentRole => _authUser?['user_metadata']?['role'] as String?;

  String? get currentMemberLevel =>
      _authUser?['user_metadata']?['member_level'] as String?;

  bool get isAuthenticated => _authUser != null;
  bool get isLoggedIn => isAuthenticated;

  // ==================== 会话操作 ====================

  /// 保存登录会话（内存 + 持久化 + 同步到 HttpClient）
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> authUser,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _authUser = authUser;

    HttpClient.instance.setAccessToken(_accessToken);
    await _persist();
  }

  /// 从本地恢复会话
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('sb_access_token');
      final refresh = prefs.getString('sb_refresh_token');
      final userJson = prefs.getString('sb_user');

      if (token != null && userJson != null) {
        _accessToken = token;
        _refreshToken = refresh;
        _authUser = jsonDecode(userJson) as Map<String, dynamic>;
        HttpClient.instance.setAccessToken(_accessToken);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 恢复会话失败: $e');
      return false;
    }
  }

  /// 清除会话（内存 + 持久化 + HttpClient）
  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _authUser = null;

    HttpClient.instance.setAccessToken(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sb_access_token');
      await prefs.remove('sb_refresh_token');
      await prefs.remove('sb_user');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 清除会话失败: $e');
    }
  }

  /// 仅更新用户信息（刷新用户数据时用）
  Future<void> updateAuthUser(Map<String, dynamic> authUser) async {
    _authUser = authUser;
    await _persist();
  }

  /// 更新 Token（刷新 Token 时用）
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? authUser,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (authUser != null) _authUser = authUser;

    HttpClient.instance.setAccessToken(_accessToken);
    await _persist();
  }

  // ==================== 内部方法 ====================

  Future<void> _persist() async {
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
      if (kDebugMode) debugPrint('⚠️ 持久化会话失败: $e');
    }
  }
}
