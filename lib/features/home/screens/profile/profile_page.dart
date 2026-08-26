import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../../profile/services/point_service.dart';
import '../../../auth/screens/login_screen.dart';
import '../../../../services/version_check_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/screens/point_records/checkin_screen.dart';
import '../edit_profile/edit_profile_screen.dart';
import '../settings/settings_screen.dart';
import '../theme_settings/theme_settings_screen.dart';
import './profile_page_content.dart';

/// 个人中心页面
///
/// 展示用户头像、昵称、角色、会员等级、积分等信息，
/// 提供编辑资料、阅读历史、版本信息、退出登录等入口。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _totalPoints = 0;

  /// 当前应用版本号（形如 1.10.11，手机安装版本）
  String _appVersion = '';

  /// 是否有可更新的新版本（用于版本号右上角红点提示）
  bool _hasUpdate = false;

  /// 头像 URL：直接从 users 表读取（与「编辑资料」页同源），
  /// 不依赖 auth user_metadata 的异步同步，避免「我的」页经常显示默认头像。
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    // 先用会话内已有头像值，避免首帧空白；随后 _loadUserData 会从 users 表校正
    _avatarUrl = SupabaseService.instance.currentUserAvatar;
    _loadUserData();
    _loadAppVersion();
    _checkUpdate();
  }

  /// 读取当前应用版本号，用于在版本信息右侧展示
  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  /// 检查是否有新版本，有则在版本号右上角显示红点。
  /// 使用 getLatestVersionInfo（不受「稍后更新」影响），
  /// 这样即便用户点过「稍后更新」，版本信息仍展示最新版本并允许手动更新。
  Future<void> _checkUpdate() async {
    final versionInfo = await VersionCheckService.instance.getLatestVersionInfo();
    if (mounted) {
      setState(() {
        _hasUpdate = versionInfo != null;
      });
    }
  }

  /// 从 Supabase 重新加载用户数据
  Future<void> _loadUserData() async {
    await SupabaseService.instance.reloadCurrentUser();
    final points = await PointService.instance.getAvailablePoints();

    // 直接读取 users 表 avatar_url（与「编辑资料」页同源），确保头像可靠显示，
    // 不依赖 auth user_metadata 的异步同步（该同步偶发未及时完成，导致显示默认头像）。
    String? avatarUrl = SupabaseService.instance.currentUserAvatar;
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId != null) {
        final res = await ApiClient.get(
          'users',
          filters: {
            ApiClient.userKey(userId): 'eq.$userId',
            'is_deleted': 'eq.false',
          },
          columns: 'avatar_url',
          limit: 1,
        );
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          final v = res.data![0]['avatar_url'];
          if (v != null && v is String && v.isNotEmpty) avatarUrl = v;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('读取用户头像失败: $e');
    }

    if (mounted) {
      setState(() {
        _totalPoints = points;
        _avatarUrl = avatarUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService.instance;
    return ProfilePageContent(
      currentUserName: supabaseService.currentUserName,
      currentUserEmail: supabaseService.currentUserEmail,
      currentRole: supabaseService.currentRole,
      currentMemberLevel: supabaseService.currentMemberLevel,
      totalPoints: _totalPoints,
      appVersion: _appVersion,
      hasUpdate: _hasUpdate,
      avatarUrl: _avatarUrl,
      onSettingsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ).then((_) => _loadUserData());
      },
      onEditProfile: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        );
        if (result == true) {
          _loadUserData();
        }
      },
      onPointsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CheckinScreen()),
        ).then((_) => _loadUserData());
      },
      onVersionTap: () async {
        // 走不受「稍后更新」影响的手动检查通道，确保即便已忽略也能更新
        final versionInfo =
            await VersionCheckService.instance.getLatestVersionInfo();
        if (!context.mounted) return;
        // 刷新红点状态
        if (mounted) {
          setState(() {
            _hasUpdate = versionInfo != null;
          });
        }
        if (versionInfo != null) {
          VersionCheckService.instance.showUpdateDialog(context, versionInfo);
        } else {
          showSnackBar(context, '当前已是最新版本');
        }
      },
      onThemeSettingsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
        ).then((_) => _loadUserData());
      },
      onSignOut: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('确定要退出登录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          try {
            await supabaseService.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          } catch (e) {
            if (context.mounted) {
              showSnackBar(context, '退出登录失败，请稍后重试', isError: true);
            }
          }
        }
      },
    );
  }
}
