import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';

/// 宠物商城页（在售道具 + 购买）
///
/// 数据源 pet_items（on_shelf 且 channels 含 shop）；扩容阶梯道具
/// 购买即生效（服务端转 rpc_pet_buy_expansion，限购/顺序/上限由 RPC 校验）。
class PetShopScreen extends StatefulWidget {
  const PetShopScreen({super.key, required this.goldBalance});

  final int goldBalance;

  @override
  State<PetShopScreen> createState() => _PetShopScreenState();
}

class _PetShopScreenState extends State<PetShopScreen> {
  bool _loading = true;
  String? _error;
  List<PetShopItemModel> _items = const [];
  final Set<String> _buying = {};
  late int _gold = widget.goldBalance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (items, err) = await PetRpc.fetchShopItems();
    if (mounted) {
      setState(() {
        _items = items;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  Future<void> _buy(PetShopItemModel item) async {
    if (_buying.contains(item.id)) return;
    if (_gold < item.priceCoin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金币不足，可通过任务/历险获取')),
      );
      return;
    }
    setState(() => _buying.add(item.id));
    final (status, err) = await PetRpc.shopBuy(item.id);
    if (!mounted) return;
    setState(() => _buying.remove(item.id));
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      return;
    }
    if (status == 'bag_full') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('背包已满，请先清理背包再购买')),
      );
      return;
    }
    setState(() => _gold -= item.priceCoin);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(item.isExpansion ? '扩容已生效' : '已购买「${item.name}」')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('宠物商城'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.paid_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text('$_gold', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const EmptyWidget(message: '商城暂无在售道具');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = _items[i];
          final affordable = _gold >= item.priceCoin;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_iconFor(item)),
              ),
              title: Text(item.name),
              subtitle: Text(
                item.description?.isNotEmpty == true
                    ? item.description!
                    : (item.isExpansion ? '购买后立即生效' : '购买后放入背包'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: FilledButton.tonal(
                onPressed: affordable ? () => _buy(item) : null,
                child: Text(
                  _buying.contains(item.id)
                      ? '购买中'
                      : '${item.priceCoin} 金币',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(PetShopItemModel item) {
    if (item.isExpansion) return Icons.unfold_more;
    return switch (item.category) {
      'consumable' => Icons.restaurant,
      'tool' => Icons.build_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }
}
