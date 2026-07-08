import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../profile/services/point_service.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

/// 个人中心页面
///
/// 展示用户头像、昵称、角色、会员等级、积分等信息，
/// 提供编辑资料、查看设置、退出登录等入口。
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
    final points = await PointService.instance.fetchTotalPoints();
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
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 用户信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAvatar(colorScheme, supabaseService),
                    const SizedBox(height: 12),
                    Text(
                      supabaseService.currentUser?.userMetadata?['nickname'] ??
                          supabaseService.currentUser?.email?.split('@').first ??
                          '用户',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supabaseService.currentUser?.email ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 统计信息
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(Icons.stars_outlined, '角色', _getRoleLabel(supabaseService.currentRole), onTap: () {}),
                ),
                Expanded(
                  child: _buildStatItem(Icons.workspace_premium_outlined, '会员', _getMemberLevelLabel(supabaseService.currentMemberLevel), onTap: () {}),
                ),
                Expanded(
                  child: _buildStatItem(Icons.monetization_on_outlined, '积分', '$_totalPoints', onTap: () {
                    // TODO: 跳转到积分详情
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 功能列表
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('编辑资料'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: const Text('退出登录'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await SupabaseService.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建用户头像
  Widget _buildAvatar(ColorScheme colorScheme, SupabaseService supabaseService) {
    final avatarUrl = supabaseService.currentUser?.userMetadata?['avatar_url'] as String?;
    return CircleAvatar(
      radius: 40,
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Icon(Icons.person, size: 40, color: colorScheme.onPrimaryContainer)
          : null,
    );
  }

  /// 构建统计项
  Widget _buildStatItem(IconData icon, String label, String value, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 获取角色显示文本
  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'vip':
        return 'VIP';
      default:
        return '普通用户';
    }
  }

  /// 获取会员等级显示文本
  String _getMemberLevelLabel(String? level) {
    switch (level) {
      case 'gold':
        return '黄金会员';
      case 'silver':
        return '白银会员';
      default:
        return '免费会员';
    }
  }
}
