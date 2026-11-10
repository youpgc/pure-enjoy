import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_adventure.dart';
import '../services/pet_rpc_shop.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_errors.dart';
import '../utils/pet_gold_format.dart';
import '../widgets/pet_category_rail.dart';
import '../widgets/pet_item_icon.dart';
import 'pet_bag_screen.dart';
import 'pet_odds_screen.dart';
import '../widgets/pet_toast.dart';
import '../widgets/pet_loading.dart';
part 'pet_shop_exchange.dart';
part 'pet_shop_item_float.dart';

/// 批量购买单次数量上限（与服务端 rpc_pet_shop_buy 的 PET_QTY_LIMIT 对齐
///  调整须两端同步）。
const int kShopBuyQtyLimit = 99;

/// 解锁类道具 → 功能键（pet_items.effect.unlock.feature 同源结构映射；
///  unlock 类限购 1 次 + 购买后不再展示——已购在包或功能
/// 已开通即隐藏，使用后道具从背包移除、功能解锁不反弹）。
const Map<String, String> kUnlockItemFeatures = {
  'unlock_feed_basin': 'batch_feed',
  'unlock_breeding_nest': 'breeding',
};

/// 宠物商城页（左侧分类栏 + 物品格 + 悬浮窗购买）
///
/// 布局：分类栏在**左侧竖排**（栅格 tile，超出出滚动条）
/// 右侧物品格网格每行 4 格、只显图标+名称（§5.3 物品格展示）；
/// 点击物品弹悬浮窗展示信息、批量数量与购买按钮。
/// 分类清单取自 `PetShopItemModel.categoryLabels`（消耗品等 8 类；食物/医疗/
///  清洁/玩具/救援已合并为「消耗品」）。
/// 数据源 pet_items（on_shelf 且 channels 含 shop）；扩容阶梯道具
/// 购买即生效（服务端转 rpc_pet_buy_expansion，限购/顺序/上限由 RPC 校验）。
class PetShopScreen extends StatefulWidget {
  const PetShopScreen({
    super.key,
    required this.goldBalance,
    this.petId,
  });

  final int goldBalance;

  /// 在养宠物 id（背包页「使用道具」的目标；由主页带过来，null 时背包内不可用道具）
  final String? petId;

  @override
  State<PetShopScreen> createState() => _PetShopScreenState();
}

class _PetShopScreenState extends State<PetShopScreen> {
  bool _loading = true;
  String? _error;
  List<PetShopItemModel> _items = const [];

  /// 幸运抽奖配置（reserved.lottery：price/限购；null=后台未配不展示）
  Map<String, dynamic>? _lottery;
  bool _drawing = false;
  final Set<String> _buying = {};
  late int _gold = widget.goldBalance;

  /// 收藏兑换组（按收藏品分组；仅持有>0 的收藏品出卡）
  List<_ExchangeGroup> _exchangeGroups = const [];
  final Set<String> _exchanging = {};

  /// 当前分类（all / [PetShopItemModel.categoryLabels] 之一）
  String _category = 'all';

  /// 分类栏项：清单来自模型（与 categoryLabel 同源，防漂移），图标在本页映射
  static List<PetCategoryItem> get _railItems => [
        const PetCategoryItem('all', '全部', icon: Icons.grid_view_outlined),
        for (final label in PetShopItemModel.categoryLabels)
          PetCategoryItem(label, label, icon: _labelIcon(label)),
      ];

  static const Map<String, IconData> _labelIcons = <String, IconData>{
    '宠物蛋': Icons.egg_outlined,
    '消耗品': Icons.inventory_2_outlined,
    '扩容': Icons.unfold_more,
    '进化': Icons.auto_awesome_outlined,
    '加速': Icons.speed_outlined,
    '洗练': Icons.replay_outlined,
    '解锁': Icons.lock_open_outlined,
  };

  static IconData _labelIcon(String label) =>
      _labelIcons[label] ?? Icons.category_outlined;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    final (items, err) = await PetRpcShop.fetchShopItems();
    final (records, recErr) = await PetRpcShop.fetchExpansionRecords();
    final (reserved, _) = await PetRpcP2.fetchReserved();
    final lot = reserved.raw['lottery'];
    // 解锁类「购买后不再展示」信号：背包在持 + 已开通功能集
    final (bag, bagErr) = await PetRpc.fetchBag();
    final unlocked = await PetRpcAdventure.fetchUnlockedFeatures();
    // 收藏兑换：配方(reserved) + 持有量(背包) + 道具名(目录)——失败静默不展示
    final exchange = await _loadExchangeGroups(reserved.raw['collection_exchange'], bag);
    if (mounted) {
      setState(() {
        // 阶梯过滤失败不拦截商城(全量展示,购买时服务端仍校验顺序)——
        // 仅 recErr == null 时应用「只展示当前可购档」
        var visible = recErr == null ? _filterLadder(items, records) : items;
        // 解锁类隐藏仅在全信号就绪时应用(服务端限购/已解锁校验仍兜底)
        if (bagErr == null) {
          visible = _filterUnlockItems(visible, bag, unlocked);
        }
        _items = visible;
        _lottery = lot is Map ? Map<String, dynamic>.from(lot) : null;
        _exchangeGroups = exchange;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  /// 解锁类道具「购买后不再展示」:限购 1 次——
  /// 已购在包(未使用)或功能已开通即隐藏;使用后道具从背包移除、功能不反弹。
  List<PetShopItemModel> _filterUnlockItems(List<PetShopItemModel> items,
      List<PetBagItemModel> bag, Set<String> unlocked) {
    final bagCodes = bag.map((b) => b.itemCode).toSet();
    return items.where((e) {
      final feature = kUnlockItemFeatures[e.itemCode];
      if (feature == null) return true;
      return !bagCodes.contains(e.itemCode) && !unlocked.contains(feature);
    }).toList();
  }

  List<PetShopItemModel> _filterLadder(
      List<PetShopItemModel> items, List<Map<String, dynamic>> records) {
    final maxBought = <String, int>{};
    for (final r in records) {
      final k = r['ladder_key']?.toString() ?? '';
      final st = (r['step'] as num?)?.toInt() ?? 0;
      if (k.isEmpty) continue;
      if (st > (maxBought[k] ?? 0)) maxBought[k] = st;
    }
    return items.where((e) {
      final lk = e.ladderKey;
      if (lk == null) return true;
      final bought = maxBought[lk] ?? 0;
      final totalSteps = items.where((x) => x.ladderKey == lk).length;
      if (bought >= totalSteps) return false; // 全套购完:整类隐藏
      // step 缺失行不参与隐藏:宁可全量展示也不让购买入口不可达
      // （服务端顺序校验仍兜底）
      if (e.ladderStep == null) return true;
      return e.ladderStep == bought + 1; // 只出下一档
    }).toList();
  }

  List<PetShopItemModel> get _filtered {
    if (_category == 'all') return _items;
    return _items.where((e) => e.categoryLabel == _category).toList();
  }

  Future<void> _buy(
    PetShopItemModel item, {
    bool fromDialog = false,

    /// 满格腾位「扩容并重试」的自动重试：结果 toast 合并扩容信息——
    /// toast 是替换式单条，扩容先吐一条会被购买结果立即覆盖
    ///
    bool afterExpand = false,

    /// 购买数量
    int qty = 1,
  }) async {
    if (_buying.contains(item.id)) return;
    final total = item.priceCoin * qty;
    if (_gold < total) {
      showPetToast(context, '金币不足，可通过任务/游历获取');
      return;
    }
    setState(() => _buying.add(item.id));
    final (result, err) = await PetRpcShop.shopBuy(item.id, qty: qty);
    if (!mounted) return;
    setState(() => _buying.remove(item.id));
    if (err != null) {
      showPetToast(context, afterExpand
          ? '已扩容，购买未完成：${petRpcErrorText(err)}'
          : petRpcErrorText(err));
      return;
    }
    if (result == null) {
      showPetToast(context, afterExpand
          ? '已扩容，购买未完成：$kPetLocalError'
          : kPetLocalError);
      return;
    }
    if (result.isBagFull) {
      // 满格未扣款：走 §5.4 腾位流程（有下一级扩容 → 购买后自动重试；
      // 无 → 引导清理背包）。腾位决策发生在扣款前，不产生资金损失。
      await _showBagFullDialog(item, result,
          fromDialog: fromDialog, qty: qty);
      return;
    }
    setState(() => _gold -= total);
    showPetToast(context,
        item.isExpansion && !afterExpand
            ? '扩容已生效'
            : '已购买「${item.name}」${qty > 1 ? ' ×$qty' : ''}');
    // 静默刷新:扩容生效后阶梯过滤显示下一档道具,普通道具数量角标同步
    _load(showLoading: false);
    if (fromDialog && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('宠物商城'),
        actions: [
          // 概率公示（P2）：读后台已发布蛋池，与抽取判定同版本，纯只读入口
          IconButton(
            tooltip: '概率公示',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PetOddsScreen()),
            ),
            icon: const Icon(Icons.help_outline, size: 22),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Tooltip(
                message: petGoldConverted(_gold) ? '查看完整数额' : '',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  // 未达转换阈值不触发（数值本就完整）
                  onTap: petGoldConverted(_gold) ? () => _showGoldDetail() : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.paid_outlined, size: 18),
                        const SizedBox(width: 4),
                        Text(petGoldLabel(_gold),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  void _showGoldDetail() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.paid_outlined, size: 22),
            const SizedBox(width: 8),
            Text('$_gold',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: PetPawLoading());
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
    // 左侧分类栏 + 右侧商品网格（分类不再占顶部一行
    // 分类数不再受屏宽限制，超出时分类栏自身出滚动条）
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetCategoryRail(
          items: _railItems,
          selected: _category,
          onSelect: (key) => setState(() => _category = key),
        ),
        Expanded(
          child: Column(
            children: [
              // 幸运抽奖（后期玩法入口：仅后台已配且「全部」分类时展示）
              if (_lottery != null && _category == 'all') ...[
                _lotteryCard(cs),
                const SizedBox(height: 8),
              ],
              // 收藏兑换（持有收藏品时展示；「全部」分类）
              if (_exchangeGroups.isNotEmpty && _category == 'all') ...[
                for (final g in _exchangeGroups) ...[
                  _exchangeCard(cs, g),
                  const SizedBox(height: 8),
                ],
              ],
              Expanded(
                child: _filtered.isEmpty
                    ? (_items.isEmpty
                        ? const EmptyWidget(message: '商城暂无在售道具')
                        : const EmptyWidget(message: '该分类下暂无道具'))
                    : RefreshIndicator(
                        onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    // 每行 4 格、正方形物品格（格内显示图标+名称
                    // 其余信息一律收进详情弹窗，故格子必须放大到能容一行名称）
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _filtered.length,
                        itemBuilder: (context, i) => _buildCell(_filtered[i], cs),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 物品格（正方形）：只放图标 + 名称，价格/描述/购买按钮在详情弹窗里
  ///
  /// 图标必须走 [PetItemIcon]（`assets/pets/items/<icon>.svg`，与 `pet_items.icon`
  ///  同源），不可直接画 Material Icon（不查 asset 会不显示物品图标）。
  Widget _buildCell(PetShopItemModel item, ColorScheme cs) {
    final busy = _buying.contains(item.id);
    final affordable = _gold >= item.priceCoin;
    return InkWell(
      onTap: busy ? null : () => _showItemFloat(item),
      borderRadius: BorderRadius.circular(10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PetItemIcon(
                        iconKey: item.iconKey,
                        fallback: _iconFor(item),
                        size: 30,
                        color: affordable ? cs.primary : cs.outline,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 13,
                        // 单行不换行：名称超出格宽时等比缩小（不截断、不折行）
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.name,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: affordable ? cs.onSurface : cs.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
