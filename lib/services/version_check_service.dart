import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/widgets/widgets.dart';
import './api_client.dart';
import './apk_installer.dart';
import './update_dialog.dart';

/// 版本检查服务 - 支持内部下载安装APK
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal() {
    _installer = ApkInstaller(
      downloadProgress: downloadProgress,
      downloadStatus: downloadStatus,
    );
  }

  static VersionCheckService get instance => _instance;

  // 下载进度回调
  final ValueNotifier<double> downloadProgress = ValueNotifier(0);
  final ValueNotifier<String> downloadStatus = ValueNotifier('');

  /// APK 下载与安装子系统（从本类抽取，行为与原实现一致）
  late final ApkInstaller _installer;

  // 版本检查缓存配置
  static const String _versionCheckCacheKey = 'version_check_cache';
  static const String _dismissedVersionKey = 'dismissed_update_version';
  static const Duration _minCheckInterval = Duration(hours: 1);

  /// 检查是否需要更新
  /// 使用 SharedPreferences 缓存检查结果，1 小时内重复调用直接返回缓存
  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 最先检查：用户是否已忽略当前最新版本的��新提示
      // 此检查必须在缓存检查之前，确保无论缓存命中还是网络请求，dismiss 都生效
      final dismissedVersion = prefs.getString(_dismissedVersionKey);

      final cacheJson = prefs.getString(_versionCheckCacheKey);

      // 提前读取当前已安装版本：缓存命中时需用它复核版本是否真的需要更新，
      // 避免内部更新重启后旧缓存把已装上的版本误报为待更新版本。
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 读取缓存
      if (cacheJson != null && cacheJson.isNotEmpty) {
        try {
          final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
          final lastCheckTime = DateTime.tryParse(cache['timestamp'] as String? ?? '');
          final cachedVersionInfo = cache['versionInfo'] as Map<String, dynamic>?;

          if (lastCheckTime != null) {
            final elapsed = DateTime.now().difference(lastCheckTime);
            // 强制更新不受缓存限制，始终需要检查
            final isForce = cachedVersionInfo?['is_force_update'] == true;

            if (elapsed < _minCheckInterval && !isForce) {
              // 缓存命中时也要检查 dismiss
              if (cachedVersionInfo != null && dismissedVersion != null) {
                final cachedVer = cachedVersionInfo['version'] as String?;
                if (cachedVer == dismissedVersion) {
                  if (kDebugMode) debugPrint('📱 用户已忽略缓存中的 v$cachedVer 更新提示');
                  return null;
                }
              }
              // 【修复】内部更新重启后，当前已安装版本可能已追平缓存中的最新版本，
              // 需用当前版本复核：若已是最新则清除陈旧缓存并返回 null，避免误报更新。
              if (cachedVersionInfo != null) {
                final cachedVer = cachedVersionInfo['version'] as String? ?? '';
                final cachedBuild = cachedVersionInfo['build_number'] as int? ?? 0;
                if (!_shouldUpdate(currentVersion, currentBuildNumber, cachedVer, cachedBuild)) {
                  if (kDebugMode) {
                    debugPrint('📱 当前已安装版本 v$currentVersion 已是最新，缓存为旧数据，清除并跳过更新提示');
                  }
                  await prefs.remove(_versionCheckCacheKey);
                  return null;
                }
              }
              if (kDebugMode) {
                debugPrint('📱 使用缓存结果（${elapsed.inMinutes} 分钟前检查过）');
              }
              return cachedVersionInfo;
            }
          }
        } catch (e) {
          // 缓存解析失败，继续走网络请求
          if (kDebugMode) debugPrint('📱 缓存解析失败，重新检查');
        }
      }

      if (kDebugMode) debugPrint('📱 当前版本检查');

      final result = await ApiClient.get(
        'app_versions',
        filters: {'status': 'eq.released'},
        order: 'created_at.desc',
        limit: 1,
      );

      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        if (kDebugMode) debugPrint('📱 未获取到最新版本或请求失败');
        return null;
      }

      final latestVersion = result.data!.first;
      // 统一版本号格式：去掉 v 前缀
      final latestVersionStr = (latestVersion['version'] as String).replaceFirst('v', '');
      final latestBuildNumber = latestVersion['build_number'] as int? ?? 0;
      final isForceUpdate = latestVersion['release_type'] == 'force';
      final apkUrl = latestVersion['apk_url'] as String?;

      // 防御：没有下载地址时不提示更新（数据不完整）
      if (apkUrl == null || apkUrl.isEmpty) {
        if (kDebugMode) debugPrint('📱 最新版本缺少下载地址，跳过更新提示');
        return null;
      }

      if (kDebugMode) debugPrint('📱 最新版本获取成功');

      Map<String, dynamic>? versionInfo;
      if (_shouldUpdate(currentVersion, currentBuildNumber, latestVersionStr, latestBuildNumber)) {
        // 检查用户是否已忽略此版本的更新提示（网络请求路径也要检查，防止 dismiss 后缓存过期重新弹出）
        if (!isForceUpdate && dismissedVersion == latestVersionStr) {
          if (kDebugMode) debugPrint('📱 用户已忽略 v$latestVersionStr 的更新提示');
          return null;
        }

        versionInfo = {
          'version': latestVersionStr,
          'build_number': latestBuildNumber,
          'apk_url': apkUrl,
          'github_url': latestVersion['github_url'],
          'release_notes': latestVersion['release_notes'],
          'is_force_update': isForceUpdate,
          'release_type': latestVersion['release_type'],
        };
      }

      // 写入缓存（无论是否需要更新都缓存）
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'versionInfo': versionInfo,
      };
      await prefs.setString(_versionCheckCacheKey, jsonEncode(cacheData));

      return versionInfo;
    } catch (e) {
      if (kDebugMode) debugPrint('📱 检查更新失败');
      return null;
    }
  }

  /// 判断是否需要更新
  /// 综合比较版本号(version)和构建号(build_number)：
  ///   1. 优先比较版本号（如 1.9.231 vs 1.9.238）
  ///   2. 版本号相同时，比较构建号（如 +283 vs +284）
  ///   3. 两者中有任意一个更大即提示更新
  bool _shouldUpdate(String currentVersion, int currentBuild, String latestVersion, int latestBuild) {
    // 1. 比较版本号（分段比较，如 1.9.231 vs 1.9.238）
    final currentParts = currentVersion.split('.').map(int.tryParse).toList();
    final latestParts = latestVersion.split('.').map(int.tryParse).toList();

    int versionCompare = 0;
    final maxLen = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;
    for (int i = 0; i < maxLen; i++) {
      final current = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      final latest = (i < latestParts.length ? latestParts[i] : 0) ?? 0;
      if (latest > current) {
        versionCompare = 1;
        break;
      } else if (latest < current) {
        versionCompare = -1;
        break;
      }
    }

    // 2. 比较构建号
    final buildCompare = latestBuild.compareTo(currentBuild);

    // 3. 综合判断：版本号更大，或版本号相同但构建号更大
    if (versionCompare > 0) {
      if (kDebugMode) debugPrint('📱 需要更新: 版本号');
      return true;
    }
    if (versionCompare == 0 && buildCompare > 0) {
      if (kDebugMode) debugPrint('📱 需要更新: 构建号');
      return true;
    }

    if (kDebugMode) debugPrint('📱 无需更新');
    return false;
  }

  /// 用户忽略此版本的更新提示（强制更新不可忽略）。
  /// 仅对该版本号生效；期间发布更新的版本仍会立即提示。
  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
    if (kDebugMode) debugPrint('📱 已忽略 v$version 的更新提示');
  }

  /// 获取最新版本信息（不受「稍后更新」ignore 状态影响）。
  ///
  /// 用于「我的」页面展示可用版本、以及点击版本信息时手动触发更新。
  /// - 不修改 dismiss 状态，也不抑制自动弹窗（自动弹窗仍由 [checkUpdate] 控制）。
  /// - 与 [checkUpdate] 共享 1 小时缓存；即使该版本已被「稍后更新」忽略，
  ///   缓存中仍保留其最新版本信息，这里直接返回，从而允许手动更新。
  /// - 返回 null 表示当前已是最新或网络/数据不可用。
  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_versionCheckCacheKey);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 优先复用 1 小时内的新鲜缓存（与 checkUpdate 共享）
      if (cacheJson != null && cacheJson.isNotEmpty) {
        try {
          final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
          final lastCheckTime = DateTime.tryParse(cache['timestamp'] as String? ?? '');
          final cachedVersionInfo = cache['versionInfo'] as Map<String, dynamic>?;
          if (lastCheckTime != null) {
            final elapsed = DateTime.now().difference(lastCheckTime);
            if (elapsed < _minCheckInterval) {
              // 缓存明确为最新版本信息（即便已被忽略也保留）→ 直接返回
              if (cachedVersionInfo != null) {
                if (kDebugMode) {
                  debugPrint('📱 [手动] 使用缓存最新版本 v${cachedVersionInfo['version']}');
                }
                return cachedVersionInfo;
              }
              return null; // 缓存明确为无更新
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('📱 [手动] 缓存解析失败，重新检查');
        }
      }

      // 缓存失效 → 走网络
      final result = await ApiClient.get(
        'app_versions',
        filters: {'status': 'eq.released'},
        order: 'created_at.desc',
        limit: 1,
      );
      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        if (kDebugMode) debugPrint('📱 [手动] 未获取到最新版本或请求失败');
        return null;
      }

      final latestVersion = result.data!.first;
      final latestVersionStr = (latestVersion['version'] as String).replaceFirst('v', '');
      final latestBuildNumber = latestVersion['build_number'] as int? ?? 0;
      final apkUrl = latestVersion['apk_url'] as String?;

      // 防御：没有下载地址时不提示更新（数据不完整）
      if (apkUrl == null || apkUrl.isEmpty) {
        if (kDebugMode) debugPrint('📱 [手动] 最新版本缺少下载地址');
        return null;
      }

      // 已是最新则不返回
      if (!_shouldUpdate(currentVersion, currentBuildNumber, latestVersionStr, latestBuildNumber)) {
        if (kDebugMode) debugPrint('📱 [手动] 当前已是最新');
        return null;
      }

      if (kDebugMode) debugPrint('📱 [手动] 最新版本获取成功 v$latestVersionStr');
      return {
        'version': latestVersionStr,
        'build_number': latestBuildNumber,
        'apk_url': apkUrl,
        'github_url': latestVersion['github_url'],
        'release_notes': latestVersion['release_notes'],
        'is_force_update': latestVersion['release_type'] == 'force',
        'release_type': latestVersion['release_type'],
      };
    } catch (e) {
      if (kDebugMode) debugPrint('📱 [手动] 获取最新版本失败');
      return null;
    }
  }

  /// 显示更新对话框（带下载进度）
  void showUpdateDialog(BuildContext context, Map<String, dynamic> versionInfo) {
    final isForceUpdate = versionInfo['is_force_update'] == true;
    final apkUrl = versionInfo['apk_url'] as String?;
    final fallbackUrl = versionInfo['github_url'] as String?;
    final releaseNotes = versionInfo['release_notes'] as String? ?? '';
    final version = versionInfo['version'] as String? ?? '';

    // 防御：没有下载地址时不弹出更新对话框
    if (apkUrl == null || apkUrl.isEmpty) {
      if (kDebugMode) debugPrint('📱 下载地址为空，跳过更新对话框');
      showSnackBar(context, '发现新版本但下载地址暂不可用，请稍后重试');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => UpdateDialog(
        version: version,
        releaseNotes: releaseNotes,
        isForceUpdate: isForceUpdate,
        apkUrl: apkUrl,
        fallbackUrl: fallbackUrl,
        versionService: this,
      ),
    );
  }

  /// 完整的下载并安装流程（委托 [ApkInstaller]，行为与原有实现一致）
  /// [apkUrl] 主下载源（Gitee），[fallbackUrl] 备用下载源（GitHub）
  Future<void> downloadAndInstall(
    BuildContext context,
    String apkUrl, {
    String? fallbackUrl,
  }) =>
      _installer.downloadAndInstall(
        context,
        apkUrl,
        fallbackUrl: fallbackUrl,
      );
}
