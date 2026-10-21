import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../../../constants/pet.dart';
import '../models/pet_p2_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_errors.dart';

/// 抽蛋概率公示页（P2）
///
/// 数据源 `pet_egg_pools`（published 且取每个 pool_code 的最高 config_version），
/// **与服务端判定同源**：抽蛋时写入审计流水的 config_version 与这里展示的是同一行，
/// 客户端不参与任何概率推算、也不为未配置项补默认值（铁律 1、2）——
/// 后台没配的行（如性别比）直接不显示，避免把猜测值当成对外承诺。
class PetOddsScreen extends StatefulWidget {
  const PetOddsScreen({super.key});

  @override
  State<PetOddsScreen> createState() => _PetOddsScreenState();
}

class _PetOddsScreenState extends State<PetOddsScreen> {
  bool _loading = true;
  String? _error;
  List<PetEggOddsModel> _pools = const [];

  /// 历险产出公示(2026-10-15 长途收益批):30 地 drop_table + 保底/系数配置
  List<Map<String, dynamic>> _advSpots = const [];
  Map<String, dynamic> _advReserved = const {};
  String? _advError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // 三路并行发起（各自独立容错:历险路失败不拖垮蛋池展示）
    final fPools = PetRpcP2.fetchPublishedEggOdds();
    final fSpots = PetRpc.fetchAdventureOdds();
    final fReserved = PetRpcP2.fetchReserved();
    final (pools, err) = await fPools;
    final (spots, spotsErr) = await fSpots;
    final (reserved, reservedErr) = await fReserved;
    if (!mounted) return;
    setState(() {
      // 繁育产出蛋（breed_*，内部池）不在公示页罗列——说明并入繁育页
      _pools = pools.where((p) => !p.poolCode.startsWith('breed_')).toList();
      _error = err == null ? null : petRpcErrorText(err);
      _advSpots = spots;
      _advReserved = reserved.raw;
      _advError = spotsErr == null && reservedErr == null
          ? null
          : petRpcErrorText(spotsErr ?? reservedErr);
      _loading = false;
    });
  }

  /// 长途独占掉落聚合:按道具归组(区名列表 + 概率,同道具各区同值);
  /// 保底值按道具取自 reserved.long_drop_pity；缺配置为 null（公示「未公示」,
  /// 不造默认值——本页铁律:猜测值不当作对外承诺）
  List<({String title, String maps, String pct, int? pity})> _adventureDrops() {
    final zoneNames = <String, String>{
      'forest': '森林', 'ranch': '牧场', 'beach': '海滩',
      'mountain': '山地', 'waste': '荒原', 'ruins': '遗迹',
    };
    const itemNames = kLongDropNames;
    final pityCfg =
        (_advReserved['long_drop_pity'] as Map?)?.cast<String, dynamic>() ?? const {};
    final byCode = <String, ({String maps, num? p, int? pity})>{};
    for (final row in _advSpots) {
      final code = row['code']?.toString() ?? '';
      final zone = code.startsWith('spot_') ? code.substring(5) : code;
      final zoneKey = zone.contains('_') ? zone.substring(0, zone.indexOf('_')) : zone;
      final dt = row['drop_table'];
      if (dt is! Map) continue;
      final lo = dt['long_only'];
      if (lo is! List) continue;
      for (final it in lo) {
        if (it is! Map) continue;
        final ic = it['code']?.toString() ?? '';
        if (ic.isEmpty) continue;
        final zn = zoneNames[zoneKey] ?? zoneKey;
        final p = it['p'] is num ? (it['p'] as num) : null;
        final pity =
            pityCfg[ic] is num ? (pityCfg[ic] as num).toInt() : null;
        final prev = byCode[ic];
        byCode[ic] = prev == null
            ? (maps: zn, p: p, pity: pity)
            : (maps: prev.maps.contains(zn) ? prev.maps : '${prev.maps}·$zn',
               p: prev.p ?? p,
               pity: prev.pity ?? pity);
      }
    }
    final out = <({String title, String maps, String pct, int? pity})>[];
    for (final e in byCode.entries) {
      out.add((
        title: itemNames[e.key] ?? e.key,
        maps: e.value.maps,
        // 保留一位小数:<0.5% 的概率用整数会显示成 0%(公示页语义失真)
        pct: e.value.p == null ? '-' : _fmtPct(e.value.p),
        pity: e.value.pity,
      ));
    }
    out.sort((a, b) => a.title.compareTo(b.title));
    return out;
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'short':
        return '短途 30分钟';
      case 'medium':
        return '中途 2小时';
      case 'long':
        return '长途 8小时';
    }
    return tier;
  }

  /// 历险公示卡(时长系数 + 长途独占掉落 + 保底)
  Widget _adventureCard(ColorScheme cs) {
    final tierMult =
        (_advReserved['adventure_tier_mult'] as Map?)?.cast<String, dynamic>() ?? const {};
    final expM = (tierMult['exp'] as Map?)?.cast<String, dynamic>() ?? const {};
    final goldM = (tierMult['gold'] as Map?)?.cast<String, dynamic>() ?? const {};
    String m(Map s, String tier) {
      final v = s[tier];
      if (v is num) return v == v.roundToDouble() ? v.round().toString() : v.toString();
      return v?.toString() ?? '-';
    }

    final drops = _adventureDrops();
    const tiers = ['short', 'medium', 'long'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('历险产出说明',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: cs.primary)),
            const SizedBox(height: 8),
            const Text('派遣时长收益(倍率):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Table(
              border: TableBorder(
                  horizontalInside:
                      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
              children: [
                TableRow(children: [
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: Text('', style: TextStyle(fontSize: 12))),
                  for (final t in tiers)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(_tierLabel(t),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
                TableRow(children: [
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: Text('经验', style: TextStyle(fontSize: 12))),
                  for (final t in tiers)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('×${m(expM, t)}',
                            style: const TextStyle(fontSize: 12))),
                ]),
                TableRow(children: [
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: Text('金币', style: TextStyle(fontSize: 12))),
                  for (final t in tiers)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('×${m(goldM, t)}',
                            style: const TextStyle(fontSize: 12))),
                ]),
              ],
            ),
            const SizedBox(height: 10),
            const Text('长途独占掉落(仅长途派遣概率获得):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (_advError != null)
              Text('产出数据加载失败:$_advError',
                  style: TextStyle(fontSize: 12, color: cs.error))
            else if (drops.isEmpty)
              const Text('暂未配置', style: TextStyle(fontSize: 12))
            else
              for (final d in drops)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '${d.title} · ${d.maps}(长途) 概率 ${d.pct} · ${d.pity == null ? '保底未公示' : '${d.pity} 次必得'}',
                      style: const TextStyle(fontSize: 12)),
                ),
            const SizedBox(height: 6),
            Text(
                '以上概率与后台配置同源,判定由服务端完成并留痕;各道具独立计数,'
                '概率命中或累计未中达保底次数必得(保底后清零)。',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('产出概率说明')),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _pools.isEmpty) {
      // 蛋池失败也不吞历险卡：历险路独立容错,错误条与重试钮并列其下
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _adventureCard(cs),
            const SizedBox(height: 16),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (_pools.isEmpty) {
      // 空蛋池不吞历险产出卡：历险卡在 _load 独立容错,蛋池无公示时仍可看
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _adventureCard(cs),
            const SizedBox(height: 12),
            const EmptyWidget(message: '还没有已公示的蛋池'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _adventureCard(cs),
          const SizedBox(height: 12),
          Center(
              child: Text('— 以下为宠物蛋产出说明 —',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
          const SizedBox(height: 8),
          for (final p in _pools) ...[
            _poolCard(cs, p),
            const SizedBox(height: 12),
          ],
          Text(
            '以上概率与后台配置同版本，抽取结果由服务端判定并留痕；'
            '每次抽取的随机结果相互独立，短期内不必然按比例出现。',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// 独立概率展示（p 为 0~1 小数）：整数不带小数位,否则保留一位
  String _fmtPct(num? p) {
    if (p == null) return '-';
    final v = p * 100;
    return v == v.roundToDouble() ? '${v.round()}%' : '${v.toStringAsFixed(1)}%';
  }

  /// 概率组占比换算（组内归一化；先取两位精度消浮点残差，保留 1 位小数展示）
  String _pct(num v, num total) {    if (total <= 0) return '0%';
    final p = (v / total * 100 * 100).round() / 100;
    final s = p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);
    return '$s%';
  }

  /// 蛋池名转译（ breed_* = 繁育产出蛋：家系+评级可从 code 解析）
  String _poolName(String code) {
    switch (code) {
      case 'egg_n':
        return '普通宠物蛋';
      case 'egg_r':
        return '稀有宠物蛋';
      case 'egg_sr':
        return '史诗宠物蛋';
      case 'egg_ssr':
        return '传说宠物蛋';
      case 'initial_ssr':
        return '初始宠物蛋';
    }
    final m = RegExp(r'^breed_([a-z]+)_(n|r|sr|ssr)$').firstMatch(code);
    if (m != null) {
      final fam = _familyNames[m.group(1)] ?? m.group(1)!;
      final rarity = _rarityShort[m.group(2)] ?? m.group(2)!;
      return '繁育蛋·$fam$rarity';
    }
    return code;
  }

  Widget _poolCard(ColorScheme cs, PetEggOddsModel pool) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_poolName(pool.poolCode),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text('配置版本 v${pool.configVersion}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 4),
            Text('孵化后将获得以下说明中的一种（由服务端判定）',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            _oddsGroup(cs, '评级', _rarityLines(pool.rarities)),
            _oddsGroup(cs, '系别', _familyLines(pool.families)),
            _oddsGroup(cs, '性别', pool.maleChance == null
                ? const <String>[]
                : ['公 ${_pct(pool.maleChance!, 1)} · 母 ${_pct(1 - pool.maleChance!, 1)}']),
          ],
        ),
      ),
    );
  }

  /// 评级说明行（固定 N→SSR 序，占比组内归一化）
  List<String> _rarityLines(Map<String, num> rarities) {
    if (rarities.isEmpty) return const <String>[];
    final total = rarities.values.fold<num>(0, (a, b) => a + b);
    return [
      for (final k in const ['N', 'R', 'SR', 'SSR'])
        if (rarities.containsKey(k))
          '${_rarityNames[k] ?? k} ${_pct(rarities[k]!, total)}',
    ];
  }

  /// 系别说明行（占比降序，组内归一化）
  List<String> _familyLines(Map<String, num> families) {
    if (families.isEmpty) return const <String>[];
    final total = families.values.fold<num>(0, (a, b) => a + b);
    final keys = families.keys.toList()
      ..sort((a, b) => (families[b]! - families[a]!).abs() < 1e-9
          ? a.compareTo(b)
          : families[b]!.compareTo(families[a]!));
    return [
      for (final k in keys)
        '${_familyNames[k] ?? k} ${_pct(families[k]!, total)}',
    ];
  }

/// 一组概率行；服务端没配该项就整组不渲染（不显示 0%、不写死文案）
Widget _oddsGroup(ColorScheme cs, String label, List<String> lines) {
  if (lines.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final line in lines)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(line,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ],
    ),
  );
}

/// 转译用常量：家系/评级中文名（与评级展示序 N→SSR 对齐）
static const Map<String, String> _familyNames = {
  'cat': '猫系',
  'dog': '犬系',
  'rabbit': '兔系',
  'mouse': '鼠系',
};
static const Map<String, String> _rarityNames = {
  'N': 'N 级·普通',
  'R': 'R 级·稀有',
  'SR': 'SR 级·史诗',
  'SSR': 'SSR 级·传说',
};
static const Map<String, String> _rarityShort = {
  'n': 'N',
  'r': 'R',
  'sr': 'SR',
  'ssr': 'SSR',
};
}
