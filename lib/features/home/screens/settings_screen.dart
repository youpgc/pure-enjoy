import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../config.dart';
import 'data_sync_screen.dart';
import 'rich_text_page.dart';
import '../../../services/data_export_service.dart';
import '../../../services/version_check_service.dart';
import '../../../services/supabase_service.dart';
import '../../life/screens/feedback_list_screen.dart';

/// 系统设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _fontSize = '中';
  String _readingBg = '默认';
  String _language = '简体中文';
  bool _autoSync = true;
  bool _wifiOnly = true;
  bool _pushNotification = true;
  bool _dailyReminder = false;
  bool _anniversaryReminder = true;
  String _currentVersion = '';
  bool _isCheckingUpdate = false;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  void _loadSettings() {
    final themeProvider = context.read<ThemeProvider>();
    _isDarkMode = themeProvider.themeMode == ThemeMode.dark;
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _currentVersion = '${info.version}+${info.buildNumber}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
      ),
      body: ListView(
        children: [
          // 阅读设置
          const _SectionHeader(title: '阅读设置'),
          SwitchListTile(
            secondary: const Icon(Icons.nightlight_outlined),
            title: const Text('深色模式'),
            subtitle: const Text('切换深色/浅色主题'),
            value: _isDarkMode,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              final provider = context.read<ThemeProvider>();
              provider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('字体大小'),
            subtitle: Text(_fontSize),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontSizeDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('阅读背景'),
            subtitle: Text(_readingBg),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReadingBgDialog(),
          ),

          // 同步设置
          const _SectionHeader(title: '同步设置'),
          SwitchListTile(
            secondary: const Icon(Icons.sync),
            title: const Text('自动同步'),
            subtitle: const Text('连接网络时自动同步数据'),
            value: _autoSync,
            onChanged: (val) => setState(() => _autoSync = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('仅WiFi同步'),
            subtitle: const Text('移动网络下不同步数据'),
            value: _wifiOnly,
            onChanged: (val) => setState(() => _wifiOnly = val),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('数据同步'),
            subtitle: const Text('手动同步数据到云端'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataSyncScreen()),
              );
            },
          ),

          // 通知设置
          const _SectionHeader(title: '通知设置'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('推送通知'),
            subtitle: const Text('接收系统推送通知'),
            value: _pushNotification,
            onChanged: (val) => setState(() => _pushNotification = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('每日提醒'),
            subtitle: const Text('每天提醒记录体重和心情'),
            value: _dailyReminder,
            onChanged: (val) => setState(() => _dailyReminder = val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cake_outlined),
            title: const Text('纪念日提醒'),
            subtitle: const Text('纪念日到期前提醒'),
            value: _anniversaryReminder,
            onChanged: (val) => setState(() => _anniversaryReminder = val),
          ),

          // 语言设置
          const _SectionHeader(title: '语言设置'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            subtitle: Text(_language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(),
          ),

          // 数据管理
          const _SectionHeader(title: '数据管理'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('数据导出'),
            subtitle: const Text('导出消费、体重、心情数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showExportDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清除缓存'),
            subtitle: const Text('清除本地缓存数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('注销账号', style: TextStyle(color: Colors.red)),
            subtitle: const Text('永久删除账号及所有数据'),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () => _showDeleteAccountDialog(),
          ),

          // 关于与法律
          const _SectionHeader(title: '关于与法律'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于纯享'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RichTextPage(
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
                  builder: (_) => const RichTextPage(
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
                  builder: (_) => const RichTextPage(
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
                  builder: (_) => const RichTextPage(
                    configKey: 'help_center',
                    title: '帮助中心',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('问题反馈'),
            subtitle: const Text('提交问题与建议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FeedbackListScreen(),
                ),
              );
            },
          ),

          // 版本信息
          const _SectionHeader(title: '版本'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('检查更新'),
            subtitle: Text(_isCheckingUpdate
                ? '检查中...'
                : _latestVersion != null
                    ? '发现新版本: $_latestVersion'
                    : _currentVersion.isEmpty
                        ? '加载中...'
                        : '当前版本: $_currentVersion'),
            trailing: _isCheckingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isCheckingUpdate ? null : () => _checkUpdate(),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('字体大小'),
        children: ['小', '中', '大', '特大'].map((size) {
          return RadioListTile<String>(
            title: Text(size),
            value: size,
            groupValue: _fontSize,
            onChanged: (val) {
              setState(() => _fontSize = val!);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showReadingBgDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('阅读背景'),
        children: ['默认', '护眼绿', '暖黄', '深色'].map((bg) {
          return RadioListTile<String>(
            title: Text(bg),
            value: bg,
            groupValue: _readingBg,
            onChanged: (val) {
              setState(() => _readingBg = val!);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('语言'),
        children: ['简体中文', 'English'].map((lang) {
          return RadioListTile<String>(
            title: Text(lang),
            value: lang,
            groupValue: _language,
            onChanged: (val) {
              setState(() => _language = val!);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除本地缓存数据吗？不会影响云端数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCache();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除缓存失败: $e')),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注销账号', style: TextStyle(color: Colors.red)),
        content: const Text(
          '警告：此操作将永久删除您的账号及所有相关数据，包括消费记录、体重记录、心情日记、笔记、收藏等。此操作不可恢复！\n\n请确认您已备份重要数据。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final auth = AuthService.instance;
      final userId = auth.currentUserId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未登录，无法注销')),
          );
        }
        return;
      }

      // 删除用户相关数据
      final tables = [
        'expenses',
        'weight_records',
        'mood_diaries',
        'notes',
        'user_habits',
        'user_habit_checkins',
        'user_favorites',
        'user_feedback',
        'user_reminders',
        'reading_history',
        'user_anniversaries',
      ];

      for (final table in tables) {
        try {
          await http.delete(
            Uri.parse('${SupabaseConfig.url}/rest/v1/$table?user_id=eq.$userId'),
            headers: SupabaseConfig.writeHeaders,
          );
        } catch (_) {
          // 忽略单个表删除失败
        }
      }

      // 登出
      await auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账号已注销，所有数据已删除')),
        );
        // 返回首页
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注销失败: $e')),
        );
      }
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final versionInfo = await VersionCheckService.instance.checkUpdate();
      if (mounted) {
        if (versionInfo != null) {
          setState(() => _latestVersion = versionInfo['version'] as String?);
          VersionCheckService.instance.showUpdateDialog(context, versionInfo);
        } else {
          setState(() => _latestVersion = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前已是最新版本')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _showExportDialog() async {
    final result = await DataExportService.exportAndShare(type: DataExportService.typeAll);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('数据导出成功，共${result.count}条记录')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: ${result.error}')),
        );
      }
    }
  }

  Future<void> _showVersionInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('版本信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('应用名称', info.appName),
            _buildInfoRow('版本号', '${info.version}+${info.buildNumber}'),
            _buildInfoRow('包名', info.packageName),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
