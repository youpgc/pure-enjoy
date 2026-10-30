import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../../../constants/pet.dart';
import '../models/pet_p2_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_dict.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_item_icon.dart';
import '../widgets/pet_loading.dart';

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

  /// item_code → 中文名（pet_items 服务端真源；失败时空表走字典兜底）
  Map<String, String> _itemNames = const {};

  /// 历险产出公示(2026-10-15 长途收益批):30 地 drop_table + 保底/系数配置
  List<Map<String, dynamic>> _advSpots = const [];
  Map<String, dynamic> _advReserved = const {};
  String? _advError;
  /// 游历档位配置（pet_config.adventure_tiers 下发，档位文案同源 20261030）
  List<Map<String, dynamic>> _tierCfg = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // 多路并行发起（各自独立容错:历险路失败不拖垮蛋池展示）
    final fPools = PetRpcP2.fetchPublishedEggOdds();
    final fSpots = PetRpc.fetchAdventureOdds();
    final fReserved = PetRpcP2.fetchReserved();
    final fNames = PetRpc.fetchItemNames();
    final fTiers = PetRpc.fetchAdventureTiers();
    final (pools, err) = await fPools;
    final (spots, spotsErr) = await fSpots;
    final (reserved, reservedErr) = await fReserved;
    final names = await fNames;
    final tiers = await fTiers;
    if (!mounted) return;
    setState(() {
      // 繁育产出蛋（breed_*，内部池）不在公示页罗列——说明并入繁育页
      _pools = pools.where((p) => !p.poolCode.startsWith('breed_')).toList();
      _error = err == null ? null : petRpcErrorText(err);
      _advSpots = spots;
      _advReserved = reserved.raw;
      _itemNames = names;
      _tierCfg = tiers;
      _advError = spotsErr == null && reservedErr == null
          ? null
          : petRpcErrorText(spotsErr ?? reservedErr);
      _loading = false;
    });
  }

  /// 长途独占掉落聚合:按道具归组(**具体地图名**列表 + 概率,同道具各区同值);
  /// 保底值按道具取自 reserved.long_drop_pity；缺配置为 null（公示「未公示」,
  /// 不造默认值——本页铁律:猜测值不当作对外承诺）
  List<({String code, String title, Map<String, List<String>> zoneMaps, String pct, int? pity})>
      _adventureDrops() {
    // 取名统一口径：服务端 pet_items 映射为主，kLongDropNames 仅旧版兜底
    const itemNames = kLongDropNames;
    final srvNames = _itemNames;
    final pityCfg =
        (_advReserved['long_drop_pity'] as Map?)?.cast<String, dynamic>() ?? const {};
    final byCode = <String,
        ({Map<String, List<String>> zoneMaps, num? p, int? pity})>{};
    for (final row in _advSpots) {
      final code = row['code']?.toString() ?? '';
      final zone = code.startsWith('spot_') ? code.substring(5) : code;
      final zoneKey = zone.contains('_') ? zone.substring(0, zone.indexOf('_')) : zone;
      final spotName = row['name']?.toString() ?? code;
      final dt = row['drop_table'];
      if (dt is! Map) continue;
      final lo = dt['long_only'];
      if (lo is! List) continue;
      for (final it in lo) {
        if (it is! Map) continue;
        final ic = it['code']?.toString() ?? '';
        if (ic.isEmpty) continue;
        final p = it['p'] is num ? (it['p'] as num) : null;
        final pity =
            pityCfg[ic] is num ? (pityCfg[ic] as num).toInt() : null;
        final prev = byCode[ic];
        if (prev == null) {
          byCode[ic] = (zoneMaps: {zoneKey: [spotName]}, p: p, pity: pity);
        } else {
          final maps = Map<String, List<String>>.of(prev.zoneMaps);
          final list = List<String>.of(maps[zoneKey] ?? const <String>[]);
          if (!list.contains(spotName)) list.add(spotName);
          maps[zoneKey] = list;
          byCode[ic] = (zoneMaps: maps, p: prev.p ?? p, pity: prev.pity ?? pity);
        }
      }
    }
    final out = <({String code, String title,
        Map<String, List<String>> zoneMaps, String pct, int? pity})>[];
    for (final e in byCode.entries) {
      out.add((
        code: e.key,
        title: srvNames[e.key] ?? itemNames[e.key] ?? e.key,
        zoneMaps: e.value.zoneMaps,
        // 保留一位小数:<0.5% 的概率用整数会显示成 0%(公示页语义失真)
        pct: e.value.p == null ? '-' : _fmtPct(e.value.p),
        pity: e.value.pity,
      ));
    }
    out.sort((a, b) => a.title.compareTo(b.title));
    return out;
  }

  String _tierLabel(String tier) {
    // 档位名与时长以 pet_config.adventure_tiers 下发为准（与历险页同源，
    // 20261030 收敛双真源）；配置缺失回落端内文案（不含时长）
    for (final t in _tierCfg) {
      if (t['tier'] == tier) {
        final label = t['label']?.toString() ?? '';
        final minutes = (t['minutes'] as num?)?.toInt();
        if (label.isNotEmpty) {
          return minutes == null ? label : '$label ${_minutesText(minutes)}';
        }
      }
    }
    final base = kPetTierNames[tier];
    return base ?? tier;
  }

  static String _minutesText(int minutes) =>
      minutes >= 60 ? '${minutes ~/ 60}小时${minutes % 60 > 0 ? '${minutes % 60}分钟' : ''}' : '$minutes分钟';

  /// 历险公示卡(时长系数 + 长途独占掉落:道具图标+概率/保底徽章+地图分支路径)
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头部横幅:渐变底+罗盘图标,替代纯文字标题
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withValues(alpha: 0.14), cs.tertiary.withValues(alpha: 0.10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      cs.primary,
                      cs.tertiary,
                    ]),
                  ),
                  child: const Icon(Icons.explore, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('游历产出说明',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('派遣时长收益(倍率):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Table(
                  border: TableBorder(
                      horizontalInside: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5))),
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
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Icon(Icons.auto_awesome, size: 13, color: cs.tertiary),
                            const SizedBox(width: 4),
                            const Text('经验', style: TextStyle(fontSize: 12)),
                          ])),
                      for (final t in tiers)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text('×${m(expM, t)}',
                                style: const TextStyle(fontSize: 12))),
                    ]),
                    TableRow(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Icon(Icons.paid_outlined, size: 13, color: cs.primary),
                            const SizedBox(width: 4),
                            const Text('金币', style: TextStyle(fontSize: 12)),
                          ])),
                      for (final t in tiers)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text('×${m(goldM, t)}',
                                style: const TextStyle(fontSize: 12))),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('长途限定宝藏（只有长途出行才有机会获得）：',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_advError != null)
                  Text('产出数据加载失败，稍后再来看看',
                      style: TextStyle(fontSize: 12, color: cs.error))
                else if (drops.isEmpty)
                  const Text('敬请期待', style: TextStyle(fontSize: 12))
                else
                  for (final d in drops) ...[
                    _dropTile(cs, d),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 2),
                Text(
                    '每件宝贝单独计数：抽中或攒够保底次数必定获得，获得后重新计数。',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 掉落道具卡:头部(道具图标+名称+概率/保底徽章)+地图分支路径
  Widget _dropTile(
    ColorScheme cs,
    ({String code, String title, Map<String, List<String>> zoneMaps, String pct, int? pity}) d,
  ) {
    final zones = d.zoneMaps.keys.toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: PetItemIcon(
                  iconKey: d.code,
                  fallback: _dropFallbackIcon(d.code),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        '长途游历掉落 · ${zones.length} 地形 ${d.zoneMaps.values.fold<int>(0, (a, l) => a + l.length)} 图',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('概率 ${d.pct}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(d.pity == null ? '保底待定' : '${d.pity} 次必得',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onTertiaryContainer)),
              ),
            ],
          ),
          if (zones.isNotEmpty) ...[
            const SizedBox(height: 10),
            // 游戏地图分支路径:左轨竖线串联地形站点,站点右侧列具体地图
            for (var i = 0; i < zones.length; i++)
              _zoneBranchLine(cs, zones[i], d.zoneMaps[zones[i]]!,
                  first: i == 0, last: i == zones.length - 1),
          ],
        ],
      ),
    );
  }

  /// 地图分支行:左侧路径轨(上段线-地形站点圆-下段线)+地形名+具体地图 chips
  Widget _zoneBranchLine(ColorScheme cs, String zoneKey, List<String> names,
      {required bool first, required bool last}) {
    final meta = _zoneMeta[zoneKey];
    final label = meta?.$1 ?? zoneKey;
    final icon = meta?.$2 ?? Icons.place_outlined;
    final color = meta?.$3 ?? cs.primary;
    final bg = meta?.$4 ?? cs.surfaceContainerHighest;
    final rail = color.withValues(alpha: 0.35);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                if (!first)
                  Expanded(child: Center(child: Container(width: 2, color: rail)))
                else
                  const SizedBox(height: 6),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 5,
                          offset: const Offset(0, 1.5)),
                    ],
                  ),
                  child: Icon(icon, size: 13, color: Colors.white),
                ),
                if (!last)
                  Expanded(child: Center(child: Container(width: 2, color: rail)))
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  top: first ? 4 : 8, bottom: last ? 4 : 8, right: 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ),
                  for (final n in names)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(n,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurface)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 长途掉落道具图标回退(按 code 语义选 Material 图标)
  static IconData _dropFallbackIcon(String code) {
    if (code.contains('compass')) return Icons.explore_outlined;
    if (code.startsWith('evo_stone')) return Icons.diamond_outlined;
    return Icons.inventory_2_outlined;
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
    if (_loading) return const Center(child: PetPawLoading());
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
            const EmptyWidget(message: '蛋池还在准备中，敬请期待'),
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
          const SizedBox(height: 14),
          // 分隔行:左右细线夹说明,替代孤零零的一行字
          Row(
            children: [
              Expanded(
                  child: Container(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.6))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('以下为宠物蛋产出说明',
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
              Expanded(
                  child: Container(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in _pools) ...[
            _poolCard(cs, p),
            const SizedBox(height: 12),
          ],
          Text(
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
      case 'lottery_s1':
        return '幸运蛋礼盒';
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
      final fam = PetDict.family(m.group(1)!);
      final rarity = _rarityShort[m.group(2)] ?? m.group(2)!;
      return '繁育蛋·$fam$rarity';
    }
    return code;
  }

  /// 蛋池图标键(egg_* 直用;initial_ssr 映射 egg_initial_ssr;breed_* 无专属图)
  static String? _eggIconKey(String code) {
    if (code.startsWith('breed_')) return null;
    if (code == 'initial_ssr') return 'egg_initial_ssr';
    return code.startsWith('egg_') ? code : null;
  }

  /// 初始蛋公示文案:不强调种属(20261022 拍板),统一自选/固定口径
  String _initialOddsText(Map<String, List<String>> choices) {
    return choices.isEmpty ? '孵化固定获得一只初始 SSR' : '孵化时自选获得一只初始 SSR';
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PetItemIcon(
                    iconKey: _eggIconKey(pool.poolCode),
                    fallback: Icons.egg_outlined,
                    size: 24,
                    color: cs.tertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_poolName(pool.poolCode),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (pool.poolCode == 'initial_ssr')
              // 初始蛋自选种属(20261022 拍板):可选系来自池配置,系内候选由随机取一
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_initialOddsText(pool.initialChoices),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onTertiaryContainer)),
              )
            else
              Text('孵化后将获得以下说明中的一种',
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
        '${PetDict.family(k)} ${_pct(families[k]!, total)}',
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
/// 地形展示元数据:(中文名, 站点图标, 主题色, 地图 chip 淡底色)——
/// 地图分支路径的视觉基元;未登记地形走 _zoneBranchLine 内兜底
static const Map<String, (String, IconData, Color, Color)> _zoneMeta = {
  'forest': ('森林', Icons.forest, Color(0xFF43A047), Color(0xFFE8F5E9)),
  'ranch': ('牧场', Icons.grass, Color(0xFF7CB342), Color(0xFFF1F8E9)),
  'beach': ('海滩', Icons.beach_access, Color(0xFF00ACC1), Color(0xFFE0F7FA)),
  'mountain': ('山地', Icons.terrain, Color(0xFF8D6E63), Color(0xFFEFEBE9)),
  'waste': ('荒原', Icons.landscape, Color(0xFFFB8C00), Color(0xFFFFF3E0)),
  'ruins': ('遗迹', Icons.account_balance, Color(0xFF7E57C2), Color(0xFFEDE7F6)),
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
