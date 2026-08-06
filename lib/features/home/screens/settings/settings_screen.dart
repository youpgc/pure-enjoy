import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../services/api_client.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../core/widgets/widgets.dart';
import './settings_list.dart';
import './settings_dialogs.dart';
import './settings_helpers.dart';

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

  // 持久化到 SharedPreferences 的设置
  bool _autoSync = true;
  bool _wifiOnly = true;
  // [FCM 待接入·占位开关] 推送通知总闸。
  //   目前 App 无任何远程推送通道（pubspec 无 firebase_messaging，lib 内只有 flutter_local_notifications 本地通知），
  //   故该开关仅为 UI 占位与用户偏好持久化，不触发任何实际逻辑。接入 FCM 后的行为见 onPushNotifChanged。
  bool _pushNotification = true;
  bool _dailyReminder = true;
  bool _anniversaryReminder = true;

  // SharedPreferences keys
  static const _autoSyncKey = 'setting_auto_sync';
  static const _wifiOnlyKey = 'setting_wifi_only';
  // [FCM 待接入] 推送通知总闸 key。接入方案见 onPushNotifChanged 注释。
  static const _pushNotifKey = 'setting_push_notification';
  static const _dailyReminderKey = 'setting_daily_reminder';
  static const _anniversaryReminderKey = 'setting_anniversary_reminder';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final tp = ref.read(themeProvider);
    _isDarkMode = tp.isDarkMode;
    _fontScale = tp.fontScale;

    // 加载持久化设置
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _autoSync = prefs.getBool(_autoSyncKey) ?? true;
          _wifiOnly = prefs.getBool(_wifiOnlyKey) ?? true;
          _pushNotification = prefs.getBool(_pushNotifKey) ?? true;
          _dailyReminder = prefs.getBool(_dailyReminderKey) ?? true;
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
        autoSync: _autoSync,
        wifiOnly: _wifiOnly,
        pushNotification: _pushNotification,
        dailyReminder: _dailyReminder,
        anniversaryReminder: _anniversaryReminder,
        onDarkModeChanged: (val) {
          setState(() => _isDarkMode = val);
          ref.read(themeProvider).setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
        },
        onFontSizeTap: _showFontSizeDialog,
        onAutoSyncChanged: (val) {
          setState(() => _autoSync = val);
          _saveBoolSetting(_autoSyncKey, val);
          // 开关立即生效：关闭后后台不再自动补发；开启后立即补发挂起队列
          OfflineSyncService.instance.syncPending();
        },
        onWifiOnlyChanged: (val) {
          setState(() => _wifiOnly = val);
          _saveBoolSetting(_wifiOnlyKey, val);
          // 开关立即生效：解除/启用 WiFi 限制后立即尝试同步（非 WiFi 时按限制跳过）
          OfflineSyncService.instance.syncPending();
        },
        // [FCM 待接入·占位逻辑] 当前仅持久化用户偏好，不触发任何推送行为（无 FCM 通道）。
        // —— 接入方案（待实施）——
        // 1. 依赖：pubspec.yaml 增加 `firebase_messaging`（及 `firebase_core`）；
        //    移动端放置 google-services.json / GoogleService-Info.plist，并配置 APNs。
        // 2. 启动初始化：在 main.dart / auth_provider 登录成功后调用
        //    `FirebaseMessaging.instance.requestPermission()` 申请通知权限，
        //    取 `FirebaseMessaging.instance.getToken()` 得到设备 FCM token。
        // 3. 上报 token：将 token 写入用户表（如 users.fcm_token 或独立 user_devices 表），
        //    并在 token 刷新 (`onTokenRefresh`) 时同步更新。
        // 4. 服务端推送：由 Supabase Edge Function / 定时函数按目标 fcm_token 下发通知
        //    （纯享现有习惯/待办/纪念日提醒如要上云推送，也走此链路）。
        // 5. 消息处理：注册 `FirebaseMessaging.onMessage`（前台）与
        //    `FirebaseMessaging.onBackgroundMessage`（后台/退出态）回调，
        //    统一转交 flutter_local_notifications 弹出本地通知。
        // 6. 总闸联动：本开关为总闸——关闭时调用 `FirebaseMessaging.instance.deleteToken()`
        //    （或上报后端置 is_push_enabled=false 停止下发）；开启时重新 getToken 并上报。
        // 注：在 1~6 落地前，本回调保持"只存不生效"，避免误导。
        onPushNotifChanged: (val) {
          setState(() => _pushNotification = val);
          _saveBoolSetting(_pushNotifKey, val);
        },
        onDailyReminderChanged: (val) {
          setState(() => _dailyReminder = val);
          _saveBoolSetting(_dailyReminderKey, val);
          // 总闸立即生效：重新挂接习惯+待办提醒（关闭时按总闸取消已调度的提醒）
          NotificationService.instance.armHabitRemindersFromRemote().catchError((e) {});
          NotificationService.instance.armRemindersFromRemote().catchError((e) {});
        },
        onAnniversaryReminderChanged: (val) {
          setState(() => _anniversaryReminder = val);
          _saveBoolSetting(_anniversaryReminderKey, val);
          // 总闸立即生效：重新挂接纪念日提醒（关闭时按总闸取消已调度的提醒）
          NotificationService.instance.armAnniversariesFromRemote().catchError((e) {});
        },
        onClearCacheTap: () => showClearCacheDialog(context, _clearCache),
        onChangePasswordTap: _showChangePasswordDialog,
        onDeleteAccountTap: () => showDeleteAccountDialog(context, _deleteAccount),
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

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 只清除非设置类的缓存，保留用户设置
      final keysToRemove = prefs.getKeys().where((key) =>
        !key.startsWith('theme_') &&
        !key.startsWith('font_') &&
        !key.startsWith('color_') &&
        !key.startsWith('setting_') &&
        key != 'user'
      ).toList();
      await Future.wait(keysToRemove.map((key) => prefs.remove(key)));

      if (mounted) {
        showSnackBar(context, '缓存已清除（${keysToRemove.length}项）');
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
}


