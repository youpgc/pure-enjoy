import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/login_page.dart';

/// 个人中心页面
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isSyncing = false;
  String? _syncError;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  void _loadLastSyncTime() {
    final saved = StorageService().getSetting<String>('last_sync_time');
    if (saved != null) {
      _lastSyncTime = DateTime.tryParse(saved);
    }
  }

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });
    try {
      await SyncService().syncAll();
      final now = DateTime.now();
      await StorageService().saveSetting('last_sync_time', now.toIso8601String());
      setState(() {
        _lastSyncTime = now;
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('同步完成'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _syncError = e.toString();
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: $_syncError'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final user = authState.user;
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 用户信息卡片
            _buildUserCard(context, isLoggedIn, user, ref),
            const SizedBox(height: 20),

            // 数据同步
            _buildSection(
              context,
              title: '数据同步',
              children: [
                _buildListTile(
                  icon: Icons.cloud_sync,
                  title: '云端同步',
                  subtitle: isLoggedIn
                      ? (_isSyncing
                          ? '正在同步...'
                          : _lastSyncTime != null
                              ? '上次同步: ${_formatSyncTime(_lastSyncTime!)}'
                              : '点击手动同步')
                      : '登录后可使用',
                  trailing: isLoggedIn
                      ? _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.sync),
                              onPressed: _triggerSync,
                            )
                      : null,
                  onTap: isLoggedIn && !_isSyncing ? _triggerSync : null,
                ),
                _buildListTile(
                  icon: Icons.download,
                  title: '导出数据',
                  onTap: () {
                    // TODO: 导出数据
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 设置
            _buildSection(
              context,
              title: '设置',
              children: [
                _buildListTile(
                  icon: Icons.palette,
                  title: '主题设置',
                  subtitle: currentTheme.label,
                  onTap: () => _showThemePicker(context, ref, currentTheme),
                ),
                _buildListTile(
                  icon: Icons.notifications,
                  title: '通知设置',
                  onTap: () {
                    // TODO: 通知设置
                  },
                ),
                _buildListTile(
                  icon: Icons.lock,
                  title: '隐私设置',
                  onTap: () {
                    // TODO: 隐私设置
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 关于
            _buildSection(
              context,
              title: '关于',
              children: [
                _buildListTile(
                  icon: Icons.info,
                  title: '关于纯享',
                  subtitle: '版本 ${AppConstants.appVersion}',
                ),
                _buildListTile(
                  icon: Icons.star,
                  title: '给个好评',
                  onTap: () {
                    // TODO: 应用商店
                  },
                ),
                _buildListTile(
                  icon: Icons.feedback,
                  title: '意见反馈',
                  onTap: () {
                    // TODO: 反馈
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 退出登录
            if (isLoggedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showLogoutDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                    foregroundColor: AppTheme.errorColor,
                    elevation: 0,
                  ),
                  child: const Text('退出登录'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, AppThemeMode current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择主题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...AppThemeMode.values.map((mode) {
                final isSelected = mode == current;
                return ListTile(
                  leading: Icon(
                    mode == AppThemeMode.system
                        ? Icons.brightness_auto
                        : mode == AppThemeMode.light
                            ? Icons.light_mode
                            : Icons.dark_mode,
                    color: isSelected ? AppTheme.primaryColor : null,
                  ),
                  title: Text(mode.label),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primaryColor)
                      : null,
                  selected: isSelected,
                  selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, bool isLoggedIn, dynamic user, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLoggedIn ? Icons.person : Icons.person_outline,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoggedIn
                          ? (user?.email ?? '用户')
                          : '未登录',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoggedIn
                          ? '数据已同步到云端'
                          : '登录后可同步数据到云端',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLoggedIn) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                ),
                child: const Text('登录 / 注册'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出登录后，本地数据仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authStateProvider.notifier).signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
