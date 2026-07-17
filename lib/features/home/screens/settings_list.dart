import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';
import '../widgets/section_header.dart';
import 'settings_helpers.dart';

/// 系统设置列表（纯展示，状态由父级管理）
class SettingsList extends StatelessWidget {
  final bool isDarkMode;
  final double fontScale;
  final ReaderBackgroundTheme readerBg;
  final bool autoSync;
  final bool wifiOnly;
  final bool pushNotification;
  final bool dailyReminder;
  final bool anniversaryReminder;
  final String currentVersion;
  final bool isCheckingUpdate;
  final String? latestVersion;

  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onFontSizeTap;
  final VoidCallback onReadingBgTap;
  final ValueChanged<bool> onAutoSyncChanged;
  final ValueChanged<bool> onWifiOnlyChanged;
  final ValueChanged<bool> onPushNotifChanged;
  final ValueChanged<bool> onDailyReminderChanged;
  final ValueChanged<bool> onAnniversaryReminderChanged;
  final VoidCallback onClearCacheTap;
  final VoidCallback onChangePasswordTap;
  final VoidCallback onDeleteAccountTap;
  final VoidCallback onAboutTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onAgreementTap;
  final VoidCallback onHelpTap;
  final VoidCallback onFeedbackTap;
  final VoidCallback onCheckUpdateTap;

  const SettingsList({
    super.key,
    required this.isDarkMode,
    required this.fontScale,
    required this.readerBg,
    required this.autoSync,
    required this.wifiOnly,
    required this.pushNotification,
    required this.dailyReminder,
    required this.anniversaryReminder,
    required this.currentVersion,
    required this.isCheckingUpdate,
    required this.latestVersion,
    required this.onDarkModeChanged,
    required this.onFontSizeTap,
    required this.onReadingBgTap,
    required this.onAutoSyncChanged,
    required this.onWifiOnlyChanged,
    required this.onPushNotifChanged,
    required this.onDailyReminderChanged,
    required this.onAnniversaryReminderChanged,
    required this.onClearCacheTap,
    required this.onChangePasswordTap,
    required this.onDeleteAccountTap,
    required this.onAboutTap,
    required this.onPrivacyTap,
    required this.onAgreementTap,
    required this.onHelpTap,
    required this.onFeedbackTap,
    required this.onCheckUpdateTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 阅读设置
        const SectionHeader(title: '阅读设置'),
        SwitchListTile(
          secondary: const Icon(Icons.nightlight_outlined),
          title: const Text('深色模式'),
          subtitle: const Text('切换深色/浅色主题'),
          value: isDarkMode,
          onChanged: onDarkModeChanged,
        ),
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: const Text('字体大小'),
          subtitle: Text(scaleToFontSize(fontScale)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onFontSizeTap,
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('阅读背景'),
          subtitle: Text(bgToName(readerBg)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onReadingBgTap,
        ),

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

        // 关于与法律
        const SectionHeader(title: '关于与法律'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于纯享'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onAboutTap,
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('隐私政策'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onPrivacyTap,
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('用户协议'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onAgreementTap,
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('帮助中心'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onHelpTap,
        ),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('问题反馈'),
          subtitle: const Text('提交问题与建议'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onFeedbackTap,
        ),
        // 版本信息
        const SectionHeader(title: '版本'),
        ListTile(
          leading: const Icon(Icons.system_update_outlined),
          title: const Text('检查更新'),
          subtitle: Text(isCheckingUpdate
              ? '检查中...'
              : latestVersion != null
                  ? '发现新版本: $latestVersion'
                  : currentVersion.isEmpty
                      ? '加载中...'
                      : '当前版本: $currentVersion'),
          trailing: isCheckingUpdate
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: isCheckingUpdate ? null : onCheckUpdateTap,
        ),
      ],
    );
  }
}
