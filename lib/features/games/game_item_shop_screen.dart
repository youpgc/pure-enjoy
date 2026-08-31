import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'models/game_item_model.dart';
import 'models/game_model.dart';
import 'models/match3_mode.dart';
import 'services/game_item_service.dart';
import '../../features/profile/services/point_service.dart';

/// 游戏道具商城页。
///
/// 列出当前游戏的全部已启用道具（含按模式道具），展示名称/说明/积分成本/持有数，
/// 购买时扣积分（写 game_spend 流水）并入库；积分不足或积分项成本为 0 时按钮禁用/隐藏。
class GameItemShopScreen extends StatefulWidget {
  final GameModel game;

  const GameItemShopScreen({super.key, required this.game});

  @override
  State<GameItemShopScreen> createState() => _GameItemShopScreenState();
}

class _GameItemShopScreenState extends State<GameItemShopScreen> {
  List<GameItemModel> _items = <GameItemModel>[];
  Map<String, int> _inventory = const <String, int>{};
  int _availablePoints = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await GameItemService.instance.fetchItems(gameCode: widget.game.code);
    final inv = await GameItemService.instance.fetchInventory();
    final pts = await PointService.instance.getAvailablePoints();
    if (mounted) {
      setState(() {
        _items = items;
        _inventory = inv;
        _availablePoints = pts;
        _loading = false;
      });
    }
  }

  Future<void> _buy(GameItemModel item) async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await GameItemService.instance.purchase(item);
    if (mounted) {
      setState(() => _busy = false);
      if (res['success'] == true) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? '购买成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? '购买失败'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 道具商城')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.wallet_giftcard,
                              color: AppTheme.primaryOrange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('我的积分',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.neutral600)),
                                Text('$_availablePoints',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('暂无可用道具',
                            style: TextStyle(color: AppTheme.neutral600)),
                      ),
                    )
                  else
                    ..._items.map((it) => _ItemCard(
                          item: it,
                          owned: _inventory[it.id] ?? 0,
                          canAfford: _availablePoints >= it.pointCost,
                          busy: _busy,
                          onBuy: () => _buy(it),
                        )),
                ],
              ),
            ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final GameItemModel item;
  final int owned;
  final bool canAfford;
  final bool busy;
  final VoidCallback onBuy;

  const _ItemCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.busy,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel =
        item.mode.isEmpty ? '通用' : match3ModeLabelOf(item.mode);
    final disabled = busy || !canAfford || item.pointCost <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(item.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.neutral200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(modeLabel,
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(item.description!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.neutral600)),
                    ],
                    const SizedBox(height: 6),
                    Text('持有 $owned · 单局限用 ${item.perGameLimit} 次',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.neutral500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: <Widget>[
                  Text('${item.pointCost} 积分',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: disabled ? null : onBuy,
                    child: const Text('购买'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
