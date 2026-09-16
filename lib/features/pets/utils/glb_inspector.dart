import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../constants/pet.dart';

/// GLB（glTF Binary）解析与素材验收结果。
///
/// 只解析 JSON chunk（不解析 BIN/网格数据），可在主 isolate 完成——
/// 单文件 ≤3MB 的量级下毫秒级开销，无需 compute。
class GlbInspectResult {
  const GlbInspectResult({
    required this.fileName,
    required this.fileSizeBytes,
    this.triangleCount = 0,
    this.animationNames = const [],
    this.variantNames = const [],
    this.extensionsUsed = const [],
    this.meshCount = 0,
    this.imageCount = 0,
    this.boneNames = const [],
    this.parseError,
  });

  final String fileName;
  final int fileSizeBytes;

  /// 全部 mesh 三角面数合计（indices accessor count / 3，无索引时按顶点数 / 3 估算）
  final int triangleCount;
  final List<String> animationNames;

  /// glTF material variants（KHR_materials_variants）名称
  final List<String> variantNames;
  final List<String> extensionsUsed;
  final int meshCount;
  final int imageCount;

  /// 骨骼节点名（与 rig 命名规范比对）
  final List<String> boneNames;

  /// 非 null = 文件不是合法 GLB / 解析失败
  final String? parseError;

  bool get draco => extensionsUsed.contains('KHR_draco_mesh_compression');
  bool get ktx2 => extensionsUsed.contains('KHR_texture_basisu');
  bool get hasVariantsExtension => extensionsUsed.contains('KHR_materials_variants');
}

/// 素材验收单项结论
enum AuditVerdict { pass, warn, fail }

/// 素材验收单项
class AuditItem {
  const AuditItem(this.name, this.verdict, this.detail);

  final String name;
  final AuditVerdict verdict;
  final String detail;
}

/// GLB 静态解析器（命名/面数/体积/动画/variants/extensions）
class GlbInspector {
  const GlbInspector._();

  static const int _magicGltf = 0x46546C67; // 'glTF'
  static const int _chunkTypeJson = 0x4E4F534A; // 'JSON'

  /// 解析 GLB 文件（同步读，文件受 3MB 阈值约束，主 isolate 开销可忽略）
  static GlbInspectResult inspectFile(String path) {
    final file = File(path);
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : path;
    Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } catch (e) {
      return GlbInspectResult(
        fileName: name,
        fileSizeBytes: 0,
        parseError: '无法读取文件: $e',
      );
    }
    return inspectBytes(name, bytes);
  }

  /// 解析 GLB 字节（assets 与文件路径共用入口）
  static GlbInspectResult inspectBytes(String fileName, Uint8List bytes) {
    final result = _parse(fileName, bytes);
    return result;
  }

  static GlbInspectResult _parse(String fileName, Uint8List bytes) {
    final size = bytes.length;
    final bd = ByteData.sublistView(bytes);

    if (size < 20) {
      return GlbInspectResult(
        fileName: fileName,
        fileSizeBytes: size,
        parseError: '文件过小，不是合法 GLB',
      );
    }
    if (bd.getUint32(0, Endian.little) != _magicGltf) {
      return GlbInspectResult(
        fileName: fileName,
        fileSizeBytes: size,
        parseError: 'GLB magic 不匹配（可能不是二进制 glTF）',
      );
    }
    // header: magic(4) + version(4) + length(4)，随后第一个 chunk: length(4)+type(4)
    if (bd.getUint32(12, Endian.little) != _chunkTypeJson) {
      return GlbInspectResult(
        fileName: fileName,
        fileSizeBytes: size,
        parseError: '首个 chunk 不是 JSON',
      );
    }
    final jsonLen = bd.getUint32(8, Endian.little) - 12 - 8;
    if (jsonLen <= 0 || 20 + jsonLen > size) {
      return GlbInspectResult(
        fileName: fileName,
        fileSizeBytes: size,
        parseError: 'JSON chunk 长度非法',
      );
    }
    Map<String, dynamic> json;
    try {
      final raw = utf8.decode(bytes.sublist(20, 20 + jsonLen));
      json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (e) {
      return GlbInspectResult(
        fileName: fileName,
        fileSizeBytes: size,
        parseError: 'JSON 解析失败: $e',
      );
    }

    // ---- 三角面数：meshes[].primitives 求和 ----
    var triangles = 0;
    var meshCount = 0;
    final accessors = (json['accessors'] as List?) ?? const [];
    int accessorCount(int? index) {
      if (index == null || index < 0 || index >= accessors.length) return 0;
      final a = accessors[index];
      if (a is! Map) return 0;
      return (a['count'] as num?)?.toInt() ?? 0;
    }

    for (final mesh in (json['meshes'] as List?) ?? const []) {
      if (mesh is! Map) continue;
      meshCount++;
      for (final prim in (mesh['primitives'] as List?) ?? const []) {
        if (prim is! Map) continue;
        final indices = prim['indices'];
        if (indices is Map && indices['accessor'] is int) {
          triangles += accessorCount(indices['accessor'] as int) ~/ 3;
        } else {
          final attrs = prim['attributes'];
          final pos = attrs is Map ? attrs['POSITION'] : null;
          triangles += accessorCount(pos is int ? pos : null) ~/ 3;
        }
      }
    }

    // ---- 动画 ----
    final animations = <String>[
      for (final a in (json['animations'] as List?) ?? const [])
        if (a is Map && a['name'] is String) a['name'] as String,
    ];

    // ---- variants ----
    final variants = <String>[];
    final extRoot = json['extensions'];
    if (extRoot is Map &&
        extRoot['KHR_materials_variants'] is Map &&
        (extRoot['KHR_materials_variants'] as Map)['variants'] is List) {
      for (final v
          in ((extRoot['KHR_materials_variants'] as Map)['variants'] as List)) {
        if (v is Map && v['name'] is String) variants.add(v['name'] as String);
      }
    }

    // ---- extensions ----
    final extensionsUsed = <String>[
      if (json['extensionsUsed'] is List)
        for (final e in json['extensionsUsed'] as List)
          if (e is String) e,
    ];

    // ---- 骨骼节点名（ rig 命名规范比对）----
    final boneNames = <String>[
      for (final n in (json['nodes'] as List?) ?? const [])
        if (n is Map && n['name'] is String) n['name'] as String,
    ];

    final imageCount = ((json['images'] as List?) ?? const []).length;

    return GlbInspectResult(
      fileName: fileName,
      fileSizeBytes: size,
      triangleCount: triangles,
      animationNames: animations,
      variantNames: variants,
      extensionsUsed: extensionsUsed,
      meshCount: meshCount,
      imageCount: imageCount,
      boneNames: boneNames,
    );
  }

  /// 执行验收规则，产出逐项结论（阈值取自 [PetAssetThresholds]）
  static List<AuditItem> audit(GlbInspectResult r) {
    if (r.parseError != null) {
      return [AuditItem('GLB 解析', AuditVerdict.fail, r.parseError!)];
    }
    final items = <AuditItem>[];

    // 1. 体积
    if (r.fileSizeBytes > PetAssetThresholds.maxGlbBytes) {
      items.add(AuditItem(
        '体积',
        AuditVerdict.fail,
        '${fmtBytes(r.fileSizeBytes)} > ${fmtBytes(PetAssetThresholds.maxGlbBytes)}（上限）',
      ));
    } else {
      items.add(AuditItem('体积', AuditVerdict.pass, fmtBytes(r.fileSizeBytes)));
    }

    // 2. 面数
    if (r.triangleCount > PetAssetThresholds.maxTriangleCount) {
      items.add(AuditItem(
        '面数',
        AuditVerdict.fail,
        '${r.triangleCount} 三角面 > ${PetAssetThresholds.maxTriangleCount}（上限）',
      ));
    } else {
      items.add(AuditItem(
        '面数',
        AuditVerdict.pass,
        '${r.triangleCount} 三角面 / ${r.meshCount} mesh',
      ));
    }

    // 3. 压缩
    items.add(AuditItem(
      'Draco 压缩',
      r.draco ? AuditVerdict.pass : AuditVerdict.warn,
      r.draco ? 'KHR_draco_mesh_compression 已启用' : '未启用（POC 底模可接受，量产必须）',
    ));
    items.add(AuditItem(
      'KTX2 纹理',
      r.ktx2 ? AuditVerdict.pass : AuditVerdict.warn,
      r.ktx2 ? 'KHR_texture_basisu 已启用' : '未启用（POC 底模可接受，量产必须）',
    ));

    // 4. 动画命名（命名即契约：全部动画必须来自 8 标准名单）
    if (r.animationNames.isEmpty) {
      items.add(const AuditItem(
        '动画',
        AuditVerdict.warn,
        '未包含动画（POC 静态底模可接受，量产必须含标准动画）',
      ));
    } else {
      final invalid = r.animationNames
          .where((a) => !kPetStandardAnimations.contains(a))
          .toList();
      if (invalid.isNotEmpty) {
        items.add(AuditItem(
          '动画命名',
          AuditVerdict.fail,
          '非标准命名: ${invalid.join(', ')}（标准: ${kPetStandardAnimations.join('/')}）',
        ));
      } else {
        items.add(AuditItem(
          '动画',
          AuditVerdict.pass,
          r.animationNames.join(', '),
        ));
      }
    }

    // 5. variants
    if (r.hasVariantsExtension) {
      final invalid = r.variantNames
          .where((v) => !kPetStandardVariants.contains(v))
          .toList();
      if (invalid.isNotEmpty) {
        items.add(AuditItem(
          '评级 variants',
          AuditVerdict.fail,
          '非标准 variant: ${invalid.join(', ')}（标准: ${kPetStandardVariants.join('/')}）',
        ));
      } else {
        items.add(AuditItem(
          '评级 variants',
          AuditVerdict.pass,
          r.variantNames.join(', '),
        ));
      }
    } else {
      items.add(const AuditItem(
        '评级 variants',
        AuditVerdict.warn,
        '未包含 KHR_materials_variants（量产跨评级链必须）',
      ));
    }

    // 6. 骨骼命名（仅检查标准清单里出现过的缺失，多余节点不罚）
    final missingBones = kPetStandardBones
        .where((b) => !r.boneNames.contains(b))
        .toList();
    if (missingBones.isEmpty) {
      items.add(const AuditItem('骨骼 rig', AuditVerdict.pass, '标准命名齐全'));
    } else {
      items.add(AuditItem(
        '骨骼 rig',
        AuditVerdict.warn,
        '缺少标准骨骼: ${missingBones.join(', ')}（POC 底模可接受，量产必须）',
      ));
    }

    // 7. 文件名规范（对齐 species code；POC 临时底模名不合规仅提示）
    if (PetAssetThresholds.speciesCodePattern.hasMatch(
      r.fileName.replaceAll(RegExp(r'\.glb$', caseSensitive: false), ''),
    )) {
      items.add(const AuditItem('文件名', AuditVerdict.pass, '对齐 species code 规范'));
    } else {
      items.add(const AuditItem(
        '文件名',
        AuditVerdict.warn,
        '不符合 species code 规范（如 cat_n1 / cat_n1_s1.glb）；POC 底模可接受，入库前须改名',
      ));
    }

    return items;
  }

  static String fmtBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(2)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }
}
