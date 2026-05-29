import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../config.dart';

/// 版本检查服务 - 支持内部下载安装APK
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  static VersionCheckService get instance => _instance;

  // 下载进度回调
  ValueNotifier<double> downloadProgress = ValueNotifier(0);
  ValueNotifier<String> downloadStatus = ValueNotifier('');

  /// 检查是否需要更新
  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('📱 当前版本: $currentVersion+$currentBuildNumber');

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

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) return null;

        final latestVersion = data.first as Map<String, dynamic>;
        final latestVersionStr = latestVersion['version'] as String;
        final latestBuildNumber = latestVersion['build_number'] as int? ?? 0;
        final isForceUpdate = latestVersion['release_type'] == 'force';

        if (_shouldUpdate(currentVersion, currentBuildNumber, latestVersionStr, latestBuildNumber)) {
          return {
            'version': latestVersionStr,
            'build_number': latestBuildNumber,
            'apk_url': latestVersion['apk_url'],
            'release_notes': latestVersion['release_notes'],
            'is_force_update': isForceUpdate,
            'release_type': latestVersion['release_type'],
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('📱 检查更新失败: $e');
      return null;
    }
  }

  bool _shouldUpdate(String currentVersion, int currentBuild, String latestVersion, int latestBuild) {
    if (latestBuild > currentBuild) return true;
    final currentParts = currentVersion.split('.').map(int.tryParse).toList();
    final latestParts = latestVersion.split('.').map(int.tryParse).toList();
    for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
      final current = currentParts[i] ?? 0;
      final latest = latestParts[i] ?? 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    return latestParts.length > currentParts.length;
  }

  /// 显示更新对话框（带下载进度）
  void showUpdateDialog(BuildContext context, Map<String, dynamic> versionInfo) {
    final isForceUpdate = versionInfo['is_force_update'] == true;
    final apkUrl = versionInfo['apk_url'] as String?;
    final releaseNotes = versionInfo['release_notes'] as String? ?? '';
    final version = versionInfo['version'] as String? ?? '';

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => _UpdateDialog(
        version: version,
        releaseNotes: releaseNotes,
        isForceUpdate: isForceUpdate,
        apkUrl: apkUrl,
        versionService: this,
      ),
    );
  }

  /// 请求安装权限
  Future<bool> requestInstallPermission() async {
    // Android 8+ 需要请求安装未知来源权限
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        return result.isGranted;
      }
      return true;
    }
    return false;
  }

  /// 请求存储权限
  /// Android 10+ 使用应用私有目录，不需要存储权限
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 10 (API 29)+ 使用应用私有目录，不需要存储权限
      // 直接使用 getTemporaryDirectory() 或 getApplicationDocumentsDirectory()
      // 这些目录不需要 READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE 权限
      return true;
    }
    return false;
  }

  /// 下载APK文件
  Future<String?> downloadApk(String apkUrl, {ValueChanged<double>? onProgress}) async {
    try {
      downloadProgress.value = 0;
      downloadStatus.value = '准备下载...';

      // Android 10+ 使用应用私有目录，不需要存储权限
      // 直接使用 getTemporaryDirectory() 保存到缓存目录
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/pure_enjoy_update.apk';
      final file = File(savePath);

      // 如果旧文件存在则删除
      if (await file.exists()) {
        await file.delete();
      }

      downloadStatus.value = '正在下载...';

      // 开始下载
      debugPrint('📱 开始下载APK...');
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      debugPrint('📱 HTTP 状态码: ${response.statusCode}');

      if (response.statusCode != 200) {
        downloadStatus.value = '下载失败: HTTP ${response.statusCode}';
        client.close();
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      debugPrint('📱 文件总大小: $totalBytes bytes');
      int downloadedBytes = 0;

      final sink = file.openWrite();
      bool downloadSuccess = false;

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            downloadProgress.value = progress;
            onProgress?.call(progress);
            downloadStatus.value = '下载中 ${(progress * 100).toStringAsFixed(1)}%';
          }
        },
        onDone: () async {
          debugPrint('📱 下载流完成');
          downloadSuccess = true;
          await sink.close();
          client.close();
        },
        onError: (error) async {
          debugPrint('📱 下载流出错: $error');
          await sink.close();
          client.close();
          downloadStatus.value = '下载失败: $error';
        },
        cancelOnError: true,
      ).asFuture();

      // 验证文件
      if (await file.exists() && await file.length() > 0) {
        downloadProgress.value = 1.0;
        downloadStatus.value = '下载完成';
        return savePath;
      } else {
        downloadStatus.value = '下载失败：文件无效';
        return null;
      }
    } catch (e) {
      downloadStatus.value = '下载出错: $e';
      return null;
    }
  }

  /// 安装APK
  Future<bool> installApk(String filePath) async {
    try {
      downloadStatus.value = '准备安装...';

      // 请求安装权限
      final hasPermission = await requestInstallPermission();
      if (!hasPermission) {
        downloadStatus.value = '安装权限被拒绝，请在设置中允许安装';
        // 引导用户到设置页面
        await openAppSettings();
        return false;
      }

      downloadStatus.value = '正在打开安装器...';

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        downloadStatus.value = '安装成功';
        return true;
      } else if (result.type == ResultType.error) {
        downloadStatus.value = '安装出错: ${result.message}';
        return false;
      } else {
        downloadStatus.value = '安装未完成';
        return false;
      }
    } catch (e) {
      downloadStatus.value = '安装失败: $e';
      return false;
    }
  }

  /// 完整的下载并安装流程
  Future<void> downloadAndInstall(BuildContext context, String apkUrl) async {
    try {
      debugPrint('📱 开始下载并安装流程');
      debugPrint('📱 APK URL: $apkUrl');

      // 1. 下载APK
      final filePath = await downloadApk(apkUrl);
      if (filePath == null) {
        debugPrint('📱 下载失败，filePath 为 null');
        return;
      }

      debugPrint('📱 APK 下载完成，路径: $filePath');

      // 验证文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('📱 错误：下载的文件不存在');
        downloadStatus.value = '下载文件不存在';
        return;
      }

      final fileSize = await file.length();
      debugPrint('📱 文件大小: $fileSize bytes');

      if (fileSize == 0) {
        debugPrint('📱 错误：文件大小为0');
        downloadStatus.value = '下载文件无效（大小为0）';
        return;
      }

      // 2. 安装APK
      debugPrint('📱 开始安装APK...');
      final result = await installApk(filePath);
      debugPrint('📱 安装结果: $result');
    } catch (e, stackTrace) {
      debugPrint('📱 下载安装流程出错: $e');
      debugPrint('📱 堆栈: $stackTrace');
      downloadStatus.value = '更新失败: $e';
    }
  }
}

/// 更新对话框组件
class _UpdateDialog extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final bool isForceUpdate;
  final String? apkUrl;
  final VersionCheckService versionService;

  const _UpdateDialog({
    required this.version,
    required this.releaseNotes,
    required this.isForceUpdate,
    required this.apkUrl,
    required this.versionService,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    widget.versionService.downloadProgress.addListener(_onProgressChanged);
    widget.versionService.downloadStatus.addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    widget.versionService.downloadProgress.removeListener(_onProgressChanged);
    widget.versionService.downloadStatus.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {
        _progress = widget.versionService.downloadProgress.value;
      });
    }
  }

  void _onStatusChanged() {
    if (mounted) {
      setState(() {
        _statusText = widget.versionService.downloadStatus.value;
      });
    }
  }

  Future<void> _startUpdate() async {
    if (widget.apkUrl == null) return;

    setState(() => _isDownloading = true);

    await widget.versionService.downloadAndInstall(context, widget.apkUrl!);

    if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForceUpdate && !_isDownloading,
      child: AlertDialog(
        title: Text(widget.isForceUpdate ? '🔒 强制更新' : '📦 发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新版本: v${widget.version}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (widget.releaseNotes.isNotEmpty) ...[
              const Text(
                '更新内容:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    widget.releaseNotes,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.isForceUpdate)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '此版本为强制更新，必须更新后才能继续使用。',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _statusText,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.isForceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后更新'),
            ),
          FilledButton(
            onPressed: _isDownloading ? null : _startUpdate,
            child: Text(_isDownloading ? '下载中...' : '立即更新'),
          ),
        ],
      ),
    );
  }
}
