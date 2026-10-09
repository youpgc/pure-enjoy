import 'package:flutter/material.dart';

import '../models/pet_dex_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_art_resolver.dart';
import '../utils/pet_errors.dart';

/// 宠物图鉴（§2026-10-09 收集功能）
///
/// 收集语义：owned = 历史拥有过（含已放生，软删除不熄灭）；
/// 范围 = enabled 形态（三系开闸前仅猫系 30 项，开闸自动扩容无需发版）。
/// 未拥有形态灰位"？"占位（防剧透，素材本就未产出）。
class PetDexScreen extends StatefulWidget {
  const PetDexScreen({super.key});

  @override
  State<PetDexScreen> createState() => _PetDexScreenState();
}

/// 展示序（服务端 family 按字母序返回，展示按此固定）
const _familyOrder = ['cat', 'dog', 'rabbit', 'mouse'];
const _familyNames = {'cat': '猫系', 'dog': '犬系', 'rabbit': '兔系', 'mouse': '鼠系'};

const _rarityColors = {
  'N': Colors.grey,
  'R': Color(0xFF4A90D9),
  'SR': Color(0xFF9B59D0),
  'SSR': Color(0xFFD9A441),
};

class _PetDexScreenState extends State<PetDexScreen> {
  PetDexModel? _dex;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (dex, err) = await PetRpc.fetchDex();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _dex = dex;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('宠物图鉴')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(cs)
              : _dex == null || _dex!.families.isEmpty
                  ? Center(
                      child: Text('图鉴暂无内容',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : RefreshIndicator(onRefresh: _load, child: _list(cs)),
    );
  }

  Widget _errorView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('图鉴加载失败', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(petRpcErrorText(_error),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _list(ColorScheme cs) {
    final dex = _dex!;
    // 展示序固定：猫/犬/兔/鼠（服务端为字母序）
    final fams = [
      for (final f in _familyOrder)
        if (dex.families.any((x) => x.family == f))
          dex.families.firstWhere((x) => x.family == f),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        // 收集进度头
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('已收集 ${dex.ownedTotal} / ${dex.total}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700))),
                    Text(
                        '${dex.total == 0 ? 0 : (dex.ownedTotal * 100 / dex.total).round()}%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: dex.total == 0
                        ? 0
                        : (dex.ownedTotal / dex.total).clamp(0.0, 1.0),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final fam in fams) ..._familySection(cs, fam),
      ],
    );
  }

  List<Widget> _familySection(ColorScheme cs, PetDexFamily fam) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(
          children: [
            Text(_familyNames[fam.family] ?? fam.family,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text(
                '${fam.chains.fold<int>(0, (a, c) => a + c.ownedN)} / ${fam.chains.fold<int>(0, (a, c) => a + c.n)}',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
      for (final chain in fam.chains) _chainCard(cs, chain),
    ];
  }

  Widget _chainCard(ColorScheme cs, PetDexChain chain) {
    final rarityColor = _rarityColors[chain.rarity] ?? Colors.grey;
    final complete = chain.ownedN >= chain.n;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // 评级角标
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(chain.rarity,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rarityColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    complete
                        ? '进化链已完成'
                        : chain.ownedN == 0
                            ? '未发现'
                            : '收集 ${chain.ownedN}/${chain.n}',
                    style: TextStyle(
                        fontSize: 12,
                        color: complete ? cs.primary : cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final stage in chain.stages)
                  Expanded(child: _stageCell(cs, stage)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageCell(ColorScheme cs, PetDexStage stage) {
    final img = stage.owned ? petPortraitArt(stage.speciesCode) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: stage.owned
                    ? Border.all(color: cs.primary.withValues(alpha: 0.35))
                    : null,
              ),
              padding: const EdgeInsets.all(4),
              child: stage.owned
                  ? (img != null
                      ? Image.asset(img,
                          fit: BoxFit.contain,
                          cacheWidth: (72 * MediaQuery.devicePixelRatioOf(context)).round(),
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.cruelty_free_outlined,
                              size: 28,
                              color: cs.onSurfaceVariant))
                      : Icon(Icons.cruelty_free_outlined,
                          size: 28, color: cs.onSurfaceVariant))
                  : Center(
                      child: Text('？',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5)))),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stage.owned ? stage.name : '？？？',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: stage.owned ? cs.onSurface : cs.onSurfaceVariant),
          ),
          if (stage.owned && stage.firstAt != null)
            Text(
              '${stage.firstAt!.month}.${stage.firstAt!.day} 获得',
              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
