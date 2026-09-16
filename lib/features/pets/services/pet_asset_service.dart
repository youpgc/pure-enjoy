import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/pet.dart';
import '../../../services/supabase_service.dart';
import 'pet_service.dart';

/// 3D 资源包服务（单例）：按系资源包的下载 / 校验 / 状态机 / 路径解析
///
/// 设计定版（2026-09-16 对话确认）：
/// - 2D 素材随包本地；3D 按系 zip 资源包线上下载，用户可感知（弹窗/进度/失败重试）；
/// - 三层判定 effective_3d = 系统开关(pet_config) && 用户开关(本机持久化) && 资源包就绪；
/// - 两级校验：轻校验(每次进主页：本地 manifest version == 远端 version 且关键文件存在)；
///   全量校验(下载/更新后：逐文件 SHA256 对比包内 manifest)；
/// - 落盘：ApplicationSupport/pet_assets/<family>/（非 cache 目录，防系统清理）；
///   下载至 .staging 临时目录 → SHA 校验 → 原子换目录，不留半包；
/// - 渲染层只认 [resolveModelPath] 返回的 code → 本地路径，来源可替换（COS+CDN 零改动）。
///
/// 网络边界：清单/开关走 ApiClient（pet_config，DB 唯一入口红线）；zip 二进制
/// 走 dart:io HttpClient 独立下载器（对象存储资源，非 Supabase REST，不触红线）。
class PetAssetService {
  static PetAssetService? _instance;
  PetAssetService._();
  static PetAssetService get instance {
    _instance ??= PetAssetService._();
    return _instance!;
  }

  /// 用户级 3D 开关（设备偏好，非用户数据：不进 CacheHelper 切号清除列表）
  static const String _prefsUserSwitch = 'prefs_pet_render3d_user';

  /// 远端清单缓存新鲜度（与 PetService 门控同缓存 keyGate，低变配置）
  static const Duration _manifestTtl = Duration(minutes: 5);

  final Map<String, PetAssetPackState> _states =
      HashMap<String, PetAssetPackState>();

  /// 全部资源包状态广播（UI 监听刷新：下载进度 / 就绪 / 失败）
  final ValueNotifier<UnmodifiableMapView<String, PetAssetPackState>> states =
      ValueNotifier<UnmodifiableMapView<String, PetAssetPackState>>(
    UnmodifiableMapView<String, PetAssetPackState>({}),
  );

  Directory? _rootDir;

  /// 用户级 3D 开关读取（默认开启；关闭后即使资源就绪也走 2D 兜底）
  Future<bool> isUser3dEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsUserSwitch) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 写入用户级 3D 开关
  Future<void> setUser3dEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsUserSwitch, value);
    } catch (_) {
      // 持久化失败不影响当次会话
    }
  }

  /// 三层判定总开关（B3 渲染层分发依据；资源就绪单独看 [isPackReady]）
  Future<bool> isEffective3dEnabled() async {
    if (!await PetService.instance.isRender3dSystemEnabled()) return false;
    if (!await isUser3dEnabled()) return false;
    return true;
  }

  /// 读取远端资源包清单（pet_config.asset_manifest：family → 元数据）
  Future<Map<String, dynamic>> remoteManifest({bool forceRefresh = false}) async {
    if (SupabaseService.instance.currentUserId == null) return const {};
    try {
      final (data, _) = await PetService.instance.gateConfig(
        forceRefresh: forceRefresh,
        ttl: _manifestTtl,
      );
      final raw = data?['asset_manifest'];
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const {};
    } catch (e) {
      if (kDebugMode) debugPrint('[PetAsset] 清单读取失败: $e');
      return const {};
    }
  }

  /// 轻校验 + 就绪判定（每次进主页调用，毫秒级）：
  /// 本地 manifest version == 远端 version 且 pack 目录存在。
  Future<bool> isPackReady(String family) async {
    final state = await lightCheck(family);
    return state.status == PetAssetPackStatus.ready;
  }

  /// 轻校验：本地 manifest 存在、版本与远端一致、pack 目录在。
  ///
  /// 版本落后 → missing（触发静默更新）；目录缺失/manifest 损坏 → corrupt。
  Future<PetAssetPackState> lightCheck(String family) async {
    if (_states[family] != null &&
        (_states[family]!.status == PetAssetPackStatus.downloading ||
            _states[family]!.status == PetAssetPackStatus.verifying)) {
      return _states[family]!;
    }
    final state = await _doLightCheck(family);
    _publish(family, state);
    return state;
  }

  Future<PetAssetPackState> _doLightCheck(String family) async {
    try {
      final manifest = await _readLocalManifest(family);
      final remote = await remoteManifest();
      final meta = remote[family];
      if (manifest == null || meta is! Map || meta.isEmpty) {
        return PetAssetPackState(
          family: family,
          status: PetAssetPackStatus.missing,
          remoteVersion: _metaVersion(meta),
          remoteSizeBytes: _metaSize(meta),
        );
      }
      final localVersion = manifest['version'] as int? ?? -1;
      final remoteVersion = _metaVersion(meta);
      final familyDir = await _familyDir(family);
      final packDir = Directory(p.join(familyDir.path, 'pack'));
      if (remoteVersion > 0 && localVersion < remoteVersion) {
        // 版本落后：提示更新（下载完成后原子替换，期间旧版可继续渲染）
        return PetAssetPackState(
          family: family,
          status: PetAssetPackStatus.ready,
          version: localVersion,
          remoteVersion: remoteVersion,
          remoteSizeBytes: _metaSize(meta),
          updateAvailable: true,
        );
      }
      if (!await packDir.exists()) {
        return PetAssetPackState(
          family: family,
          status: PetAssetPackStatus.corrupt,
          version: localVersion,
          remoteVersion: remoteVersion,
          remoteSizeBytes: _metaSize(meta),
        );
      }
      return PetAssetPackState(
        family: family,
        status: PetAssetPackStatus.ready,
        version: localVersion,
        remoteVersion: remoteVersion,
        remoteSizeBytes: _metaSize(meta),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PetAsset] 轻校验异常: $e');
      return PetAssetPackState(family: family, status: PetAssetPackStatus.corrupt);
    }
  }

  /// 渲染层唯一入口：speciesCode → 本地 GLB 绝对路径；未就绪返回 null（回退 2D）。
  ///
  /// 约定包内结构：pack/glb/<species_code>.glb（素材命名规范对齐 species code）。
  Future<String?> resolveModelPath(String family, String speciesCode) async {
    final state = await lightCheck(family);
    if (state.status != PetAssetPackStatus.ready) return null;
    final familyDir = await _familyDir(family);
    final file = File(
      p.join(familyDir.path, 'pack', 'glb', '$speciesCode.glb'),
    );
    if (!await file.exists()) return null;
    return file.path;
  }

  /// 下载（或更新）指定系资源包：下载 → 整包 SHA256 → 解压 → 全量校验 → 原子替换。
  ///
  /// 支持断点续传（.part 文件 + Range）；任何一步失败状态置 error/corrupt，
  /// 旧版包不受影响（更新场景）。进度经 [states] 广播。
  Future<bool> downloadPack(String family) async {
    final remote = await remoteManifest(forceRefresh: true);
    final meta = remote[family];
    if (meta is! Map || (meta['url'] as String?) == null) {
      _publish(family, PetAssetPackState(family: family, status: PetAssetPackStatus.error));
      return false;
    }
    final url = meta['url'] as String;
    final expectSha = meta['sha256'] as String?;
    final targetVersion = _metaVersion(meta);
    final sizeBytes = _metaSize(meta);

    _publish(family, PetAssetPackState(
      family: family,
      status: PetAssetPackStatus.downloading,
      remoteVersion: targetVersion,
      remoteSizeBytes: sizeBytes,
    ));

    try {
      final familyDirBase = await _familyDir(family);
      final stagingDir = Directory(p.join(familyDirBase.path, '.staging'));
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);
      final partFile = File(p.join(stagingDir.path, 'pack.zip.part'));

      // 1) 下载（Range 断点续传：.part 已有字节则续传，服务端不支持则重下）
      var downloaded = 0;
      final totalBytes = sizeBytes > 0 ? sizeBytes : -1;
      if (await partFile.exists()) downloaded = await partFile.length();
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse(url));
        if (downloaded > 0) {
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=$downloaded-');
        }
        final resp = await req.close();
        if (downloaded > 0 && resp.statusCode != HttpStatus.partialContent) {
          // 不支持续传：重头下载
          downloaded = 0;
          await partFile.writeAsBytes(<int>[], mode: FileMode.write);
        }
        final sink = partFile.openWrite(mode: FileMode.append);
        try {
          await for (final chunk in resp) {
            await sink.addStream(Stream<List<int>>.value(chunk));
            downloaded += chunk.length;
            _publish(family, PetAssetPackState(
              family: family,
              status: PetAssetPackStatus.downloading,
              remoteVersion: targetVersion,
              remoteSizeBytes: totalBytes,
              downloadedBytes: downloaded,
            ));
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      } finally {
        client.close(force: true);
      }

      // 2) 整包 SHA256 校验
      _publish(family, PetAssetPackState(
        family: family,
        status: PetAssetPackStatus.verifying,
        remoteVersion: targetVersion,
        remoteSizeBytes: totalBytes,
        downloadedBytes: downloaded,
      ));
      if (expectSha != null && expectSha.isNotEmpty) {
        final actual = await _sha256OfFile(partFile);
        if (actual != expectSha) {
          await partFile.delete();
          _publish(family, PetAssetPackState(
            family: family,
            status: PetAssetPackStatus.corrupt,
            remoteVersion: targetVersion,
            remoteSizeBytes: sizeBytes,
          ));
          return false;
        }
      }

      // 3) 解压到 .staging/pack（isolate 内执行：解码+落盘不阻塞 UI）
      final packDir = Directory(p.join(stagingDir.path, 'pack'));
      await packDir.create(recursive: true);
      final extracted = await compute(
        _extractZipSync,
        (partFile.path, packDir.path),
      );
      if (!extracted) {
        _publish(family, PetAssetPackState(
          family: family, status: PetAssetPackStatus.corrupt,
          remoteVersion: targetVersion, remoteSizeBytes: sizeBytes,
        ));
        return false;
      }

      // 4) 全量校验：逐文件 SHA256 对比包内 manifest.json
      final innerManifestFile =
          File(p.join(packDir.path, 'manifest.json'));
      if (!await innerManifestFile.exists()) {
        _publish(family, PetAssetPackState(
          family: family, status: PetAssetPackStatus.corrupt,
          remoteVersion: targetVersion, remoteSizeBytes: sizeBytes,
        ));
        return false;
      }
      final inner = await _readJsonFile(innerManifestFile);
      final files = (inner?['files'] as Map?)?.cast<String, dynamic>() ?? const {};
      for (final entry in files.entries) {
        final f = File(p.join(packDir.path, entry.key));
        if (!await f.exists()) {
          _publish(family, PetAssetPackState(
            family: family, status: PetAssetPackStatus.corrupt,
            remoteVersion: targetVersion, remoteSizeBytes: sizeBytes,
          ));
          return false;
        }
        final expect = entry.value as String?;
        if (expect != null && expect.isNotEmpty) {
          if (await _sha256OfFile(f) != expect) {
            _publish(family, PetAssetPackState(
              family: family, status: PetAssetPackStatus.corrupt,
              remoteVersion: targetVersion, remoteSizeBytes: sizeBytes,
            ));
            return false;
          }
        }
      }

      // 5) 原子换目录：staging 内写本地 manifest → 旧 pack 让位 → staging/pack 上位
      final familyDir = await _familyDir(family);
      final finalPack = Directory(p.join(familyDir.path, 'pack'));
      final oldPack = Directory(p.join(familyDir.path, '.old_pack'));
      if (await oldPack.exists()) await oldPack.delete(recursive: true);
      if (await finalPack.exists()) {
        await finalPack.rename(oldPack.path);
      }
      await packDir.rename(finalPack.path);
      await File(p.join(familyDir.path, 'manifest.json')).writeAsString(
        jsonEncode(<String, dynamic>{
          'version': targetVersion,
          if (expectSha != null && expectSha.isNotEmpty)
            'pack_sha256': expectSha,
        }),
      );
      if (await oldPack.exists()) await oldPack.delete(recursive: true);
      await partFile.delete();

      _publish(family, PetAssetPackState(
        family: family,
        status: PetAssetPackStatus.ready,
        version: targetVersion,
        remoteVersion: targetVersion,
        remoteSizeBytes: sizeBytes,
      ));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[PetAsset] 下载失败: $e');
      _publish(family, PetAssetPackState(
        family: family,
        status: PetAssetPackStatus.error,
        remoteVersion: targetVersion,
        remoteSizeBytes: sizeBytes,
      ));
      return false;
    }
  }

  // ==================== 内部工具 ====================

  int _metaVersion(dynamic meta) =>
      meta is Map ? ((meta['version'] as num?)?.toInt() ?? 0) : 0;

  int _metaSize(dynamic meta) =>
      meta is Map ? ((meta['size_bytes'] as num?)?.toInt() ?? 0) : 0;

  void _publish(String family, PetAssetPackState state) {
    _states[family] = state;
    states.value =
        UnmodifiableMapView<String, PetAssetPackState>(Map.of(_states));
  }

  Future<Directory> _familyDir(String family) async {
    final root = _rootDir ??=
        Directory(p.join((await getApplicationSupportDirectory()).path, 'pet_assets'));
    final dir = Directory(p.join(root.path, family));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Map<String, dynamic>?> _readLocalManifest(String family) async {
    final dir = await _familyDir(family);
    final f = File(p.join(dir.path, 'manifest.json'));
    if (!await f.exists()) return null;
    return _readJsonFile(f);
  }

  Future<Map<String, dynamic>?> _readJsonFile(File f) async {
    try {
      return await compute(_parseJson, await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<String> _sha256OfFile(File f) async {
    return compute(_sha256Sync, f.path);
  }
}

/// 资源包状态（不可变；进度/版本随状态机流转）
@immutable
class PetAssetPackState {
  const PetAssetPackState({
    required this.family,
    required this.status,
    this.version = 0,
    this.remoteVersion = 0,
    this.remoteSizeBytes = 0,
    this.downloadedBytes = 0,
    this.updateAvailable = false,
  });

  final String family;
  final PetAssetPackStatus status;

  /// 本地已就绪版本（0 = 无本地包）
  final int version;

  /// 远端清单版本（> 本地版本即有更新）
  final int remoteVersion;

  /// 远端包体积（bytes；0 = 清单未提供，UI 隐藏体积）
  final int remoteSizeBytes;

  /// 已下载字节（downloading 态进度分母为 remoteSizeBytes）
  final int downloadedBytes;

  /// true = 本地可用但远端有新版（旧版可继续渲染，静默/提示更新）
  final bool updateAvailable;

  double? get progress {
    if (status != PetAssetPackStatus.downloading) return null;
    if (remoteSizeBytes <= 0) return null;
    return (downloadedBytes / remoteSizeBytes).clamp(0.0, 1.0);
  }
}

/// isolate 辅助：JSON 解析（大 manifest 不阻塞 UI）
Map<String, dynamic>? _parseJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}

/// isolate 辅助：整文件 SHA256（90MB 级包体哈希不阻塞 UI）
String _sha256Sync(String path) {
  final file = File(path);
  final digest = sha256.convert(file.readAsBytesSync());
  return digest.toString();
}

/// isolate 辅助：zip 解压落盘（解码在 isolate 内完成，不阻塞 UI）。
///
/// 返回 false = 解码失败；单文件解压失败抛出由调用方捕获。
/// 安全：对每个 entry 做 normalize + isWithin 校验，防 zip path traversal。
bool _extractZipSync((String, String) params) {
  final (zipPath, destDirPath) = params;
  try {
    final destDir = Directory(destDirPath);
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    for (final entry in archive) {
      final outPath = p.normalize(p.join(destDirPath, entry.name));
      if (!p.isWithin(destDirPath, outPath)) continue;
      if (entry.isFile) {
        final data = entry.content as List<int>;
        final outFile = File(outPath);
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(data);
      }
    }
    return destDir.existsSync();
  } catch (e) {
    if (kDebugMode) debugPrint('[PetAsset] 解压失败: $e');
    return false;
  }
}
