import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/widgets/widgets.dart';
import './api_client.dart';
import './apk_installer.dart';
import './update_dialog.dart';

/// 版本检查服务 - 支持内部下载安装APK
///
/// 更新检测**不做跨进程持久缓存**——它是前后两个缺陷的总根子：
/// - 持久缓存"无更新"结论被原样信任 1 小时 → 新版本发布后最多 1 小时黑洞，
///   自动与手动两条通道都取不到更新（2026-10-11 v1.11.3 实证，含强更被吞）；
/// - 持久缓存旧版本信息 → 内部更新重启后与已装版本追平误报（2026-10-10 修）。
/// 现改为**进程内 5 分钟内存缓存**：同一会话内省请求；安装新版本必然新进程，
/// 内存必空 → 装完立刻能查到下一个版本。「稍后更新」忽略（dismiss）在读取时
/// 拦截自动弹窗，手动检查（force）绕过缓存与忽略，永远直连服务器。
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

  static const String _dismissedVersionKey = 'dismissed_update_version';

  /// 进程内检查结论缓存：{'info': 版本信息或 null}——null 表示"服务器最新 =
  /// 当前已装"。强更结论不入缓存（强更每次实时确认，不吞不延）。
  static Map<String, dynamic>? _memResult;
  static DateTime? _memAt;
  static const Duration _memTtl = Duration(minutes: 5);

  static Map<String, dynamic>? _memHit() {
    final at = _memAt;
    if (_memResult == null || at == null) return null;
    if (DateTime.now().difference(at) >= _memTtl) {
      _memResult = null;
      _memAt = null;
      return null;
    }
    return _memResult;
  }

  static void _memStore(Map<String, dynamic>? info) {
    _memResult = {'info': info};
    _memAt = DateTime.now();
  }

  /// 检查是否需要更新（首页/启动自动通道）
  ///
  /// 「稍后更新」忽略在读取时拦截（含进程内缓存命中路径）；强更不受忽略限制
  /// 且永不复用缓存。
  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString(_dismissedVersionKey);

      final mem = _memHit();
      if (mem != null) {
        final info = mem['info'] as Map<String, dynamic>?;
        if (info != null &&
            dismissedVersion != null &&
            info['version'] == dismissedVersion) {
          if (kDebugMode) debugPrint('📱 用户已忽略 v${info['version']} 更新提示');
          return null;
        }
        if (kDebugMode) {
          debugPrint('📱 使用进程内检查结论（${DateTime.now().difference(_memAt!).inSeconds} 秒前）');
        }
        return info;
      }

      final current = await _currentInfo();
      final latest = await _fetchLatest();
      if (current == null || latest == null) return null;

      final needUpdate = _shouldUpdate(
          current.$1, current.$2, latest['version'] as String, latest['build'] as int);
      final isForce = latest['force'] as bool;

      Map<String, dynamic>? versionInfo;
      if (needUpdate) {
        versionInfo = _infoFrom(latest);
        // 已被「稍后更新」忽略的非强更：不弹（结论仍入缓存，供我的页手动更新）
        if (!isForce &&
            dismissedVersion != null &&
            dismissedVersion == latest['version']) {
          if (kDebugMode) debugPrint('📱 用户已忽略 v${latest['version']} 的更新提示');
          _memStore(versionInfo);
          return null;
        }
      }

      // 强更结论不入缓存：下次检查实时再确认
      if (!isForce) _memStore(versionInfo);
      return versionInfo;
    } catch (e) {
      if (kDebugMode) debugPrint('📱 检查更新失败');
      return null;
    }
  }

  /// 获取最新版本信息（不受「稍后更新」忽略状态影响）。
  ///
  /// 用于「我的」页面展示可用版本与手动触发更新：
  /// - [force] = true（用户手动点击）绕过进程内缓存直连服务器——运营发版后
  ///   立即手动检查必须即时可见，不得吃旧结论；
  /// - 返回 null 表示当前已是最新或网络/数据不可用。
  Future<Map<String, dynamic>?> getLatestVersionInfo({bool force = false}) async {
    try {
      if (!force) {
        final mem = _memHit();
        if (mem != null) return mem['info'] as Map<String, dynamic>?;
      }

      final current = await _currentInfo();
      final latest = await _fetchLatest();
      if (current == null || latest == null) return null;

      if (!_shouldUpdate(current.$1, current.$2,
          latest['version'] as String, latest['build'] as int)) {
        if (kDebugMode) debugPrint('📱 [手动] 当前已是最新');
        _memStore(null);
        return null;
      }

      if (kDebugMode) debugPrint('📱 [手动] 最新版本获取成功 v${latest['version']}');
      final info = _infoFrom(latest);
      _memStore(info);
      return info;
    } catch (e) {
      if (kDebugMode) debugPrint('📱 [手动] 获取最新版本失败');
      return null;
    }
  }

  /// 当前已安装版本（version, buildNumber）；读取失败返回 null
  Future<(String, int)?> _currentInfo() async {
    try {
      final p = await PackageInfo.fromPlatform();
      return (p.version, int.tryParse(p.buildNumber) ?? 0);
    } catch (_) {
      return null;
    }
  }

  /// 拉取服务器最新 released 版本（含防御：版本号空/缺下载地址均视为不可用）
  Future<Map<String, dynamic>?> _fetchLatest() async {
    final result = await ApiClient.get(
      'app_versions',
      filters: {'status': 'eq.released', 'platform': 'eq.android'},
      order: 'created_at.desc',
      limit: 1,
    );
    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      if (kDebugMode) debugPrint('📱 未获取到最新版本或请求失败');
      return null;
    }
    final row = result.data!.first;
    // 统一版本号格式：只去锚定开头的 v 前缀（无锚定的 replaceFirst 会吃掉
    // 任意位置的首个 v，如 "1.0.dev"→"1.0.de"，审查报告 版本#8）
    final version = ((row['version'] as String?) ?? '')
        .replaceFirst(RegExp('^v'), '');
    final apkUrl = row['apk_url'] as String?;
    if (version.isEmpty || apkUrl == null || apkUrl.isEmpty) {
      if (kDebugMode) debugPrint('📱 最新版本数据不完整（版本号/下载地址缺失），跳过');
      return null;
    }
    return {
      'version': version,
      'build': row['build_number'] as int? ?? 0,
      'force': row['is_force_update'] == true,
      'row': row,
    };
  }

  Map<String, dynamic> _infoFrom(Map<String, dynamic> latest) {
    final row = latest['row'] as Map;
    return {
      'version': latest['version'],
      'build_number': latest['build'],
      'apk_url': row['apk_url'],
      'github_url': row['github_url'],
      'release_notes': row['release_notes'],
      'is_force_update': latest['force'],
      'release_type': row['release_type'],
      'checksum': row['checksum'],
    };
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
    // 忽略动作即时生效：清进程内结论，下次检查重新走网络（dismiss 在读取时拦截）
    _memResult = null;
    _memAt = null;
    if (kDebugMode) debugPrint('📱 已忽略 v$version 的更新提示');
  }

  /// 显示更新对话框（带下载进度）
  void showUpdateDialog(BuildContext context, Map<String, dynamic> versionInfo) {
    final isForceUpdate = versionInfo['is_force_update'] == true;
    final apkUrl = versionInfo['apk_url'] as String?;
    final fallbackUrl = versionInfo['github_url'] as String?;
    final releaseNotes = versionInfo['release_notes'] as String? ?? '';
    final version = versionInfo['version'] as String? ?? '';
    final checksum = versionInfo['checksum'] as String?;

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
        checksum: checksum,
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
    String? checksum,
  }) =>
      _installer.downloadAndInstall(
        context,
        apkUrl,
        fallbackUrl: fallbackUrl,
        checksum: checksum,
      );
}
