import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../config.dart';
import '../../life/screens/life_screen.dart';
import '../../life/screens/expense_list_screen.dart';
import '../../life/screens/mood_diary_screen.dart';
import '../../life/screens/weight_record_screen.dart';
import '../../novel/screens/novel_list_screen.dart';
import '../../novel/screens/book_shelf_screen.dart';
import '../../../services/supabase_service.dart';
import '../../../services/version_check_service.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import 'rich_text_page.dart';

/// 首页 - 主导航页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    LifeScreen(),
    BookShelfScreen(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 应用启动时检查更新
    _checkForUpdate();
  }

  /// 检查应用更新
  void _checkForUpdate() async {
    final versionInfo = await VersionCheckService.instance.checkUpdate();
    if (versionInfo != null && mounted) {
      VersionCheckService.instance.showUpdateDialog(context, versionInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '生活',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// 首页仪表板
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingActivities = true;
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
  }

  /// 从 Supabase 加载最近活动记录
  Future<void> _loadRecentActivities() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingActivities = false);
        return;
      }

      final headers = {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
      };

      // 并行查询 expenses、mood_diaries、weight_records 各最新一条
      final futures = [
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/expenses?user_id=eq.$userId&select=*,created_at&order=created_at.desc&limit=1',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/mood_diaries?user_id=eq.$userId&select=*,created_at&order=created_at.desc&limit=1',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/weight_records?user_id=eq.$userId&select=*,created_at&order=created_at.desc&limit=1',
          ),
          headers: headers,
        ),
      ];

      final responses = await Future.wait(futures);

      final activities = <Map<String, dynamic>>[];

      // 解析心情日记
      final diaryResponse = responses[1];
      if (diaryResponse.statusCode == 200) {
        final list = jsonDecode(diaryResponse.body) as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.edit_note,
            'title': '心情日记',
            'subtitle': item['content'] ?? item['mood']?.toString() ?? '记录了一条心情',
            'time': _formatTime(item['created_at']),
          });
        }
      }

      // 解析支出记录
      final expenseResponse = responses[0];
      if (expenseResponse.statusCode == 200) {
        final list = jsonDecode(expenseResponse.body) as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.attach_money,
            'title': '支出记录',
            'subtitle': '${item['category'] ?? '其他'} ¥${item['amount'] ?? 0}',
            'time': _formatTime(item['created_at']),
          });
        }
      }

      // 解析体重记录
      final weightResponse = responses[2];
      if (weightResponse.statusCode == 200) {
        final list = jsonDecode(weightResponse.body) as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.monitor_weight,
            'title': '体重记录',
            'subtitle': '${item['weight'] ?? 0} kg',
            'time': _formatTime(item['created_at']),
          });
        }
      }

      // 按时间排序
      activities.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));

      if (mounted) {
        setState(() {
          _recentActivities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      print('加载最近活动失败: $e');
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  /// 格式化时间显示
  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    final dateTime = DateTime.tryParse(createdAt);
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dateTime.month}/${dateTime.day}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final supabaseService = SupabaseService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('纯享'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: 通知页面
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 欢迎卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '欢迎回来',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AuthService.instance.currentUserName ?? '用户',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '今天想做些什么？',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 快捷操作
          Text(
            '快捷操作',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.note_add_outlined,
                  label: '写日记',
                  color: colorScheme.primaryContainer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MoodDiaryScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '记一笔',
                  color: colorScheme.secondaryContainer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.monitor_weight_outlined,
                  label: '记体重',
                  color: colorScheme.tertiaryContainer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WeightRecordScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.menu_book_outlined,
                  label: '小说库',
                  color: colorScheme.errorContainer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NovelListScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.library_books_outlined,
                  label: '我的书架',
                  color: colorScheme.primaryContainer,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BookShelfScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // 占位保持对齐
            ],
          ),
          const SizedBox(height: 24),

          // 最近活动
          Text(
            '最近活动',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: _isLoadingActivities
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _recentActivities.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            '暂无最近活动',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: List.generate(_recentActivities.length, (index) {
                            final activity = _recentActivities[index];
                            return Column(
                              children: [
                                _ActivityItem(
                                  icon: activity['icon'] as IconData,
                                  title: activity['title'] as String,
                                  subtitle: activity['subtitle'] as String,
                                  time: activity['time'] as String,
                                ),
                                if (index < _recentActivities.length - 1)
                                  const Divider(),
                              ],
                            );
                          }),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// 我的页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _currentVersion = '1.0.0';
  String _latestVersion = '';
  bool _hasUpdate = false;
  bool _isForceUpdate = false;
  String? _apkUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _checkVersion();
    _loadUserData();
  }

  /// 从 Supabase 重新加载用户数据
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    await SupabaseService.instance.reloadCurrentUser();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 加载当前版本
  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      print('获取版本信息失败: $e');
    }
  }

  /// 检查最新版本
  Future<void> _checkVersion() async {
    try {
      final versionInfo = await VersionCheckService.instance.checkUpdate();
      if (versionInfo != null && mounted) {
        setState(() {
          _latestVersion = versionInfo['version'] ?? '';
          _hasUpdate = true;
          _isForceUpdate = versionInfo['is_force_update'] == true;
          _apkUrl = versionInfo['apk_url'];
        });
      }
    } catch (e) {
      print('检查版本失败: $e');
    }
  }

  /// 显示版本信息对话框
  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('版本信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: $_currentVersion'),
            if (_hasUpdate) ...[
              const SizedBox(height: 8),
              Text('最新版本: $_latestVersion'),
              if (_isForceUpdate)
                const Text(
                  '【强制更新】',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          ],
        ),
        actions: [
          if (_hasUpdate && _apkUrl != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _downloadAndInstall();
              },
              child: const Text('立即更新'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 下载并安装APK（内部下载）
  Future<void> _downloadAndInstall() async {
    if (_apkUrl == null) return;

    // 显示下载进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(apkUrl: _apkUrl!),
    );
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
              // TODO: 设置页面
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // 用户信息卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
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
                        // 重新从 Supabase 加载用户数据
                        _loadUserData();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // 功能列表
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('数据同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 数据同步
            },
          ),
          
          // 版本信息 - 带更新提示
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('版本信息'),
            subtitle: Text('当前: $_currentVersion'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isForceUpdate ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isForceUpdate ? '强制更新' : '有更新',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _showVersionDialog,
          ),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RichTextPage(
                    configKey: 'about',
                    title: '关于纯享',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RichTextPage(
                    configKey: 'privacy_policy',
                    title: '隐私政策',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RichTextPage(
                    configKey: 'user_agreement',
                    title: '用户协议',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('帮助中心'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RichTextPage(
                    configKey: 'help_center',
                    title: '帮助中心',
                  ),
                ),
              );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('退出登录失败: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ThemeSettingsScreen()),
    );
  }
}

/// 个性化设置页面
class _ThemeSettingsScreen extends StatelessWidget {
  const _ThemeSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个性化设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ====== 主题模式 ======
          _SectionTitle(title: '主题模式'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Column(
                children: [
                  _ThemeModeTile(
                    icon: Icons.brightness_auto,
                    title: '跟随系统',
                    selected: tp.themeMode == ThemeMode.system,
                    onTap: () => tp.setThemeMode(ThemeMode.system),
                  ),
                  const Divider(height: 1),
                  _ThemeModeTile(
                    icon: Icons.light_mode,
                    title: '浅色模式',
                    selected: tp.themeMode == ThemeMode.light,
                    onTap: () => tp.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  _ThemeModeTile(
                    icon: Icons.dark_mode,
                    title: '深色模式',
                    selected: tp.themeMode == ThemeMode.dark,
                    onTap: () => tp.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ====== 配色方案 ======
          _SectionTitle(title: '配色方案'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                padding: const EdgeInsets.all(16),
                children: AppColorScheme.values.map((scheme) {
                  final isSelected = tp.colorScheme == scheme;
                  return GestureDetector(
                    onTap: () => tp.setColorScheme(scheme),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.seedColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: scheme.seedColor, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: scheme.seedColor.withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scheme.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? scheme.seedColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ====== 字体大小 ======
          _SectionTitle(title: '字体大小'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('小'),
                        Text(
                          '${(tp.fontScale * 100).toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Text('大'),
                      ],
                    ),
                    Slider(
                      value: tp.fontScale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      label: '${(tp.fontScale * 100).toInt()}%',
                      onChanged: (value) => tp.setFontScale(value),
                    ),
                    // 预览文本
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '预览文本：纯享，记录生活每一天',
                        style: TextStyle(fontSize: 14 * tp.fontScale),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ====== 阅读背景 ======
          _SectionTitle(title: '阅读背景'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                padding: const EdgeInsets.all(16),
                children: ReaderBackgroundTheme.values.map((bg) {
                  final isSelected = tp.readerBg == bg;
                  return GestureDetector(
                    onTap: () => tp.setReaderBackground(bg),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: bg.bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.withOpacity(0.3),
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: bg.textColor,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bg.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// 分区标题
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// 主题模式选项
class _ThemeModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// 下载进度对话框
class _DownloadProgressDialog extends StatefulWidget {
  final String apkUrl;

  const _DownloadProgressDialog({required this.apkUrl});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String _status = '准备下载...';
  bool _isComplete = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final versionService = VersionCheckService.instance;

      // 监听进度
      versionService.downloadProgress.addListener(() {
        if (mounted) {
          setState(() {
            _progress = versionService.downloadProgress.value;
          });
        }
      });

      // 监听状态
      versionService.downloadStatus.addListener(() {
        if (mounted) {
          setState(() {
            _status = versionService.downloadStatus.value;
          });
        }
      });

      // 开始下载和安装
      await versionService.downloadAndInstall(context, widget.apkUrl);

      if (mounted) {
        setState(() {
          _isComplete = true;
        });

        // 延迟关闭对话框
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = '更新失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('应用更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete && !_hasError) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 16),
          ],
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _hasError ? Colors.red : null,
              fontWeight: _isComplete || _hasError ? FontWeight.bold : null,
            ),
          ),
          if (_isComplete) ...[
            const SizedBox(height: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
          ],
        ],
      ),
      actions: [
        if (_hasError || _isComplete)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}


