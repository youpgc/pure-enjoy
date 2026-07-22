/// Supabase 服务门面
///
/// 将 SessionManager（会话管理）和 AuthApi（认证逻辑）组合为统一入口。
/// 所有外部代码通过 AuthService.instance 访问，保持向后兼容。
library;

import 'supabase_config.dart';
import 'session_manager.dart';
import 'auth_api.dart';
import 'api_client.dart';
import 'http_client.dart';
import '../utils/cache_helper.dart';
import 'chapter_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

// 重新导出，保持向后兼容
export 'supabase_config.dart';

// 为了兼容旧代码，保留别名
typedef SupabaseService = AuthService;

/// 用户认证服务（门面）
///
/// 委托 SessionManager 处理会话，委托 AuthApi 处理认证请求。
class AuthService {
  static AuthService? _instance;
  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  final _session = SessionManager.instance;
  final _auth = AuthApi.instance;

  // ==================== 用户信息代理 ====================

  String? get currentUserId => _session.currentUserId;
  String? get currentUserEmail => _session.currentUserEmail;
  String? get currentUserName => _session.currentUserName;
  String? get currentUserAvatar => _session.currentUserAvatar;
  int? get currentPoints => _session.currentPoints;
  String? get currentRole => _session.currentRole;
  String? get currentMemberLevel => _session.currentMemberLevel;
  bool get isAuthenticated => _session.isAuthenticated;
  bool get isLoggedIn => _session.isLoggedIn;
  Map<String, dynamic>? get currentUser => _session.authUser;
  String? get accessToken => _session.accessToken;

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    final restored = await _session.restoreSession();
    if (restored) {
      SecureLogger.log(
          '🔐 Supabase Auth 会话已恢复: ${_session.currentUserId}');
    }
  }

  // ==================== 认证代理 ====================

  /// 保存认证结果到会话
  Future<void> _saveAuthResult(SupabaseAuthResponse result) async {
    if (result.success && result.user != null) {
      await _session.saveSession(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
        authUser: result.user!,
      );
    }
  }

  /// 邮箱+密码登录
  Future<SupabaseAuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmail(
        email: email, password: password);
    await _saveAuthResult(result);
    _reportLogin(success: result.success, account: email);
    return result;
  }

  /// 统一账号登录
  Future<SupabaseAuthResponse> signInWithAccount({
    required String account,
    required String password,
  }) async {
    final result = await _auth.signInWithAccount(
        account: account, password: password);
    await _saveAuthResult(result);
    _reportLogin(success: result.success, account: account);
    return result;
  }

  // ==================== 登录日志埋点 ====================
  // 记录一次 App 登录事件（成功/失败）。best-effort，不阻塞登录主流程。
  // 真实客户端 IP 由服务端 record_login RPC 从 request.headers 提取；
  // 登录地点由前端 GeoIP 解析（best-effort，失败传 null）。
  static String? _cachedAppVersion;

  static Future<String> get _appVersion async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = info.version;
    } catch (_) {
      _cachedAppVersion = 'unknown';
    }
    return _cachedAppVersion!;
  }

  /// 触发一次登录日志记录（fire-and-forget）
  void _reportLogin({required bool success, String? account}) {
    _doReportLogin(success, account).catchError((_) {});
  }

  /// 解析登录地点（best-effort）：依次尝试多个免费 GeoIP 接口，任一成功即返回。
  /// 因国内访问海外接口可能不稳定，采用主用 + 兜底策略；任一失败静默跳过。
  static const List<Map<String, dynamic>> _geoProviders = [
    {
      'url': 'https://ipapi.co/json/',
      'fields': ['country_name', 'region', 'city'],
    },
    {
      'url': 'https://api.ip.sb/geoip/',
      'fields': ['country', 'region', 'city'],
    },
  ];

  Future<String?> _resolveLocation() async {
    for (final p in _geoProviders) {
      try {
        final geo = await HttpClient.instance.rawRequest(
          p['url'] as String,
          method: 'GET',
          headers: {'User-Agent': 'PureEnjoy'},
          timeout: RequestTimeout.simple,
        );
        if (geo.statusCode == 200) {
          final j = jsonDecode(geo.body) as Map<String, dynamic>;
          final parts = <String>[
            for (final f in (p['fields'] as List<String>))
              if (j[f] != null) j[f].toString(),
          ];
          final loc = parts.join(' ').trim();
          if (loc.isNotEmpty) return loc;
        }
      } catch (_) {
        // 尝试下一个兜底接口
      }
    }
    return null;
  }

  Future<void> _doReportLogin(bool success, String? account) async {
    final location = await _resolveLocation();

    final ua = 'PureEnjoy/${await _appVersion} (${Platform.operatingSystem})';
    await HttpClient.instance.rawRequest(
      '${SupabaseConfig.url}/rest/v1/rpc/record_login',
      method: 'POST',
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      },
      body: {
        'p_source': 'app',
        'p_status': success ? 'success' : 'failed',
        'p_user_agent': ua,
        'p_location': location,
        'p_username': account,
      },
      timeout: RequestTimeout.simple,
    );
  }

  /// 注册
  Future<SupabaseAuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    final result = await _auth.signUpWithEmail(
      email: email,
      password: password,
      username: username,
      phone: phone,
    );
    await _saveAuthResult(result);
    return result;
  }

  /// 退出登录
  Future<void> signOut() async {
    // 切换账号前清除本地缓存数据，防止旧账号数据残留
    try {
      await CacheHelper.instance.clearAllUserData();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('清理缓存失败: $e');
      }
    }
    try {
      await ChapterCacheService.instance.clearAllCache();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('清理缓存失败: $e');
      }
    }
    await _session.clearSession();
  }

  /// 刷新 Token
  Future<bool> refreshToken() async {
    final currentRefresh = _session.refreshToken;
    if (currentRefresh == null) return false;

    final result =
        await _auth.refreshToken(refreshToken: currentRefresh);
    if (result.success) {
      await _session.updateTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
        authUser: result.user,
      );
      return true;
    }
    return false;
  }

  /// 刷新用户信息
  Future<Map<String, dynamic>?> refreshUser() async {
    return refreshAuthUser();
  }

  /// 刷新用户信息（Supabase Auth）
  Future<Map<String, dynamic>?> refreshAuthUser() async {
    final token = _session.accessToken;
    if (token == null) return null;

    final user = await _auth.fetchUser(accessToken: token);
    if (user != null) {
      await _session.updateAuthUser(user);
    }
    return user;
  }

  /// 重新加载当前用户数据
  ///
  /// 同时把 public.users 表的积分统计同步进会话缓存，
  /// 避免 currentPoints 等始终停留在 Auth user_metadata 的旧值
  /// （积分真实存于 users 表，曾存在两套数据源脱节的隐患）。
  Future<bool> reloadCurrentUser() async {
    final user = await refreshAuthUser();
    if (user == null) return false;

    // 同步 users 表积分统计到会话缓存，使 currentPoints 与事实一致
    try {
      final userId = _session.currentUserId;
      if (userId != null) {
        final statsRes = await ApiClient.get(
          'users',
          filters: {
            ApiClient.userKey(userId): 'eq.$userId',
            'is_deleted': 'eq.false',
          },
          columns:
              'points,available_points,effective_points,expiring_points,avatar_url',
          limit: 1,
        );
        if (statsRes.isSuccess &&
            statsRes.data != null &&
            statsRes.data!.isNotEmpty) {
          final row = statsRes.data![0];
          final metadata = Map<String, dynamic>.from(
            user['user_metadata'] as Map<dynamic, dynamic>? ?? {},
          );
          metadata['points'] = row['points'] ?? metadata['points'];
          metadata['available_points'] = row['available_points'];
          metadata['effective_points'] = row['effective_points'];
          metadata['expiring_points'] = row['expiring_points'];
          // 同步头像URL（public.users.avatar_url），修复"我的"页头像已上传却不渲染
          metadata['avatar_url'] = row['avatar_url'] ?? metadata['avatar_url'];
          user['user_metadata'] = metadata;
          await _session.updateAuthUser(user);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('同步用户积分到会话缓存失败: $e');
      }
    }

    return true;
  }

  /// 修改密码
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = _session.accessToken;
    if (token == null) {
      return {'success': false, 'message': '未登录，无法修改密码'};
    }
    return _auth.changePassword(
      accessToken: token,
      newPassword: newPassword,
    );
  }

  /// 获取当前用户的认证 Headers
  Map<String, String> get authHeaders => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization':
            'Bearer ${_session.accessToken ?? SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };
}
