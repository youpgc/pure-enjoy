part of 'pet_odds_screen.dart';

/// 历险公示域：时长系数 / 独占掉落 / 地图分支路径。

extension _PetOddsAdventureViews on _PetOddsScreenState {
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
    final meta = _PetOddsScreenState._zoneMeta[zoneKey];
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
}
