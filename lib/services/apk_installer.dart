import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import './http_client.dart';

/// APK 下载与安装子系统
///
/// 从 [VersionCheckService] 抽取，行为与原有实现完全一致。
/// 持有下载进度 / 状态两个通知器，由外层 [VersionCheckService] 透传给 UI
/// （[UpdateDialog] 监听 `downloadProgress` / `downloadStatus`）。
class ApkInstaller {
  final ValueNotifier<double> downloadProgress;
  final ValueNotifier<String> downloadStatus;

  ApkInstaller({
    required this.downloadProgress,
    required this.downloadStatus,
  });

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
  /// 优先从 Gitee 下载（国内快），失败时回退到 GitHub Releases（备份源）
  Future<String?> downloadApk(
    String apkUrl, {
    String? fallbackUrl,
    ValueChanged<double>? onProgress,
  }) async {
    if (kDebugMode) debugPrint('📱 开始下载 APK: $apkUrl');
    downloadStatus.value = '正在连接...';

    // 优先尝试主下载源（Gitee）
    var result = await _downloadFromUrl(apkUrl, onProgress: onProgress);
    if (result != null) {
      if (kDebugMode) debugPrint('📱 ✅ 主源下载成功');
      return result;
    }

    // 主源失败，尝试备用源（GitHub）
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      if (kDebugMode) debugPrint('📱 主源失败，尝试备用源: $fallbackUrl');
      downloadStatus.value = '主源连接失败，尝试备用源...';
      result = await _downloadFromUrl(fallbackUrl, onProgress: onProgress);
      if (result != null) {
        if (kDebugMode) debugPrint('📱 ✅ 备用源下载成功');
        return result;
      }
    }

    downloadStatus.value = '下载失败：请检查网络连接';
    return null;
  }

  /// 从指定 URL 下载 APK（内部方法）
  /// [redirectDepth] 递归跟踪重定向时的深度，防止无限循环
  Future<String?> _downloadFromUrl(
    String apkUrl, {
    ValueChanged<double>? onProgress,
    int redirectDepth = 0,
  }) async {
    if (redirectDepth > 5) {
      if (kDebugMode) debugPrint('📱 重定向次数过多，放弃下载');
      return null;
    }

    // URL 为空或无效时直接返回
    if (apkUrl.isEmpty) {
      if (kDebugMode) debugPrint('📱 URL 为空，跳过');
      return null;
    }

    final uri = Uri.tryParse(apkUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      // 可能是相对路径（镜像服务器的重定向地址没有完整 scheme/host）
      // 无法处理，直接返回失败
      if (kDebugMode) debugPrint('📱 URL 缺少 host');
      return null;
    }
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
      } catch (e) {
        if (kDebugMode) {
          debugPrint('删除旧文件失败: $e');
        }
      }

      // 使用 HttpClient.getRawStream 发送请求（不注入 Supabase 认证头）
      final response = await HttpClient.instance.getRawStream(
        apkUrl,
        timeout: const Duration(minutes: 5),
      );

      if (kDebugMode) debugPrint('📱 HTTP 状态码: ${response.statusCode}');

      // 处理重定向（GitHub Releases 返回 302 到 CDN）
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          if (kDebugMode) debugPrint('📱 跟随重定向');
          // drain 当前 response stream 释放连接，避免资源泄漏
          await response.stream.drain<void>();
          return await _downloadFromUrl(
            redirectUrl,
            onProgress: onProgress,
            redirectDepth: redirectDepth + 1,
          );
        }
      }

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('📱 HTTP 错误: ${response.statusCode}');
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      if (kDebugMode) debugPrint('📱 文件总大小: $totalBytes bytes');
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
          if (kDebugMode) debugPrint('📱 下载流完成');
          await sink.close();
        },
        onError: (error) async {
          if (kDebugMode) debugPrint('📱 下载流出错');
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
        if (kDebugMode) debugPrint('📱 文件验证失败');
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('📱 下载异常');
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
  /// [apkUrl] 主下载源（Gitee），[fallbackUrl] 备用下载源（GitHub）
  Future<void> downloadAndInstall(
    BuildContext context,
    String apkUrl, {
    String? fallbackUrl,
  }) async {
    try {
      if (kDebugMode) debugPrint('📱 开始下载并安装流程');
      if (kDebugMode) debugPrint('📱 APK URL 已设置');

      // 1. 下载APK（优先主源，失败回退备用源）
      final filePath = await downloadApk(apkUrl, fallbackUrl: fallbackUrl);
      if (filePath == null) {
        if (kDebugMode) debugPrint('📱 下载失败，filePath 为 null');
        return;
      }

      if (kDebugMode) debugPrint('📱 APK 下载完成');

      // 验证文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) debugPrint('📱 错误：下载的文件不存在');
        downloadStatus.value = '下载文件不存在';
        return;
      }

      final fileSize = await file.length();
      if (kDebugMode) debugPrint('📱 文件大小: $fileSize bytes');

      if (fileSize == 0) {
        if (kDebugMode) debugPrint('📱 错误：文件大小为0');
        downloadStatus.value = '下载文件无效（大小为0）';
        return;
      }

      // 2. 安装APK
      if (kDebugMode) debugPrint('📱 开始安装APK...');
      final result = await installApk(filePath);
      if (kDebugMode) debugPrint('📱 安装结果: $result');
    } catch (e) {
      if (kDebugMode) debugPrint('📱 下载安装流程出错');
      if (kDebugMode) debugPrint('📱 堆栈信息');
      downloadStatus.value = '更新失败: $e';
    }
  }
}
