import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_errors.dart';
import '../utils/pet_gold_format.dart';
import '../widgets/pet_category_rail.dart';
import '../widgets/pet_item_icon.dart';
import 'pet_bag_screen.dart';
import 'pet_odds_screen.dart';
import '../widgets/pet_toast.dart';

/// 宠物商城页（左侧分类栏 + 物品格 + 悬浮窗购买）
///
/// 布局（2026-09-24 定版）：分类栏在**左侧竖排**（栅格 tile，超出出滚动条），
/// 右侧物品格网格每行 6 格、正方形格；点击物品弹悬浮窗展示信息与购买按钮。
/// 分类清单取自 `PetShopItemModel.categoryLabels`（P1 五类 + P2 五类 + 其他）。
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

  /// 当前分类（all / [PetShopItemModel.categoryLabels] 之一）
  String _category = 'all';

  /// 分类栏项：清单来自模型（与 categoryLabel 同源，防漂移），图标在本页映射
  static List<PetCategoryItem> get _railItems => [
        const PetCategoryItem('all', '全部', icon: Icons.grid_view_outlined),
        for (final label in PetShopItemModel.categoryLabels)
          PetCategoryItem(label, label, icon: _labelIcon(label)),
      ];

  static IconData _labelIcon(String label) => switch (label) {
        '宠物蛋' => Icons.egg_outlined,
        '食物' => Icons.restaurant,
        '医疗' => Icons.medical_services_outlined,
        '清洁' => Icons.shower_outlined,
        '玩具' => Icons.toys_outlined,
        '救援' => Icons.health_and_safety_outlined,
        '扩容' => Icons.unfold_more,
        '进化' => Icons.auto_awesome_outlined,
        '加速' => Icons.speed_outlined,
        '洗练' => Icons.replay_outlined,
        '解锁' => Icons.lock_open_outlined,
        _ => Icons.category_outlined,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    final (items, err) = await PetRpc.fetchShopItems();
    final (records, recErr) = await PetRpc.fetchExpansionRecords();
    final (reserved, _) = await PetRpcP2.fetchReserved();
    final lot = reserved.raw['lottery'];
    if (mounted) {
      setState(() {
        // 阶梯过滤失败不拦截商城(全量展示,购买时服务端仍校验顺序)——
        // 仅 recErr == null 时应用「只展示当前可购档」
        _items = recErr == null ? _filterLadder(items, records) : items;
        _lottery = lot is Map ? Map<String, dynamic>.from(lot) : null;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  /// 阶梯道具「只展示当前可购档」(20261021):每套阶梯仅保留「已购最大步 + 1」
  /// 的那一档,已购档与未来档不展示;整套购完则整类隐藏(需求 §6.3 达上限不展示)。
  /// 服务端 shop_buy 的顺序校验仍兜底,此处只是把展示做对。
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
      // (服务端顺序校验仍兜底;20261021 审查 P2)
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
    /// （复审批 P3：'扩容已生效' 存活不足百毫秒）
    bool afterExpand = false,
  }) async {
    if (_buying.contains(item.id)) return;
    if (_gold < item.priceCoin) {
      showPetToast(context, '金币不足，可通过任务/历险获取');
      return;
    }
    setState(() => _buying.add(item.id));
    final (result, err) = await PetRpc.shopBuy(item.id);
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
      await _showBagFullDialog(item, result, fromDialog: fromDialog);
      return;
    }
    setState(() => _gold -= item.priceCoin);
    showPetToast(context,
        item.isExpansion && !afterExpand
            ? '扩容已生效'
            : '已购买「${item.name}」');
    // 静默刷新:扩容生效后阶梯过滤显示下一档道具,普通道具数量角标同步
    // (20261021 用户反馈:购买扩容后列表仍显示旧道具)
    _load(showLoading: false);
    if (fromDialog && mounted) Navigator.of(context).pop();
  }

  /// 满格腾位对话框（需求 §5.4）：展示容量占用与本次所需格数；
  /// 服务端给出下一级扩容道具时提供「扩容并重试」，购买成功后同流程内
  /// 自动重试原购买；已达上限则只有「去清理背包」一条路径。
  Future<void> _showBagFullDialog(
    PetShopItemModel item,
    PetShopBuyResultModel result, {
    bool fromDialog = false,
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
          await PetRpc.shopBuy(expand.itemId);
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
      await _buy(item, fromDialog: fromDialog, afterExpand: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('宠物商城'),
        actions: [
          // 概率公示（P2）：读后台已发布蛋池，与抽取判定同版本，纯只读入口
          // （20261021 用户拍板：入口收敛为问号图标，不占 AppBar 文案位）
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

  /// 幸运抽奖卡：价格/限购说明 + 抽取按钮（结果复用孵化结果弹窗）
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
                  // 面向用户的营销文案（机制与概率数字只在公示页，问号入口可达）
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
    // 左侧分类栏 + 右侧商品网格（2026-09-24 布局定版：分类不再占顶部一行，
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
              Expanded(
                child: _filtered.isEmpty
                    ? (_items.isEmpty
                        ? const EmptyWidget(message: '商城暂无在售道具')
                        : const EmptyWidget(message: '该分类下暂无道具'))
                    : RefreshIndicator(
                        onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    // 每行 4 格、正方形物品格（2026-09-24 定版：格内显示图标+名称，
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
  /// 同源）。此前这里直接画 Material `Icon(_iconFor(item))`，永远不查 asset，
  /// 是「商城格子不显示物品图标」的直接原因（2026-09-24 修复）。
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

  // ---------- 物品悬浮窗（信息 + 购买） ----------

  void _showItemFloat(PetShopItemModel item) {
    final cs = Theme.of(context).colorScheme;
    final affordable = _gold >= item.priceCoin;
    final busy = _buying.contains(item.id);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: affordable && !busy
                      ? () => _buy(item, fromDialog: true)
                      : null,
                  icon: const Icon(Icons.paid_outlined, size: 18),
                  label: Text(
                    busy ? '购买中' : (affordable ? '购买' : '金币不足'),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      _ => Icons.inventory_2_outlined,
    };
  }
}
