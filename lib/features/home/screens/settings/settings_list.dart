import 'package:flutter/material.dart';
import '../../widgets/section_header.dart';

/// 系统设置列表（纯展示，状态由父级管理）
class SettingsList extends StatelessWidget {
  final bool isDarkMode;
  final double fontScale;
  final bool autoSync;
  final bool wifiOnly;
  final bool pushNotification;
  final bool dailyReminder;
  final bool anniversaryReminder;

  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onFontSizeTap;
  final ValueChanged<bool> onAutoSyncChanged;
  final ValueChanged<bool> onWifiOnlyChanged;
  final ValueChanged<bool> onPushNotifChanged;
  final ValueChanged<bool> onDailyReminderChanged;
  final ValueChanged<bool> onAnniversaryReminderChanged;
  final VoidCallback onClearCacheTap;
  final VoidCallback onChangePasswordTap;
  final VoidCallback onDeleteAccountTap;

  const SettingsList({
    super.key,
    required this.isDarkMode,
    required this.fontScale,
    required this.autoSync,
    required this.wifiOnly,
    required this.pushNotification,
    required this.dailyReminder,
    required this.anniversaryReminder,
    required this.onDarkModeChanged,
    required this.onFontSizeTap,
    required this.onAutoSyncChanged,
    required this.onWifiOnlyChanged,
    required this.onPushNotifChanged,
    required this.onDailyReminderChanged,
    required this.onAnniversaryReminderChanged,
    required this.onClearCacheTap,
    required this.onChangePasswordTap,
    required this.onDeleteAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 同步设置
        const SectionHeader(title: '同步设置'),
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: const Text('自动同步'),
          subtitle: const Text('连接网络时自动同步数据'),
          value: autoSync,
          onChanged: onAutoSyncChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi),
          title: const Text('仅WiFi同步'),
          subtitle: const Text('移动网络下不同步数据'),
          value: wifiOnly,
          onChanged: onWifiOnlyChanged,
        ),

        // 通知设置
        const SectionHeader(title: '通知设置'),
        // [FCM 待接入·占位开关] 当前为 UI 占位与偏好持久化，无远程推送通道故不触发实际逻辑。
        // 接入方案见 settings_screen.dart 的 onPushNotifChanged 注释（依赖 firebase_messaging /
        // 启动 getToken 上报 / 服务端按 fcm_token 下发 / onMessage 转本地通知 / 总闸 deleteToken）。
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('推送通知'),
          subtitle: const Text('接收系统推送通知'),
          value: pushNotification,
          onChanged: onPushNotifChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.alarm),
          title: const Text('每日提醒'),
          subtitle: const Text('每天提醒记录体重和心情'),
          value: dailyReminder,
          onChanged: onDailyReminderChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.cake_outlined),
          title: const Text('纪念日提醒'),
          subtitle: const Text('纪念日到期前提醒'),
          value: anniversaryReminder,
          onChanged: onAnniversaryReminderChanged,
        ),

        // 数据管理
        const SectionHeader(title: '数据管理'),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('清除缓存'),
          subtitle: const Text('清除本地缓存数据'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onClearCacheTap,
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('修改密码'),
          subtitle: const Text('修改登录密码'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onChangePasswordTap,
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
          title: Text('注销账号', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          subtitle: const Text('永久删除账号及所有数据'),
          trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.error),
          onTap: onDeleteAccountTap,
        ),
      ],
    );
  }
}
