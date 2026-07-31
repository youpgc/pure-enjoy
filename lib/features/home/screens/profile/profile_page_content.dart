import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/dict_service.dart';
import '../../avatar_render.dart';
// [小说模块暂时停用] import '../reading_history_screen.dart';
import '../about_legal_screen.dart';
import '../../../life/screens/feedback_list_screen.dart';

/// {@template profile_page_content}
/// [ProfilePage] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。进一步拆为 Header / Stats / Menu 三个子组件。
/// {@endtemplate}
class ProfilePageContent extends StatelessWidget {
  /// {@macro profile_page_content}
  const ProfilePageContent({
    super.key,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.currentRole,
    required this.currentMemberLevel,
    required this.totalPoints,
    required this.appVersion,
    required this.hasUpdate,
    required this.avatarUrl,
    required this.onSettingsTap,
    required this.onEditProfile,
    required this.onPointsTap,
    required this.onVersionTap,
    required this.onSignOut,
  });

  final String? currentUserName;
  final String? currentUserEmail;
  final String? currentRole;
  final String? currentMemberLevel;
  final int totalPoints;
  final String appVersion;
  final bool hasUpdate;
  final String? avatarUrl;

  final VoidCallback onSettingsTap;
  final VoidCallback onEditProfile;
  final VoidCallback onPointsTap;
  final VoidCallback onVersionTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettingsTap,
          ),
        ],
      ),
      body: ListView(
        children: [
          ProfileHeaderCard(
            currentUserName: currentUserName,
            currentUserEmail: currentUserEmail,
            avatarUrl: avatarUrl,
            onEditProfile: onEditProfile,
          ),
          ProfileStatsRow(
            currentRole: currentRole,
            currentMemberLevel: currentMemberLevel,
            totalPoints: totalPoints,
            onPointsTap: onPointsTap,
          ),
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
          // [小说模块暂时停用] 阅读历史入口
          // ListTile(
          //   leading: const Icon(Icons.history_outlined),
          //   title: const Text('阅读历史'),
          //   trailing: const Icon(Icons.chevron_right),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()),
          //     );
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于与法律'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutLegalScreen()),
              );
            },
          ),
          ProfileVersionListTile(
            appVersion: appVersion,
            hasUpdate: hasUpdate,
            onVersionTap: onVersionTap,
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('问题反馈'),
            subtitle: const Text('提交问题与建议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackListScreen()),
              );
            },
          ),
          const Divider(),
          ProfileSignOutListTile(onSignOut: onSignOut),
        ],
      ),
    );
  }
}

/// 顶部用户信息卡片：头像 + 昵称/邮箱 + 编辑按钮
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.avatarUrl,
    required this.onEditProfile,
  });

  final String? currentUserName;
  final String? currentUserEmail;
  final String? avatarUrl;
  final VoidCallback onEditProfile;

  Widget _buildAvatar(ColorScheme colorScheme) {
    final avatarUrl = this.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) {
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
    final resolved = resolveAvatar(avatarUrl);
    final tint = resolved.bg != null ? avatarHexToColor(resolved.bg!) : null;
    return CircleAvatar(
      radius: 32,
      backgroundColor: tint ?? colorScheme.primaryContainer,
      backgroundImage: resolved.image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildAvatar(colorScheme),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUserName ?? '用户',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUserEmail ?? '',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEditProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// 用户信息展示列：角色 / 会员 / 积分
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.currentRole,
    required this.currentMemberLevel,
    required this.totalPoints,
    required this.onPointsTap,
  });

  final String? currentRole;
  final String? currentMemberLevel;
  final int totalPoints;
  final VoidCallback onPointsTap;

  String _getRoleLabel(String? role) {
    if (role == null || role.isEmpty) return '普通用户';
    return DictService.instance.getLabelOrDefault('user_role', role,
        defaultValue: '普通用户');
  }

  String _getMemberLevelLabel(String? level) {
    if (level == null || level.isEmpty) return '普通会员';
    return DictService.instance.getLabelOrDefault('member_level', level,
        defaultValue: '普通会员');
  }

  Widget _buildStatItem(IconData icon, String label, String value,
      {required VoidCallback onTap,
      required ColorScheme colorScheme,
      required BuildContext context}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: colorScheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatItem(
            Icons.stars_outlined,
            '角色',
            _getRoleLabel(currentRole),
            onTap: () {},
            colorScheme: colorScheme,
            context: context,
          ),
          _buildStatItem(
            Icons.workspace_premium_outlined,
            '会员',
            _getMemberLevelLabel(currentMemberLevel),
            onTap: () {},
            colorScheme: colorScheme,
            context: context,
          ),
          _buildStatItem(
            Icons.monetization_on_outlined,
            '积分',
            '$totalPoints',
            onTap: onPointsTap,
            colorScheme: colorScheme,
            context: context,
          ),
        ],
      ),
    );
  }
}

/// 版本信息入口：版本号右上角红点提示
class ProfileVersionListTile extends StatelessWidget {
  const ProfileVersionListTile({
    super.key,
    required this.appVersion,
    required this.hasUpdate,
    required this.onVersionTap,
  });

  final String appVersion;
  final bool hasUpdate;
  final VoidCallback onVersionTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('版本信息'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (appVersion.isNotEmpty)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  'v$appVersion',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hasUpdate)
                  Positioned(
                    right: -8,
                    top: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onVersionTap,
    );
  }
}

/// 退出登录入口
class ProfileSignOutListTile extends StatelessWidget {
  const ProfileSignOutListTile({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        Icons.logout,
        color: colorScheme.error,
      ),
      title: Text(
        '退出登录',
        style: TextStyle(color: colorScheme.error),
      ),
      onTap: onSignOut,
    );
  }
}
