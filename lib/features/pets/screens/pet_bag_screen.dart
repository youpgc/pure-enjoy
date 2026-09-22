import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_bag_meta.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_bag_grid.dart';
import '../widgets/pet_bag_item_dialog.dart';
import '../widgets/pet_home_overlays.dart';
import 'pet_shop_screen.dart';

/// 宠物背包页（格位坐标制 + 分类页签 + 拖拽换位）
///
/// - 网格严格按 `pet_bag_items.slot_index` 定位：`itemCount = 背包容量`，
///   第 i 格即 slot_index=i，无行的格位渲染为空格（与服务端坐标系一致）；
/// - 分类页签只置灰不过滤（方案 A）：过滤会改变格号与坐标的对应关系；
/// - 拖拽换位走 `rpc_pet_swap_slot`（交换/移入空格）；服务端换位不合并
///   堆叠，故同道具格位禁止落点，合并交由「整理」`rpc_pet_compact_bag`；
/// - 丢弃走 `rpc_pet_discard_items`（按 slot_index + quantity），不可恢复。
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
  Map<int, PetBagItemModel> _bySlot = const {};
  int _capacity = 0;
  int _gold = 0;

  /// 当前页签（all / egg / consumable / tool）
  String _category = 'all';
  String? _busyId;

  /// 页签图标：按枚举分支（无字符串键副本，新增类目时编译期强制补齐）
  static IconData _categoryIcon(PetBagCategory c) => switch (c) {
        PetBagCategory.egg => Icons.egg_outlined,
        PetBagCategory.consumable => Icons.restaurant,
        PetBagCategory.tool => Icons.build_outlined,
        PetBagCategory.equip => Icons.inventory_2_outlined,
      };

  /// 页签取自 PetBagCategory；equip 属 P2 穿戴，一期不出现在页签里
  static List<(String, String, IconData)> get _tabs => [
        ('all', '全部', Icons.grid_view_outlined),
        for (final c in PetBagCategory.values)
          if (c != PetBagCategory.equip) (c.code, c.label, _categoryIcon(c)),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true, bool forceRefresh = false}) async {
    if (showLoading) setState(() => _loading = true);
    // 总览先行：PetRpc.fetchBag 的堆叠上限兜底值取自总览回传的 pet_config 快照
    final summary =
        await PetService.instance.fetchSummary(forceRefresh: forceRefresh);
    final (items, err) = await PetRpc.fetchBag();
    if (!mounted) return;
    final bySlot = <int, PetBagItemModel>{
      for (final e in items) e.slotIndex: e,
    };
    // 容量以后台配置为准；越界格（后台下调容量后遗留）并入显示范围，避免道具不可见
    var cap = summary?.capacities?.backpack ?? 0;
    for (final slot in bySlot.keys) {
      if (slot >= cap) cap = slot + 1;
    }
    setState(() {
      _items = items;
      _bySlot = bySlot;
      _capacity = cap;
      _gold = summary?.wallet.goldBalance ?? 0;
      _error = err == null ? null : petRpcErrorText(err);
      _loading = false;
    });
  }

  // ---------- 操作 ----------

  Future<void> _run(Future<void> Function() action, String id) async {
    setState(() => _busyId = id);
    await action();
    if (mounted) setState(() => _busyId = null);
  }

  Future<void> _hatchEgg(PetBagItemModel egg) async {
    await _run(() async {
      final (eggs, fetchErr) = await PetRpc.fetchEggs();
      if (fetchErr != null) return _toast(petRpcErrorText(fetchErr));
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
      showPetBirthDialog(context, img: null, result: result); // 复用主页诞生弹窗
      await _load(showLoading: false, forceRefresh: true);
    }, egg.id);
  }

  Future<void> _useItem(PetBagItemModel item) async {
    if (widget.petId == null) return _toast('当前没有在养宠物');
    await _run(() async {
      final err = await PetRpc.useItem(item.itemId, widget.petId!);
      if (!mounted) return;
      if (err != null) return _toast(petRpcErrorText(err));
      _toast('已使用「${item.name}」');
      await _load(showLoading: false);
    }, item.id);
  }

  Future<void> _discard(PetBagItemModel item) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('丢弃确认'),
        content: Text('确定丢弃「${item.name}」×${item.quantity}？丢弃不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('丢弃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      // 服务端契约：p_rows 为 [{slot_index, quantity}]（rpc_pet_discard_items 定义）
      final err = await PetRpc.discardItems([
        {'slot_index': item.slotIndex, 'quantity': item.quantity},
      ]);
      if (!mounted) return;
      if (err != null) return _toast(petRpcErrorText(err));
      _toast('已丢弃');
      await _load(showLoading: false);
    }, item.id);
  }

  Future<void> _compact() async {
    await _run(() async {
      final err = await PetRpc.compactBag();
      if (!mounted) return;
      if (err != null) return _toast(petRpcErrorText(err));
      _toast('背包已整理');
      await _load(showLoading: false, forceRefresh: true);
    }, 'compact');
  }

  /// 拖拽落点判定（S3-8a）：同道具不落地——服务端 swap_slot 只换坐标不合并
  /// 堆叠，落到同道具格会让数量与预期不符，合并统一交给「整理」。
  bool _canAccept(int? from, int to) {
    if (from == null || from == to || _busyId != null) return false;
    final src = _bySlot[from];
    if (src == null) return false;
    final dst = _bySlot[to];
    return dst == null || dst.itemId != src.itemId;
  }

  Future<void> _swap(int from, int to) async {
    final src = _bySlot[from];
    if (src == null || !_canAccept(from, to)) return;
    await _run(() async {
      final err = await PetRpc.swapSlot(from, to);
      if (!mounted) return;
      if (err != null) {
        _toast(petRpcErrorText(err));
        // 越界/并发（PET_BAG_FULL_RACE）后以服务端为准重拉
        return _load(showLoading: false, forceRefresh: true);
      }
      await _load(showLoading: false);
    }, src.id);
  }

  void _showItemFloat(PetBagItemModel item) {
    showPetBagItemDialog(
      context,
      item: item,
      busy: _busyId != null,
      canUse: widget.petId != null && petBagItemUsable(item),
      onHatch: () => _hatchEgg(item),
      onUse: () => _useItem(item),
      onDiscard: () => _discard(item),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- 布局 ----------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('背包'),
        actions: [
          TextButton.icon(
            onPressed: _busyId == null ? _compact : null,
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
            FilledButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) return _emptyView(cs);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              for (final (i, tab) in _tabs.indexed) ...[
                Expanded(
                  child: _tabChip(cs, tab.$1, tab.$2, tab.$3),
                ),
                if (i != _tabs.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        PetBagCapacityBar(
          used: _items.length,
          capacity: _capacity,
          hint: _hint(),
          onHintTap: _hasHoles || _mergeable ? _compact : null,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(showLoading: false, forceRefresh: true),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              // 格子少时也要能下拉刷新
              physics: const AlwaysScrollableScrollPhysics(),
              // 每行 6 格、正方形（2026-09-17 定版）；格号恒等于 slot_index
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _capacity,
              itemBuilder: (context, slot) {
                final item = _bySlot[slot];
                return PetBagSlotCell(
                  slot: slot,
                  item: item,
                  dimmed: _category != 'all' &&
                      item != null &&
                      item.category != _category,
                  busy: item != null && _busyId == item.id,
                  canAccept: (from) => _canAccept(from, slot),
                  onDrop: (from) => _swap(from, slot),
                  onTap: item == null ? null : () => _showItemFloat(item),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabChip(ColorScheme cs, String key, String label, IconData icon) {
    final selected = _category == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? cs.onSecondaryContainer : cs.onSurface,
      ),
      selected: selected,
      onSelected: (_) => setState(() => _category = key),
    );
  }

  /// 是否存在空洞（有道具落在 >= 行数 的格位上）
  bool get _hasHoles {
    for (final e in _items) {
      if (e.slotIndex >= _items.length) return true;
    }
    return false;
  }

  /// 是否有同道具分散在多格（可经整理合并）
  bool get _mergeable {
    final seen = <String>{};
    for (final e in _items) {
      if (!seen.add(e.itemId)) return true;
    }
    return false;
  }

  String _hint() {
    if (_category != 'all' &&
        !_items.any((e) => e.category == _category)) {
      return '「${petBagCategoryLabel(_category)}」分类下暂无物品，其余格位置灰展示';
    }
    if (_hasHoles || _mergeable) {
      return '检测到空洞格 / 同道具分散，点此整理可合并并压缩格位';
    }
    return '长按道具可拖到空格移动、拖到其它道具换位';
  }

  Widget _emptyView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyWidget(message: '背包空空如也'),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PetShopScreen(goldBalance: _gold)),
            ),
            child: const Text('去商城逛逛'),
          ),
        ],
      ),
    );
  }
}
