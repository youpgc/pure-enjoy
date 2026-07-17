import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../services/api_client.dart';
import '../../../services/chapter_cache_service.dart';
import 'rich_text_page.dart';

import '../../../services/version_check_service.dart';
import '../../../services/supabase_service.dart';
import '../../life/screens/feedback_list_screen.dart';
import '../../../core/widgets/widgets.dart';
import 'settings_list.dart';
import 'settings_dialogs.dart';
import 'settings_helpers.dart';

/// 系统设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // 从 ThemeProvider 同步的状态
  bool _isDarkMode = false;
  double _fontScale = 1.0;
  ReaderBackgroundTheme _readerBg = ReaderBackgroundTheme.defaultWhite;

  // 持久化到 SharedPreferences 的设置
  bool _autoSync = true;
  bool _wifiOnly = true;
  bool _pushNotification = true;
  bool _dailyReminder = false;
  bool _anniversaryReminder = true;

  // 版本信息
  String _currentVersion = '';
  bool _isCheckingUpdate = false;
  String? _latestVersion;

  // SharedPreferences keys
  static const _autoSyncKey = 'setting_auto_sync';
  static const _wifiOnlyKey = 'setting_wifi_only';
  static const _pushNotifKey = 'setting_push_notification';
  static const _dailyReminderKey = 'setting_daily_reminder';
  static const _anniversaryReminderKey = 'setting_anniversary_reminder';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  void _loadSettings() {
    final tp = ref.read(themeProvider);
    _isDarkMode = tp.isDarkMode;
    _fontScale = tp.fontScale;
    _readerBg = tp.readerBg;

    // 加载持久化设置
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _autoSync = prefs.getBool(_autoSyncKey) ?? true;
          _wifiOnly = prefs.getBool(_wifiOnlyKey) ?? true;
          _pushNotification = prefs.getBool(_pushNotifKey) ?? true;
          _dailyReminder = prefs.getBool(_dailyReminderKey) ?? false;
          _anniversaryReminder = prefs.getBool(_anniversaryReminderKey) ?? true;
        });
      }
    });
  }

  /// 保存布尔设置到 SharedPreferences
  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _currentVersion = '${info.version}+${info.buildNumber}');
    }
  }

  /// 字体大小 -> fontScale 映射
  double _fontSizeToScale(String size) {
    switch (size) {
      case '小': return 0.85;
      case '中': return 1.0;
      case '大': return 1.15;
      case '特大': return 1.3;
      default: return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
      ),
      body: SettingsList(
        isDarkMode: _isDarkMode,
        fontScale: _fontScale,
        readerBg: _readerBg,
        autoSync: _autoSync,
        wifiOnly: _wifiOnly,
        pushNotification: _pushNotification,
        dailyReminder: _dailyReminder,
        anniversaryReminder: _anniversaryReminder,
        currentVersion: _currentVersion,
        isCheckingUpdate: _isCheckingUpdate,
        latestVersion: _latestVersion,
        onDarkModeChanged: (val) {
          setState(() => _isDarkMode = val);
          ref.read(themeProvider).setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
        },
        onFontSizeTap: _showFontSizeDialog,
        onReadingBgTap: _showReadingBgDialog,
        onAutoSyncChanged: (val) {
          setState(() => _autoSync = val);
          _saveBoolSetting(_autoSyncKey, val);
        },
        onWifiOnlyChanged: (val) {
          setState(() => _wifiOnly = val);
          _saveBoolSetting(_wifiOnlyKey, val);
        },
        onPushNotifChanged: (val) {
          setState(() => _pushNotification = val);
          _saveBoolSetting(_pushNotifKey, val);
        },
        onDailyReminderChanged: (val) {
          setState(() => _dailyReminder = val);
          _saveBoolSetting(_dailyReminderKey, val);
        },
        onAnniversaryReminderChanged: (val) {
          setState(() => _anniversaryReminder = val);
          _saveBoolSetting(_anniversaryReminderKey, val);
        },
        onClearCacheTap: () => showClearCacheDialog(context, _clearCache),
        onChangePasswordTap: _showChangePasswordDialog,
        onDeleteAccountTap: () => showDeleteAccountDialog(context, _deleteAccount),
        onAboutTap: () {
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
        onPrivacyTap: () {
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
        onAgreementTap: () {
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
        onHelpTap: () {
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
        onFeedbackTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FeedbackListScreen(),
            ),
          );
        },
        onCheckUpdateTap: _checkUpdate,
      ),
    );
  }

  void _showFontSizeDialog() {
    final currentSize = scaleToFontSize(_fontScale);
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('字体大小'),
        children: [
          RadioGroup<String>(
            groupValue: currentSize,
            onChanged: (val) {
              if (val == null) return;
              final scale = _fontSizeToScale(val);
              ref.read(themeProvider).setFontScale(scale);
              setState(() => _fontScale = scale);
              Navigator.pop(dialogContext);
            },
            child: Column(
              children: ['小', '中', '大', '特大'].map((size) {
                return ListTile(
                  leading: Radio<String>(value: size),
                  title: Text(size),
                  onTap: () {
                    final scale = _fontSizeToScale(size);
                    ref.read(themeProvider).setFontScale(scale);
                    setState(() => _fontScale = scale);
                    Navigator.pop(dialogContext);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showReadingBgDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('阅读背景'),
        children: [
          RadioGroup<ReaderBackgroundTheme>(
            groupValue: _readerBg,
            onChanged: (val) {
              if (val == null) return;
              ref.read(themeProvider).setReaderBackground(val);
              setState(() => _readerBg = val);
              Navigator.pop(dialogContext);
            },
            child: Column(
              children: ReaderBackgroundTheme.values.map((bg) {
                return ListTile(
                  leading: Radio<ReaderBackgroundTheme>(value: bg),
                  title: Text(bg.label),
                  onTap: () {
                    ref.read(themeProvider).setReaderBackground(bg);
                    setState(() => _readerBg = bg);
                    Navigator.pop(dialogContext);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 只清除非设置类的缓存，保留用户设置
      final keysToRemove = prefs.getKeys().where((key) =>
        !key.startsWith('theme_') &&
        !key.startsWith('font_') &&
        !key.startsWith('reader_') &&
        !key.startsWith('color_') &&
        !key.startsWith('setting_') &&
        key != 'user'
      ).toList();
      await Future.wait(keysToRemove.map((key) => prefs.remove(key)));

      // 清除章节缓存文件（Bug 9 修复：之前只清除了索引，磁盘文件未被删除）
      final chapterCacheCount = await ChapterCacheService.instance.clearAllCache();

      if (mounted) {
        showSnackBar(context, '缓存已清除（${keysToRemove.length}项 + $chapterCacheCount个章节文件）');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '清除缓存失败，请稍后重试', isError: true);
      }
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final auth = AuthService.instance;
      final userId = auth.currentUserId;
      if (userId == null) {
        if (mounted) {
          showSnackBar(context, '未登录，无法注销');
        }
        return;
      }

      // 删除用户相关数据
      final tables = [
        'expenses',
        'weight_records',
        'mood_diaries',
        'notes',
        'habits',
        'habit_checkins',
        'user_favorites',
        'user_feedback',
        'reminders',
        'user_novels',
        'user_anniversaries',
        'point_records',
      ];

      await Future.wait(tables.map((table) async {
        try {
          await ApiClient.batchDeleteByFilter(
            table,
            filters: {'user_id': 'eq.$userId'},
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('删除表 $table 失败');
          }
        }
      }));

      // 登出
      await auth.signOut();

      if (mounted) {
        showSnackBar(context, '账号已注销，所有数据已删除');
        // 返回首页
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '注销失败，请稍后重试', isError: true);
      }
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('修改密码'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '旧密码',
                    hintText: '请输入当前密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密码',
                    hintText: '请输入新密码（至少6位）',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '确认新密码',
                    hintText: '请再次输入新密码',
                    prefixIcon: Icon(Icons.lock_person),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final oldPassword = oldPasswordController.text.trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text.trim();

                      if (oldPassword.isEmpty) {
                        showSnackBar(context, '请输入旧密码');
                        return;
                      }
                      if (newPassword.length < 6) {
                        showSnackBar(context, '新密码至少6位');
                        return;
                      }
                      if (newPassword != confirmPassword) {
                        showSnackBar(context, '两次输入的新密码不一致');
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final result = await AuthService.instance.changePassword(
                        oldPassword: oldPassword,
                        newPassword: newPassword,
                      );

                      if (mounted) {
                        setDialogState(() => isLoading = false);
                        if (result['success'] == true) {
                          Navigator.pop(context);
                          showSnackBar(context, result['message'] as String);
                        } else {
                          // TODO: showSnackBar 不支持自定义 backgroundColor，保留原样
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] as String),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('确认修改'),
            ),
          ],
        ),
      ),
    );
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
          showSnackBar(context, '当前已是最新版本');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '检查更新失败，请稍后重试', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }
}


