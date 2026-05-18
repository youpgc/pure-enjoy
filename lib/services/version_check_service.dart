import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

/// 版本检查服务
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  static VersionCheckService get instance => _instance;

  /// 检查是否需要更新
  /// 返回最新版本信息，如果不需要更新则返回null
  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      print('📱 当前版本: $currentVersion+$currentBuildNumber');

      // 从Supabase获取最新版本
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/app_versions?status=eq.released&order=created_at.desc&limit=1',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      print('📱 版本检查响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          print('📱 没有已发布的版本');
          return null;
        }

        final latestVersion = data.first as Map<String, dynamic>;
        final latestVersionStr = latestVersion['version'] as String;
        final latestBuildNumber = latestVersion['build_number'] as int? ?? 0;
        final isForceUpdate = latestVersion['is_force_update'] == true;

        print('📱 最新版本: $latestVersionStr+$latestBuildNumber, 强制更新: $isForceUpdate');

        // 比较版本号
        if (_shouldUpdate(currentVersion, currentBuildNumber, latestVersionStr, latestBuildNumber)) {
          return {
            'version': latestVersionStr,
            'build_number': latestBuildNumber,
            'apk_url': latestVersion['apk_url'],
            'release_notes': latestVersion['release_notes'],
            'is_force_update': isForceUpdate,
          };
        }
      }

      return null;
    } catch (e) {
      print('📱 检查更新失败: $e');
      return null;
    }
  }

  /// 比较版本号，判断是否需要更新
  bool _shouldUpdate(String currentVersion, int currentBuild, String latestVersion, int latestBuild) {
    // 先比较build number
    if (latestBuild > currentBuild) {
      return true;
    }
    
    // 如果build number相同，比较版本号
    final currentParts = currentVersion.split('.').map(int.tryParse).toList();
    final latestParts = latestVersion.split('.').map(int.tryParse).toList();
    
    for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
      final current = currentParts[i] ?? 0;
      final latest = latestParts[i] ?? 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    
    // 版本号相同但latest有更多位数
    return latestParts.length > currentParts.length;
  }

  /// 显示更新对话框
  void showUpdateDialog(BuildContext context, Map<String, dynamic> versionInfo) {
    final isForceUpdate = versionInfo['is_force_update'] == true;
    final apkUrl = versionInfo['apk_url'] as String?;
    final releaseNotes = versionInfo['release_notes'] as String? ?? '';
    final version = versionInfo['version'] as String? ?? '';

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate, // 强制更新时不可关闭
      builder: (context) => WillPopScope(
        onWillPop: () async => !isForceUpdate, // 强制更新时禁止返回
        child: AlertDialog(
          title: Text(isForceUpdate ? '强制更新' : '发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最新版本: $version'),
              const SizedBox(height: 8),
              if (releaseNotes.isNotEmpty) ...[
                const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(releaseNotes, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
              ],
              if (isForceUpdate)
                const Text(
                  '此版本为强制更新，必须更新后才能继续使用。',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('稍后更新'),
              ),
            FilledButton(
              onPressed: apkUrl != null ? () => _downloadUpdate(context, apkUrl) : null,
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  /// 下载更新
  Future<void> _downloadUpdate(BuildContext context, String apkUrl) async {
    try {
      final uri = Uri.parse(apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载链接')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
}
