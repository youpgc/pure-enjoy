import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../core/theme/app_theme.dart';
import 'api_client.dart';

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

      final result = await ApiClient.get(
        'app_versions',
        filters: {'status': 'eq.released'},
        order: 'created_at.desc',
        limit: 1,
      );

      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        debugPrint('📱 未获取到最新版本或请求失败');
        return null;
      }

      final latestVersion = result.data!.first;
      // 统一版本号格式：去掉 v 前缀
      final latestVersionStr = (latestVersion['version'] as String).replaceFirst('v', '');
      final latestBuildNumber = latestVersion['build_number'] as int? ?? 0;
      final isForceUpdate = latestVersion['release_type'] == 'force';

      debugPrint('📱 最新版本: $latestVersionStr+$latestBuildNumber');

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

  /// GitHub 国内镜像加速地址列表（按优先级排序）
  /// 当 GitHub 直接访问失败时，依次尝试这些镜像
  static const List<String> _githubMirrors = [
    '', // 空字符串表示直接访问 GitHub（原始地址）
    'https://ghproxy.com/',
    'https://mirror.ghproxy.com/',
    'https://ghps.cc/',
  ];

  /// 将 GitHub URL 转换为镜像 URL
  String _getMirrorUrl(String originalUrl, int mirrorIndex) {
    if (mirrorIndex == 0 || mirrorIndex >= _githubMirrors.length) {
      return originalUrl;
    }
    final mirror = _githubMirrors[mirrorIndex];
    // 镜像服务通常需要完整的 https:// 前缀
    if (originalUrl.startsWith('https://')) {
      return '$mirror$originalUrl';
    }
    return originalUrl;
  }

  /// 下载APK文件
  /// 支持 GitHub Releases 下载，自动使用国内镜像加速
  /// 当某个镜像失败时，自动切换到下一个镜像重试
  Future<String?> downloadApk(String apkUrl, {ValueChanged<double>? onProgress}) async {
    // 尝试所有镜像地址（包括原始地址）
    for (int mirrorIndex = 0; mirrorIndex < _githubMirrors.length; mirrorIndex++) {
      final tryUrl = _getMirrorUrl(apkUrl, mirrorIndex);
      final mirrorName = mirrorIndex == 0 ? 'GitHub直连' : _githubMirrors[mirrorIndex];

      debugPrint('📱 尝试下载 [$mirrorName]: $tryUrl');
      downloadStatus.value = '正在连接${mirrorIndex > 0 ? " (镜像${mirrorIndex})" : ""}...';

      final result = await _downloadFromUrl(tryUrl, onProgress: onProgress);
      if (result != null) {
        debugPrint('📱 ✅ 下载成功 via $mirrorName');
        return result;
      }

      debugPrint('📱 ❌ $mirrorName 下载失败，尝试下一个...');
    }

    // 所有镜像都失败了
    downloadStatus.value = '下载失败：所有镜像均不可用，请检查网络连接';
    return null;
  }

  /// 从指定 URL 下载 APK（内部方法）
  /// [redirectDepth] 递归跟踪重定向时的深度，防止无限循环
  Future<String?> _downloadFromUrl(String apkUrl, {ValueChanged<double>? onProgress, int redirectDepth = 0}) async {
    if (redirectDepth > 5) {
      debugPrint('📱 重定向次数过多，放弃下载');
      return null;
    }

    // URL 为空或无效时直接返回
    if (apkUrl.isEmpty) {
      debugPrint('📱 URL 为空，跳过');
      return null;
    }

    final uri = Uri.tryParse(apkUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      // 可能是相对路径（镜像服务器的重定向地址没有完整 scheme/host）
      // 无法处理，直接返回失败
      debugPrint('📱 URL 缺少 host: $apkUrl');
      return null;
    }
    // 使用独立的 http.Client 下载，不经过共享 HttpClient
    // 避免注入 Supabase headers（apikey 等）导致 CDN 拒绝请求
    // 避免共享 Client 被关闭或超时影响其他 API 请求
    final client = http.Client();
    try {
      downloadProgress.value = 0;

      // Android 10+ 使用应用私有目录，不需要存储权限
      // 直接使用 getTemporaryDirectory() 保存到缓存目录
      final dir = await getTemporaryDirectory();

      // 从URL中提取版本号作为文件名，避免缓存旧版本
      final urlFileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'pure_enjoy_update.apk';
      final savePath = '${dir.path}/$urlFileName';
      final file = File(savePath);

      // 如果旧文件存在则删除
      if (await file.exists()) {
        await file.delete();
      }

      // 同时清理旧格式的缓存文件
      try {
        final oldFile = File('${dir.path}/pure_enjoy_update.apk');
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (_) {}

      // 使用独立 Client 发送请求，不注入任何额外 headers
      final request = http.Request('GET', uri);
      request.headers['Accept'] = '*/*';
      request.headers['User-Agent'] = 'PureEnjoy/1.0';

      final response = await client.send(request).timeout(const Duration(minutes: 5));

      debugPrint('📱 HTTP 状态码: ${response.statusCode}');

      // 处理重定向（GitHub Releases 返回 302 到 CDN）
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          debugPrint('📱 跟随重定向: $redirectUrl');
          // 关闭当前 response stream 后跟随重定向
          response.stream.listen((_) {}).cancel();
          return await _downloadFromUrl(redirectUrl, onProgress: onProgress, redirectDepth: redirectDepth + 1);
        }
      }

      if (response.statusCode != 200) {
        debugPrint('📱 HTTP 错误: ${response.statusCode}');
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      debugPrint('📱 文件总大小: $totalBytes bytes');
      int downloadedBytes = 0;

      final sink = file.openWrite();

      downloadStatus.value = '正在下载...';

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            downloadProgress.value = progress;
            onProgress?.call(progress);
            downloadStatus.value = '下载中 ${(progress * 100).toStringAsFixed(1)}%';
          } else {
            // 未知大小时显示已下载大小
            downloadStatus.value = '下载中 ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB';
          }
        },
        onDone: () async {
          debugPrint('📱 下载流完成');
          await sink.close();
        },
        onError: (error) async {
          debugPrint('📱 下载流出错: $error');
          await sink.close();
        },
        cancelOnError: true,
      ).asFuture();

      // 验证文件
      if (await file.exists() && await file.length() > 0) {
        downloadProgress.value = 1.0;
        downloadStatus.value = '下载完成';
        return savePath;
      } else {
        debugPrint('📱 文件验证失败');
        return null;
      }
    } catch (e) {
      debugPrint('📱 下载异常: $e');
      return null;
    } finally {
      // 确保关闭独立 Client，不影响共享 HttpClient
      client.close();
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
        downloadStatus.value = '已打开安装页面，请在弹出的安装窗口中点击"安装"';
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
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '此版本为强制更新，必须更新后才能继续使用。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
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
