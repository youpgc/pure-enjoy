import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 版本检查服务
class VersionCheckService {
  static VersionCheckService? _instance;
  late final SupabaseClient _client;
  
  VersionCheckService._() {
    _client = Supabase.instance.client;
  }
  
  static VersionCheckService get instance {
    _instance ??= VersionCheckService._();
    return _instance!;
  }
  
  /// 获取当前版本
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
  
  /// 检查更新
  Future<VersionInfo?> checkUpdate() async {
    try {
      final response = await _client
          .from('app_versions')
          .select()
          .eq('platform', Platform.isAndroid ? 'android' : 'ios')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response == null) return null;
      
      final currentVersion = await getCurrentVersion();
      final latestVersion = response['version'] as String;
      
      if (_compareVersions(latestVersion, currentVersion) > 0) {
        return VersionInfo(
          version: latestVersion,
          downloadUrl: response['download_url'] as String?,
          releaseNotes: response['release_notes'] as String?,
          forceUpdate: response['force_update'] as bool? ?? false,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('检查更新失败: $e');
      return null;
    }
  }
  
  /// 比较版本号
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    
    return 0;
  }
  
  /// 打开下载页面
  Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  /// 显示更新对话框
  Future<void> showUpdateDialog(BuildContext context, VersionInfo info) async {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本: ${info.version}'),
            if (info.releaseNotes != null) ...[
              const SizedBox(height: 8),
              Text('更新内容:'),
              const SizedBox(height: 4),
              Text(info.releaseNotes!),
            ],
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后再说'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (info.downloadUrl != null) {
                openDownloadPage(info.downloadUrl!);
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}

/// 版本信息
class VersionInfo {
  final String version;
  final String? downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  VersionInfo({
    required this.version,
    this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
  });
}
