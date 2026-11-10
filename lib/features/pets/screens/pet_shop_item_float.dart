part of 'pet_shop_screen.dart';

// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 中，分析器对本库内跨文件隐式调用的私有成员
// 引用计数有漏计（unused_element 误报）；extension 语境调 setState 触发
// protected 提示（运行时语义安全）。两处均为工具链误报，文件级压制。



extension _PetShopFloatViews on _PetShopScreenState {
/// 购买弹窗域：满格腾位对话框 / 物品悬浮窗（信息 + 数量 + 购买）。

  /// 满格腾位对话框（需求 §5.4）：展示容量占用与本次所需格数；
  /// 服务端给出下一级扩容道具时提供「扩容并重试」，购买成功后同流程内
  /// 自动重试原购买；已达上限则只有「去清理背包」一条路径。
  Future<void> _showBagFullDialog(
    PetShopItemModel item,
    PetShopBuyResultModel result, {
    bool fromDialog = false,
    int qty = 1,
  }) async {
    final expand = result.nextExpand;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('背包已满'),
        content: Text(
          result.used != null && result.capacity != null
              ? '背包 ${result.used}/${result.capacity} 格已用完'
                  '${result.rowsNeeded == null ? '' : '，本次需要 ${result.rowsNeeded} 格'}。'
              : '背包空间不足。'
          '${expand == null ? '\n背包已经扩到最大啦，清理一下再试试。' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('clean'),
            child: const Text('去清理背包'),
          ),
          if (expand != null)
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop('expand'),
              child: Text('扩容+1格 · ${expand.priceCoin}金币'),
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'clean') {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PetBagScreen(petId: widget.petId)),
      );
      if (mounted) _load();
      return;
    }
    if (action == 'expand' && expand != null) {
      setState(() => _buying.add(expand.itemId));
      final (expandResult, expandErr) =
          await PetRpcShop.shopBuy(expand.itemId);
      if (!mounted) return;
      setState(() => _buying.remove(expand.itemId));
      if (expandErr != null) {
        showPetToast(context, petRpcErrorText(expandErr));
        return;
      }
      if (expandResult == null || expandResult.isBagFull) {
        showPetToast(context, '扩容购买未完成，请清理背包后再试');
        return;
      }
      setState(() => _gold -= expand.priceCoin);
      // 同流程内闭环：扩容成功即重试原购买（§5.4）；结果 toast 由
      // 重试的 _buy 以 afterExpand 合并文案输出（替换式 toast 会覆盖
      // 此处的'扩容已生效'，单独吐等于没说）
      await _buy(item, fromDialog: fromDialog, afterExpand: true, qty: qty);
    }
  }

  // ---------- 物品悬浮窗（信息 + 数量 + 购买） ----------

  void _showItemFloat(PetShopItemModel item) {
    final cs = Theme.of(context).colorScheme;
    final busy = _buying.contains(item.id);
    var qty = 1;
    final canBatch = !item.isExpansion; // 扩容阶梯道具限购 1 次，不参与批量
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setQty) {
        final total = item.priceCoin * qty;
        final affordableNow = _gold >= total;
        final busyNow = busy || _buying.contains(item.id);
        return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PetItemIcon(
                      iconKey: item.iconKey,
                      fallback: _iconFor(item),
                      size: 28,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.categoryLabel} · ${item.priceCoin} 金币',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.description?.isNotEmpty == true
                    ? item.description!
                    : (item.isExpansion ? '购买后立即生效' : '购买后放入背包'),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              if (canBatch) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('购买数量',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    // 减
                    IconButton.outlined(
                      visualDensity: VisualDensity.compact,
                      onPressed: qty > 1
                          ? () => setQty(() => qty = qty - 1)
                          : null,
                      icon: const Icon(Icons.remove, size: 18),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    // 加（上限=服务端 PET_QTY_LIMIT 对齐值；金币上限另由按钮禁用态兜底）
                    IconButton.outlined(
                      visualDensity: VisualDensity.compact,
                      onPressed: qty < kShopBuyQtyLimit
                          ? () => setQty(() => qty = qty + 1)
                          : null,
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: affordableNow && !busyNow
                      ? () {
                          Navigator.of(ctx).pop();
                          _buy(item, fromDialog: true, qty: qty);
                        }
                      : null,
                  icon: const Icon(Icons.paid_outlined, size: 18),
                  label: Text(
                    busyNow
                        ? '购买中'
                        : (!affordableNow
                            ? '金币不足'
                            : (qty > 1
                                ? '购买 ×$qty（${item.priceCoin * qty} 金币）'
                                : '购买')),
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
      ),
      );
  }

  IconData _iconFor(PetShopItemModel item) {
    if (item.isExpansion) return Icons.unfold_more;
    return switch (item.subType) {
      'food' => Icons.restaurant,
      'clean' => Icons.shower_outlined,
      'toy' => Icons.toys_outlined,
      'rescue' => Icons.health_and_safety_outlined,
      'checkin_makeup' => Icons.event_available_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }
}
