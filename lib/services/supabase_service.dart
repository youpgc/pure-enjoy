/// 用户认证服务（本地状态管理）
class AuthService {
  static AuthService? _instance;
  
  AuthService._();
  
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }
  
  // 本地存储的用户信息
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _isAuthenticated = false;
  
  /// 获取当前用户ID
  String? get currentUserId => _userId;
  
  /// 获取当前用户邮箱
  String? get currentUserEmail => _userEmail;
  
  /// 获取当前用户名
  String? get currentUserName => _userName;
  
  /// 检查是否已登录
  bool get isAuthenticated => _isAuthenticated;
  
  /// 登录
  Future<bool> signIn(String email, String password) async {
    // 简单的本地验证（实际应用中应该使用后端验证）
    if (email.isNotEmpty && password.length >= 6) {
      _userId = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
      _userEmail = email;
      _userName = email.split('@').first;
      _isAuthenticated = true;
      return true;
    }
    return false;
  }
  
  /// 注册
  Future<bool> signUp(String email, String password) async {
    // 简单的本地注册
    if (email.isNotEmpty && password.length >= 6) {
      _userId = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
      _userEmail = email;
      _userName = email.split('@').first;
      _isAuthenticated = true;
      return true;
    }
    return false;
  }
  
  /// 退出登录
  Future<void> signOut() async {
    _userId = null;
    _userEmail = null;
    _userName = null;
    _isAuthenticated = false;
  }
  
  /// 更新用户信息
  void updateUser({String? name, String? email}) {
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
  }
}

// 为了兼容旧代码，保留 SupabaseService 别名
typedef SupabaseService = AuthService;
