import 'package:flutter/material.dart';

import '../models/pet_dex_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_art_resolver.dart';
import '../utils/pet_dict.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_loading.dart';

/// 宠物图鉴（§2026-10-09 收集功能）
///
/// 收集语义：owned = 历史拥有过（含已放生，软删除不熄灭）；
/// 范围 = enabled 形态（三系开闸前仅猫系 30 项，开闸自动扩容无需发版）。
/// 已拥有展示弯曲树中性帧 c1_neutral（与舞台渲染同源同款、静态不动画，
/// 20261021 用户拍板）；无弯曲几何的种属回退整只底图。
/// 未拥有展示中央锁定徽章、名称照常展示。
/// 格子背景板按评级分级：N 素净 → R 淡蓝 → SR 淡紫 → SSR 淡金 + 光晕，
/// 越高级越稀有越突显（渐变顶部混白提质感）。
class PetDexScreen extends StatefulWidget {
  const PetDexScreen({super.key});

  @override
  State<PetDexScreen> createState() => _PetDexScreenState();
}

/// 展示序（服务端 family 按字母序返回，展示按此固定）
const _familyOrder = ['cat', 'dog', 'rabbit', 'mouse'];

const _rarityColors = {
  'N': Colors.grey,
  'R': Color(0xFF4A90D9),
  'SR': Color(0xFF9B59D0),
  'SSR': Color(0xFFD9A441),
};

/// 评级背景板强度分级（20261021 用户需求）：渐变浓度/边框/光晕随评级递增
typedef _PlateSpec = ({double gradTop, double gradBottom, double border, double glow});

_PlateSpec _plateOf(String rarity) => switch (rarity) {
      'SSR' => (gradTop: 0.30, gradBottom: 0.08, border: 0.55, glow: 0.22),
      'SR' => (gradTop: 0.22, gradBottom: 0.06, border: 0.42, glow: 0.0),
      'R' => (gradTop: 0.16, gradBottom: 0.04, border: 0.30, glow: 0.0),
      _ => (gradTop: 0.08, gradBottom: 0.02, border: 0.14, glow: 0.0),
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
          ? const Center(child: PetPawLoading())
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
            Text(PetDict.family(fam.family),
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
      // 卡底淡染评级色，与格子背景板同一层级语言
      color: Color.lerp(
          cs.surfaceContainerHighest.withValues(alpha: 0.4), rarityColor, 0.08),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // 评级角标（渐变底+同色描边，与格子背景板呼应）
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      rarityColor.withValues(alpha: 0.22),
                      rarityColor.withValues(alpha: 0.10),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: rarityColor.withValues(alpha: 0.35)),
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
                  Expanded(
                      child: _stageCell(cs, stage, rarityColor,
                          _plateOf(chain.rarity))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageCell(
      ColorScheme cs,
      PetDexStage stage,
      Color rarityColor,
      _PlateSpec plate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              // 评级背景板：顶部混白的评级渐变 + 同色细边，SSR 另加外圈光晕
              // （渐变顶部提亮是质感关键——纯色叠底会发"土"）
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(rarityColor, Colors.white, 0.45)!
                        .withValues(alpha: plate.gradTop),
                    rarityColor.withValues(alpha: plate.gradBottom),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: rarityColor.withValues(alpha: plate.border)),
                boxShadow: plate.glow > 0
                    ? [
                        BoxShadow(
                            color: rarityColor.withValues(alpha: plate.glow),
                            blurRadius: 10,
                            offset: const Offset(0, 2)),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(4),
              child: stage.owned
                  // 弯曲树中性帧：与舞台渲染同源同款（静态，不跑待机动画）
                  ? _dexPetArt(cs, stage)
                  // 未获取：系骨架剪影（压暗，不剧透形态细节）+ 锁定徽章叠加
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.45,
                          child: Image.asset(
                            petPlaceholderArt(stage.speciesCode,
                                _dexArtKey(stage.speciesCode).$2),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 32, height: 32),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    rarityColor.withValues(alpha: 0.40)),
                          ),
                          child: Icon(Icons.lock_outline_rounded,
                              size: 16,
                              color: rarityColor.withValues(alpha: 0.80)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 4),
          // 名称照常展示（未获取不再用「？？？」）
          Text(
            stage.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: stage.owned ? cs.onSurface : cs.onSurfaceVariant),
          ),
          // 日期行恒占位等高：只有已获取格有「获得日」时该格会撑高整行，
          // 同排其余格被拉出基线（20261021 用户截图实证的错位根因）
          SizedBox(
            height: 13,
            child: (stage.owned && stage.firstAt != null)
                ? Text(
                    '${stage.firstAt!.month}.${stage.firstAt!.day} 获得',
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// 图鉴格静态形象：弯曲树的中性帧 c1_neutral（舞台渲染的基底图，与主页
  /// 形象同源同款；不跑待机动画——20261021 用户拍板）。
  ///
  /// dex 种属行码带阶后缀（cat_ssr1_s1），弯曲树按「种属 + sN 目录」组织，
  /// 先解耦再取材；路径以 kPetBendGeo 登记为准（登记 = 随包，铁律 8）。
  /// 无弯曲几何的种属兜底占位图标。
  Widget _dexPetArt(ColorScheme cs, PetDexStage stage) {
    final (code, st) = _dexArtKey(stage.speciesCode);
    final img = petBaseArt(code, st);
    if (img == null) {
      return Icon(Icons.cruelty_free_outlined,
          size: 34, color: cs.onSurfaceVariant);
    }
    return Image.asset(img,
        fit: BoxFit.contain,
        cacheWidth: (96 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, __, ___) => Icon(Icons.cruelty_free_outlined,
            size: 34, color: cs.onSurfaceVariant));
  }

  /// 种属行码 → (渲染素材键, 阶)；无 `_sN` 后缀即基础阶
  (String, int) _dexArtKey(String speciesCode) {
    final m = RegExp(r'^(.+)_s(\d+)$').firstMatch(speciesCode);
    return m != null
        ? (m.group(1)!, int.tryParse(m.group(2)!) ?? 0)
        : (speciesCode, 0);
  }
}
