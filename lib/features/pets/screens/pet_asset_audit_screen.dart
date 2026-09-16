import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/glb_inspector.dart';

/// S1 素材验收页（量产管线基础设施：不合规不入库）。
///
/// 校验项：体积 ≤3MB / 面数 ≤15k / Draco / KTX2 / 动画命名（8 标准）/
/// 评级 variants（N/R/SR/SSR）/ 骨骼 rig 命名 / 文件名对齐 species code。
/// 结果分 PASS / WARN / FAIL——WARN 为 POC 底模可接受、量产必须整改项。
class PetAssetAuditScreen extends StatefulWidget {
  const PetAssetAuditScreen({super.key});

  @override
  State<PetAssetAuditScreen> createState() => _PetAssetAuditScreenState();
}

class _PetAssetAuditScreenState extends State<PetAssetAuditScreen> {
  final TextEditingController _pathCtrl = TextEditingController();

  /// 来源标签 → 验收结果列表
  final Map<String, List<GlbInspectResult>> _results = {};
  bool _scanning = false;
  String _scanNote = '';

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('宠物素材验收')),
      body: Column(
        children: [
          _sourceBar(cs),
          const Divider(height: 1),
          if (_scanning) const LinearProgressIndicator(),
          Expanded(child: _resultList(cs)),
        ],
      ),
    );
  }

  // ==================== 来源选择 ====================

  Widget _sourceBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _scanning ? null : _scanAssets,
                child: const Text('① assets/pets_poc'),
              ),
              FilledButton.tonal(
                onPressed: _scanning ? null : _scanPackCache,
                child: const Text('② 资源包缓存'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  decoration: const InputDecoration(
                    hintText: '③ 单文件路径（.../cat_n1.glb）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _scanning ? null : _auditOnePath,
                child: const Text('验收'),
              ),
            ],
          ),
          if (_scanNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_scanNote, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Future<void> _scanAssets() async {
    setState(() {
      _scanning = true;
      _scanNote = '正在扫描 assets/pets_poc ...';
    });
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest
          .listAssets()
          .where((a) => a.startsWith('assets/pets_poc/') && a.endsWith('.glb'))
          .toList();
      final results = <GlbInspectResult>[];
      for (final a in assets) {
        try {
          final data = (await rootBundle.load(a)).buffer.asUint8List();
          results.add(GlbInspector.inspectBytes(p.basename(a), data));
        } catch (e) {
          results.add(GlbInspectResult(
            fileName: p.basename(a), fileSizeBytes: 0, parseError: 'asset 读取失败: $e',
          ));
        }
      }
      setState(() {
        _results['assets/pets_poc'] = results;
        _scanNote = results.isEmpty ? 'assets/pets_poc 下没有 .glb（先把底模放入并重新构建）' : '';
      });
    } catch (e) {
      setState(() => _scanNote = 'asset 清单读取失败: $e');
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _scanPackCache() async {
    setState(() {
      _scanning = true;
      _scanNote = '正在扫描资源包缓存 ...';
    });
    final results = <GlbInspectResult>[];
    var root = '';
    try {
      final support = await getApplicationSupportDirectory();
      root = p.join(support.path, 'pet_assets');
      final assetsRoot = Directory(root);
      if (await assetsRoot.exists()) {
        await for (final familyDir in assetsRoot.list()) {
          if (familyDir is! Directory) continue;
          final glbDir = Directory(p.join(familyDir.path, 'pack', 'glb'));
          if (!await glbDir.exists()) continue;
          await for (final f in glbDir.list()) {
            if (f is File && f.path.toLowerCase().endsWith('.glb')) {
              results.add(GlbInspector.inspectFile(f.path));
            }
          }
        }
      }
      setState(() {
        _results['资源包缓存'] = results;
        _scanNote = results.isEmpty ? '缓存目录无 GLB（$root）' : '';
      });
    } catch (e) {
      setState(() => _scanNote = '扫描失败: $e');
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _auditOnePath() async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _scanning = true;
      _scanNote = '正在验收 $path';
    });
    final r = GlbInspector.inspectFile(path);
    setState(() {
      _results.putIfAbsent('单文件', () => []).removeWhere((x) => x.fileName == r.fileName);
      _results['单文件']!.add(r);
      _scanNote = '';
    });
    if (mounted) setState(() => _scanning = false);
  }

  // ==================== 结果展示 ====================

  Widget _resultList(ColorScheme cs) {
    if (_results.isEmpty) {
      return Center(
        child: Text('选择来源开始验收', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in _results.entries) ...[
          Text(entry.key, style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
          const SizedBox(height: 8),
          for (final r in entry.value)
            _resultCard(cs, r),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _resultCard(ColorScheme cs, GlbInspectResult r) {
    final items = GlbInspector.audit(r);
    final hasFail = items.any((i) => i.verdict == AuditVerdict.fail);
    final hasWarn = items.any((i) => i.verdict == AuditVerdict.warn);
    final color = hasFail ? const Color(0xFFE53935) : (hasWarn ? const Color(0xFFFB8C00) : const Color(0xFF43A047));
    final label = hasFail ? 'FAIL' : (hasWarn ? 'WARN（量产须整改）' : 'PASS');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (r.parseError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(r.parseError!, style: TextStyle(color: color, fontSize: 13)),
              )
            else ...[
              const SizedBox(height: 8),
              Text(
                '${GlbInspector.fmtBytes(r.fileSizeBytes)} · ${r.triangleCount} 三角面 · '
                '${r.meshCount} mesh · ${r.imageCount} 贴图',
                style: const TextStyle(fontSize: 12),
              ),
              if (r.animationNames.isNotEmpty)
                Text('动画: ${r.animationNames.join(', ')}', style: const TextStyle(fontSize: 12)),
              if (r.variantNames.isNotEmpty)
                Text('variants: ${r.variantNames.join(', ')}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (item.verdict) {
                          AuditVerdict.pass => Icons.check_circle,
                          AuditVerdict.warn => Icons.warning_amber_rounded,
                          AuditVerdict.fail => Icons.cancel,
                        },
                        size: 16,
                        color: switch (item.verdict) {
                          AuditVerdict.pass => const Color(0xFF43A047),
                          AuditVerdict.warn => const Color(0xFFFB8C00),
                          AuditVerdict.fail => const Color(0xFFE53935),
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${item.name}：${item.detail}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
