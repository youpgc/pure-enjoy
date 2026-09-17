import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';
import 'pet_shop_screen.dart';

/// 宠物背包页（道具列表 + 使用/丢弃/整理 + 蛋孵化）
///
/// - 蛋条目：即开蛋直接孵化（成功弹结果卡）；等待型仅展示（P1 无等待型蛋池）；
/// - 消耗品：feed/clean/toy 对在养宠物使用；
/// - 丢弃走 rpc_pet_discard_items（append-only 流水可对账，丢弃不可恢复）；
/// - 整理走 rpc_pet_compact_bag（压缩空洞格位）。
class PetBagScreen extends StatefulWidget {
  const PetBagScreen({super.key, required this.petId});

  /// 在养宠物 id（使用道具的目标；null 时不可用道具）
  final String? petId;

  @override
  State<PetBagScreen> createState() => _PetBagScreenState();
}

class _PetBagScreenState extends State<PetBagScreen> {
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
    if (mounted) {
      setState(() {
        _items = items;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  Future<void> _hatchEgg(PetBagItemModel egg) async {
    await _busy(() async {
      final (eggs, err) = await PetRpc.fetchEggs();
      if (err != null) return _toast(petRpcErrorText(err));
      // 精确匹配该背包行对应的蛋（同道具多枚时按 bag_item_id 一一对应）
      PetEggModel? target;
      for (final e in eggs) {
        if (e.bagItemId == egg.id && e.isInstant) {
          target = e;
          break;
        }
      }
      if (target == null) {
        for (final e in eggs) {
          if (e.isInstant) {
            target = e;
            break;
          }
        }
      }
      if (target == null) return _toast('没有可即开孵化的蛋');
      final (result, hatchErr) = await PetRpc.hatchEgg(target.id);
      if (!mounted) return;
      if (hatchErr != null || result == null) {
        return _toast(petRpcErrorText(hatchErr));
      }
      _showHatchResult(result);
    }, egg.id);
  }

  void _showHatchResult(PetHatchResultModel r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 新伙伴诞生！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('名字：${r.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('编号：${r.showNo}'),
            Text('稀有度：${r.rarity}'),
            Text('性别：${r.gender?.code ?? '-'}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('太好了'),
          ),
        ],
      ),
    );
    _load();
  }

  Future<void> _useItem(PetBagItemModel item) async {
    if (widget.petId == null) return _toast('当前没有在养宠物');
    await _busy(() async {
      final err = await PetRpc.useItem(item.itemId, widget.petId!);
      if (!mounted) return;
      if (err != null) return _toast(petRpcErrorText(err));
      _toast('已使用「${item.name}」');
      _load();
    }, item.id);
  }

  Future<void> _discard(PetBagItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('丢弃确认'),
        content: Text('确定丢弃「${item.name}」×${item.quantity}？丢弃不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('丢弃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _busy(() async {
      final err = await PetRpc.discardItems([
        {'id': item.id, 'quantity': item.quantity},
      ]);
      if (!mounted) return;
      if (err != null) return _toast(petRpcErrorText(err));
      _toast('已丢弃');
      _load();
    }, item.id);
  }

  Future<void> _compact() async {
    final err = await PetRpc.compactBag();
    if (!mounted) return;
    if (err != null) return _toast(petRpcErrorText(err));
    _toast('背包已整理');
    _load();
  }

  Future<void> _busy(Future<void> Function() action, String id) async {
    setState(() => _busyId = id);
    await action();
    if (mounted) setState(() => _busyId = null);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('背包'),
        actions: [
          TextButton.icon(
            onPressed: _compact,
            icon: const Icon(Icons.cleaning_services_outlined, size: 18),
            label: const Text('整理', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyWidget(message: '背包空空如也'),
            FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetShopScreen(goldBalance: 0)),
              ),
              child: const Text('去商城逛逛'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.82,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final busy = _busyId == item.id;
          return InkWell(
            onTap: busy ? null : () => _onTap(item),
            borderRadius: BorderRadius.circular(12),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(_iconFor(item), size: 40, color: cs.primary),
                    const SizedBox(height: 6),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      item.isEgg
                          ? (item.effectType.isEmpty ? '蛋' : '蛋 · 点击孵化')
                          : '×${item.quantity}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onTap(PetBagItemModel item) async {
    if (item.isEgg) return _hatchEgg(item);
    // 消耗品：长按/弹层提供 使用/丢弃；这里弹操作面板
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(item.name),
              subtitle: Text('${item.category} · ×${item.quantity}'),
            ),
            if (widget.petId != null && _usable(item))
              ListTile(
                leading: const Icon(Icons.touch_app_outlined),
                title: const Text('使用'),
                onTap: () {
                  Navigator.pop(ctx);
                  _useItem(item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('丢弃'),
              onTap: () {
                Navigator.pop(ctx);
                _discard(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _usable(PetBagItemModel item) =>
      item.category == 'consumable' &&
      const {'feed', 'clean', 'toy'}.contains(item.effectType);

  IconData _iconFor(PetBagItemModel item) {
    if (item.isEgg) return Icons.egg_outlined;
    return switch (item.effectType) {
      'feed' => Icons.restaurant,
      'clean' => Icons.shower_outlined,
      'toy' => Icons.toys_outlined,
      'rescue' => Icons.health_and_safety_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }
}
