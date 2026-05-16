import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supabase 配置
class _VersionConfig {
  static const String supabaseUrl = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6';
}

/// 版本检查服务 - 使用 Supabase REST API
class VersionCheckService {
  static VersionCheckService? _instance;

  VersionCheckService._();

  static VersionCheckService get instance {
    _instance ??= VersionCheckService._();
    return _instance!;
  }

  /// 获取当前版本号
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 检查更新 - 调用 Supabase REST API 获取最新版本
  Future<VersionInfo?> checkUpdate() async {
    try {
      // 获取当前版本号
      final currentVersion = await getCurrentVersion();

      // 调用 Supabase REST API 获取最新已发布版本
      final uri = Uri.parse(
        '${_VersionConfig.supabaseUrl}/rest/v1/app_versions'
        '?is_active=eq.true&status=eq.released'
        '&order=created_at.desc&limit=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'apikey': _VersionConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${_VersionConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('版本检查失败: ${response.statusCode}');
        return null;
      }

      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        return null;
      }

      final latest = data.first as Map<String, dynamic>;
      final latestVersion = latest['version'] as String? ?? '';

      // 比较版本号
      final compareResult = _compareVersions(currentVersion, latestVersion);
      if (compareResult >= 0) {
        // 当前版本已是最新或更高
        return null;
      }

      // 判断是否为强制更新
      final releaseType = latest['release_type'] as String? ?? 'feature';
      final isForceUpdate = releaseType == 'force';

      return VersionInfo(
        version: latestVersion,
        buildNumber: latest['build_number'] as int? ?? 0,
        downloadUrl: latest['apk_url'] as String?,
        releaseNotes: latest['release_notes'] as String?,
        releaseType: releaseType,
        forceUpdate: isForceUpdate,
        releasedAt: latest['released_at'] as String?,
      );
    } catch (e) {
      debugPrint('版本检查异常: $e');
      return null;
    }
  }

  /// 比较版本号，返回 1 表示 v1 > v2，-1 表示 v1 < v2，0 表示相等
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (var i = 0; i < maxLen; i++) {
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

  /// 显示更新弹窗
  Future<void> showUpdateDialog(BuildContext context, VersionInfo info) async {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (context) => PopScope(
        canPop: !info.forceUpdate,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('发现新版本'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '最新版本: v${info.version}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
                const Text(
                  '更新内容:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
              if (info.forceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '此版本为强制更新，请立即升级',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                  ),
                ),
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
                if (info.downloadUrl != null && info.downloadUrl!.isNotEmpty) {
                  openDownloadPage(info.downloadUrl!);
                }
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 版本信息
class VersionInfo {
  final String version;
  final int buildNumber;
  final String? downloadUrl;
  final String? releaseNotes;
  final String releaseType;
  final bool forceUpdate;
  final String? releasedAt;

  VersionInfo({
    required this.version,
    this.buildNumber = 0,
    this.downloadUrl,
    this.releaseNotes,
    this.releaseType = 'feature',
    this.forceUpdate = false,
    this.releasedAt,
  });
}
