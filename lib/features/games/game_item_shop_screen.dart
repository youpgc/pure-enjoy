import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'shared/game_local_loading.dart';
import 'models/game_item_model.dart';
import 'models/game_model.dart';
import 'models/match3_mode.dart';
import 'services/game_item_service.dart';
import 'shared/game_shell.dart';
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
  /// 正在购买中的道具 id（null = 无进行中的购买请求）
  String? _buyingId;

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
    // 同步购买限制：已有任一购买请求进行中时，点其他按钮仅提示不排队
    if (_buyingId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在购买中...')),
      );
      return;
    }
    setState(() => _buyingId = item.id);
    final res = await GameItemService.instance.purchase(item);
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _buyingId = null);
      if (res['success'] == true) {
        await _load();
        messenger.showSnackBar(
          SnackBar(content: Text(res['message'] ?? '购买成功')),
        );
      } else {
        messenger.showSnackBar(
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
      body: RefreshIndicator(
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
                  // 道具区局部 loading（规范：禁止整页 loading）
                  if (_loading)
                    const GameLocalLoading(label: '道具加载中…')
                  else if (_items.isEmpty)
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
                          buyingId: _buyingId,
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

  /// 正在购买中的道具 id：等于本道具 → 按钮转圈；其他道具按钮**不禁用**，
  /// 点击时由调用方提示「正在购买中...」（2026-09-10 用户拍板）。
  final String? buyingId;
  final VoidCallback onBuy;

  const _ItemCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.buyingId,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel =
        item.mode.isEmpty ? '通用' : match3ModeLabelOf(item.mode);
    final isBuying = buyingId == item.id;
    // 仅「买不起/0积分」禁用；其他道具购买中不禁用本按钮（点击提示排队中）
    final disabled = !canAfford || item.pointCost <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              // 道具定版图标（game_items.icon 口子），空回退内置图标
              PropIcon(
                icon: itemIconFor(item.itemType),
                iconAsset: item.icon,
                size: 44,
              ),
              const SizedBox(width: 12),
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
                    child: isBuying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('购买'),
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
