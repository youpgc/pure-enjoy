import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../profile/services/point_service.dart';
import '../../auth/screens/login_screen.dart';
import 'reading_history_screen.dart';
import '../../../services/version_check_service.dart';
import '../../../services/dict_service.dart';
import '../../profile/screens/point_records_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../../../core/widgets/widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// 从 Supabase 重新加载用户数据
  Future<void> _loadUserData() async {
    await SupabaseService.instance.reloadCurrentUser();
    final points = await PointService.instance.getAvailablePoints();
    if (mounted) {
      setState(() {
        _totalPoints = points;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService.instance;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => _loadUserData());
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // 用户信息卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildAvatar(colorScheme, supabaseService),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supabaseService.currentUserName ?? '用户',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supabaseService.currentUserEmail ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadUserData();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // 用户信息展示列
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatItem(Icons.stars_outlined, '角色', _getRoleLabel(supabaseService.currentRole), onTap: () {}),
                _buildStatItem(Icons.workspace_premium_outlined, '会员', _getMemberLevelLabel(supabaseService.currentMemberLevel), onTap: () {}),
                _buildStatItem(Icons.monetization_on_outlined, '积分', '$_totalPoints', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PointRecordsScreen())).then((_) => _loadUserData());
                }),
              ],
            ),
          ),

          // 功能列表 - 个人中心
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '个人中心',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('阅读历史'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()),
              );
            },
          ),

          // 版本信息
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('版本信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final versionInfo = await VersionCheckService.instance.checkUpdate();
              if (!context.mounted) return;
              if (versionInfo != null) {
                VersionCheckService.instance.showUpdateDialog(context, versionInfo);
              } else {
                showSnackBar(context, '当前已是最新版本');
              }
            },
          ),

          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: colorScheme.error,
            ),
            title: Text(
              '退出登录',
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () async {
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
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(IconData icon, String label, String value, {required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: colorScheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取角色标签
  String _getRoleLabel(String? role) {
    if (role == null || role.isEmpty) return '普通用户';
    return DictService.instance.getLabelOrDefault('user_role', role, defaultValue: '普通用户');
  }

  /// 获取会员等级标签
  String _getMemberLevelLabel(String? level) {
    if (level == null || level.isEmpty) return '普通会员';
    return DictService.instance.getLabelOrDefault('member_level', level, defaultValue: '普通会员');
  }

  /// 构建用户头像
  Widget _buildAvatar(ColorScheme colorScheme, SupabaseService supabaseService) {
    final avatarUrl = supabaseService.currentUserAvatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: colorScheme.primaryContainer,
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            cacheWidth: 128,
            cacheHeight: 128,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Icon(
                Icons.person,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              );
            },
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 32,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: 32,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}
