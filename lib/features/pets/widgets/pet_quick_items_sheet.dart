import 'package:flutter/material.dart';

import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_bag_meta.dart';
import '../utils/pet_errors.dart';
import 'pet_item_icon.dart';
import 'pet_loading.dart';
import 'pet_toast.dart';

/// 主页右列「道具」快捷弹层：抚摸下方新入口。
///
/// 只列背包中**可直接使用的消耗品**（`petBagItemUsable` 同一口径：
/// consumable 且 effectType 在可用集内），点击即使用（`rpc_pet_use_item`，
/// 与背包页同一条链路）；蛋/洗练剂/加速卡等有专属去向的道具不在此列
/// （引导走背包页，见 bag_screen._extraAction 的分流）。
/// 列表逐项展示效果描述（petBagEffectDesc 同源）；使用成功即关闭弹窗，
/// 关闭后经 [onChanged] 通知主页刷新总览（金币/状态可能变化）。
Future<void> showPetQuickItemsSheet(
  BuildContext context, {
  required String? petId,
  required VoidCallback onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _QuickItemsSheet(petId: petId, onChanged: onChanged),
  );
}

class _QuickItemsSheet extends StatefulWidget {
  const _QuickItemsSheet({required this.petId, required this.onChanged});

  final String? petId;
  final VoidCallback onChanged;

  @override
  State<_QuickItemsSheet> createState() => _QuickItemsSheetState();
}

class _QuickItemsSheetState extends State<_QuickItemsSheet> {
  bool _loading = true;
  String? _error;
  List<PetBagItemModel> _items = const [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (items, err) = await PetRpc.fetchBag();
    if (!mounted) return;
    setState(() {
      // 仅可用消耗品（快捷使用的口径）；不可用道具引导去背包页
      _items = items.where(petBagItemUsable).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _error = err == null ? null : petRpcErrorText(err);
      _loading = false;
    });
  }

  Future<void> _use(PetBagItemModel item) async {
    if (widget.petId == null || _busyId != null) return;
    setState(() => _busyId = item.id);
    final err = await PetRpc.useItem(item.itemId, widget.petId!);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) {
      showPetToast(context, petRpcErrorText(err));
      // 库存类失败（不足/竞态）后以服务端为准重拉
      return _load();
    }
    showPetToast(context, '已使用「${item.name}」');
    // 使用成功即关闭弹窗（20261103 用户拍板）；主页刷新经 onChanged 通知
    Navigator.pop(context);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('使用道具',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Text('背包里的可用消耗品',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: PetPawLoading()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 34, color: cs.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('背包里暂时没有可用的消耗品',
                        style:
                            TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final busy = _busyId == item.id;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          PetItemIcon(
                            iconKey: item.iconKey,
                            fallback: petBagFallbackIcon(item),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600)),
                                // 效果描述（pet_items.effect 结构化同源，
                                // 与背包页同一实现，不臆测数值）
                                Text(
                                  petBagEffectDesc(item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      height: 1.25,
                                      color: cs.onSurfaceVariant),
                                ),
                                Text('持有 ${item.quantity}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: busy ? null : () => _use(item),
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            child: busy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('使用',
                                    style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
