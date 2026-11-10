part of 'pet_bag_screen.dart';

// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 下分析器对跨文件隐式调用的私有成员引用计数有漏计（误报）。

extension _PetBagDiscardViews on _PetBagScreenState {
  Future<int?> _showDiscardConfirm(PetBagItemModel item) {
    final cs = Theme.of(context).colorScheme;
    var qty = item.quantity; // 默认全部
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setQty) => AlertDialog(
          title: const Text('丢弃确认'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定丢弃「${item.name}」？丢弃不可恢复。',
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('丢弃数量',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        qty > 1 ? () => setQty(() => qty -= 1) : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  SizedBox(
                    width: 76,
                    child: Text('$qty / ${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    // 已是持有最大数量：禁用增加
                    onPressed: qty < item.quantity
                        ? () => setQty(() => qty += 1)
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    ),
                    onPressed: () => Navigator.pop(ctx, qty),
                    child: const Text('确认丢弃'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
