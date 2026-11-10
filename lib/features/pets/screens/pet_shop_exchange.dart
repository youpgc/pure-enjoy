part of 'pet_shop_screen.dart';

// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 中，分析器对本库内跨文件隐式调用的私有成员
// 引用计数有漏计（unused_element 误报）；extension 语境调 setState 触发
// protected 提示（运行时语义安全）。两处均为工具链误报，文件级压制。



extension _PetShopExchangeViews on _PetShopScreenState {
/// 收藏兑换与幸运抽奖域：组装兑换组 / 兑换卡 / 执行兑换 / 抽奖卡与抽取。

  /// 组装收藏兑换组：仅持有 >0 的收藏品出卡；名称取目录，缺名回退编码
  /// （背包由 _load 统一拉取后传入，避免同页重复请求）
  Future<List<_ExchangeGroup>> _loadExchangeGroups(
      Object? recipesRaw, List<PetBagItemModel> bag) async {
    if (recipesRaw is! List || recipesRaw.isEmpty) return const [];
    final names = await PetRpc.fetchItemNames();
    final owned = <String, int>{};
    for (final b in bag) {
      if (b.subType != 'collection') continue;
      owned[b.itemCode] = (owned[b.itemCode] ?? 0) + b.quantity;
    }
    final groups = <_ExchangeGroup>[];
    for (final r in recipesRaw.whereType<Map>()) {
      final from = r['from']?.toString() ?? '';
      if (from.isEmpty) continue;
      var g = groups.where((x) => x.fromCode == from).firstOrNull;
      if (g == null) {
        if ((owned[from] ?? 0) <= 0) continue; // 未持有不出卡
        g = _ExchangeGroup(
          fromCode: from,
          fromName: names[from] ?? from,
          owned: owned[from] ?? 0,
          recipes: [],
        );
        groups.add(g);
      }
      final to = r['to']?.toString() ?? '';
      if (to.isEmpty) continue;
      g.recipes.add(_ExchangeRecipe(
        toCode: to,
        toName: names[to] ?? to,
        fromCount: (r['from_count'] as num?)?.toInt() ?? 0,
      ));
    }
    return groups;
  }

  /// 阶梯道具「只展示当前可购档」:每套阶梯仅保留「已购最大步 + 1」
  /// 的那一档,已购档与未来档不展示;整套购完则整类隐藏(需求 §6.3 达上限不展示)。
  /// 服务端 shop_buy 的顺序校验仍兜底,此处只是把展示做对。

  /// 收藏兑换卡：持有收藏品 → 稀有道具（每件收藏品一卡，配方可兑的目标逐个列出）
  Widget _exchangeCard(ColorScheme cs, _ExchangeGroup g) {
    return Card(
      color: cs.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined,
                size: 30, color: cs.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('收藏兑换 · ${g.fromName} ×${g.owned}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSecondaryContainer)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in g.recipes)
                        OutlinedButton(
                          // 材料不足置灰；兑换中转圈禁点
                          onPressed: (_exchanging.contains(g.fromCode) ||
                                  g.owned < r.fromCount)
                              ? null
                              : () => _doExchange(g, r),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                              '${r.toName} · ${r.fromCount} 件换',
                              style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 执行兑换：满包走腾位提示口径，成功后刷新持有量
  Future<void> _doExchange(_ExchangeGroup g, _ExchangeRecipe r) async {
    setState(() => _exchanging.add(g.fromCode));
    final (data, err) = await PetRpc.collectionExchange(g.fromCode, r.toCode);
    if (!mounted) return;
    setState(() => _exchanging.remove(g.fromCode));
    if (err != null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    if (data == null) {
      showPetToast(context, kPetLocalError);
      return;
    }
    if (data['status'] == 'bag_full') {
      showPetToast(context, '背包已满，清理后再来兑换');
      return;
    }
    showPetToast(context, '已兑换「${r.toName}」×1');
    _load(showLoading: false);
  }

  /// 幸运抽奖卡：价格/限购说明 + 抽取按钮（结果 Toast 轻提示，不走诞生弹窗）
  Widget _lotteryCard(ColorScheme cs) {
    final price = (_lottery?['price'] as num?)?.toInt() ?? 0;
    return Card(
      color: cs.tertiaryContainer,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 30, color: cs.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('幸运蛋礼盒',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onTertiaryContainer)),
                  const SizedBox(height: 2),
                  // 商店营销文案（机制与概率数字只在公示页，问号入口可达）
                  Text('有机会抽中传说级宠物！',
                      style: TextStyle(
                          fontSize: 12, color: cs.onTertiaryContainer)),
                ],
              ),
            ),
            FilledButton.tonal(
              // 余额预检与 _buy 同口径（不足置灰；服务端仍兜底校验）
              onPressed: (_drawing || _gold < price) ? null : _drawLottery,
              child: _drawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.paid_outlined, size: 14),
                      const SizedBox(width: 3),
                      Text(petGoldLabel(price)),
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _drawLottery() async {
    setState(() => _drawing = true);
    final (data, err) = await PetRpc.lotteryDraw();
    if (!mounted) return;
    setState(() => _drawing = false);
    if (err != null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    // 本地扣减余额（与 _buy 同口径）+ 刷新商城（限购/阶梯可能变化）
    setState(() => _gold -= (_lottery?['price'] as num?)?.toInt() ?? 0);
    await _load(showLoading: false);
    if (!mounted || data == null) return;
    final r = PetHatchResultModel.fromJson(data);
    final nm = r.name.isNotEmpty ? r.name : r.speciesCode;
    showPetToast(context, '幸运降生！获得「$nm」');
  }

  /// 完整金币数额（转换值点击查看）

/// 收藏兑换组（一件收藏品 = 一张卡，recipes 为它可兑的目标清单）
}

class _ExchangeGroup {
  _ExchangeGroup({
    required this.fromCode,
    required this.fromName,
    required this.owned,
    required this.recipes,
  });

  final String fromCode;
  final String fromName;
  final int owned;
  final List<_ExchangeRecipe> recipes;
}

class _ExchangeRecipe {
  const _ExchangeRecipe({
    required this.toCode,
    required this.toName,
    required this.fromCount,
  });

  final String toCode;
  final String toName;
  final int fromCount;
}
