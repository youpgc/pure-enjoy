import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_attributes_sheet.dart';
import '../widgets/pet_home_overlays.dart';
import '../widgets/pet_item_icon.dart';
import 'pet_shop_screen.dart';

/// 宠物背包页（分类 + 物品格 + 悬浮窗操作）
///
/// - 布局（2026-09-17 定版）：顶部分类页签（全部/蛋/消耗品/工具），
///   物品格网格每行 6 格、正方形格；点击物品弹悬浮窗展示信息与操作按钮；
/// - 蛋条目：悬浮窗内「立即孵化」（成功弹结果卡）；等待型仅展示（P1 无等待型蛋池）；
/// - 消耗品：feed/clean/toy 对在养宠物使用；
/// - 丢弃走 rpc_pet_discard_items（入参按 slot_index + quantity，服务端契约），
///   append-only 流水可对账，丢弃不可恢复；
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

  /// 当前分类（all / egg / consumable / tool）
  String _category = 'all';
  String? _busyId;

  static const _tabs = <(String, String, IconData)>[
    ('all', '全部', Icons.grid_view_outlined),
    ('egg', '蛋', Icons.egg_outlined),
    ('consumable', '消耗品', Icons.restaurant),
    ('tool', '工具', Icons.build_outlined),
  ];

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

  List<PetBagItemModel> get _filtered {
    if (_category == 'all') return _items;
    return _items.where((e) => e.category == _category).toList();
  }

  Future<void> _hatchEgg(PetBagItemModel egg) async {
    Navigator.of(context).pop(); // 关闭悬浮窗
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
    showPetBirthDialog(context, img: null, result: r); // 复用主页诞生弹窗
    _load();
  }

  /// 洗练剂（tool/refine_reassign）：对在养宠物重掷升级加点（总值守恒，
  /// 孵化基础属性不动），结果经 before/after 演出展示
  Future<void> _refineItem(PetBagItemModel item) async {
    Navigator.of(context).pop();
    if (widget.petId == null) return _toast('当前没有在养宠物');
    await _busy(() async {
      final (data, err) =
          await PetRpc.refineReassign(widget.petId!, itemId: item.itemId);
      if (!mounted) return;
      if (err != null || data == null) return _toast(petRpcErrorText(err));
      await showPetRefineResultDialog(context,
          before: (data['before'] as Map?)?.cast<String, dynamic>() ?? const {},
          after: (data['after'] as Map?)?.cast<String, dynamic>() ?? const {});
      _load();
    }, item.id);
  }

  Future<void> _useItem(PetBagItemModel item) async {
    Navigator.of(context).pop();
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
    Navigator.of(context).pop();
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
      // 服务端契约：p_rows 为 [{slot_index, quantity}]（rpc_pet_discard_items 定义）
      final err = await PetRpc.discardItems([
        {'slot_index': item.slotIndex, 'quantity': item.quantity},
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
    return Column(
      children: [
        // 分类页签
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              for (final (key, label, icon) in _tabs) ...[
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: _category == key ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                    ),
                    label: Text(label),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _category == key ? cs.onSecondaryContainer : cs.onSurface,
                    ),
                    selected: _category == key,
                    onSelected: (_) => setState(() => _category = key),
                  ),
                ),
                if (key != _tabs.last.$1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? _emptyView(cs)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    // 每行 6 格、正方形物品格（2026-09-17 定版）
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
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
    );
  }

  Widget _emptyView(ColorScheme cs) {
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
    return const EmptyWidget(message: '该分类下暂无物品');
  }

  /// 物品格（正方形）：图标 + 数量角标
  Widget _buildCell(PetBagItemModel item, ColorScheme cs) {
    final busy = _busyId == item.id;
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
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    PetItemIcon(
                      iconKey: item.iconKey,
                      fallback: _iconFor(item),
                      size: 26,
                      color: item.isEgg ? cs.tertiary : cs.primary,
                    ),
                    if (!item.isEgg && item.quantity > 1)
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  // ---------- 物品悬浮窗（信息 + 操作按钮） ----------

  void _showItemFloat(PetBagItemModel item) {
    final cs = Theme.of(context).colorScheme;
    final usable = widget.petId != null && _usable(item);
    final isRefine = widget.petId != null && item.effectType == 'refine_reassign';
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
                      color: item.isEgg ? cs.tertiary : cs.primary,
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
                          '${_categoryLabel(item.category)} · 数量 ${item.quantity}',
                          style:
                              TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_effectDesc(item).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _effectDesc(item),
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  if (item.isEgg)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busyId == null ? () => _hatchEgg(item) : null,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('立即孵化'),
                      ),
                    )
                  else ...[
                    if (usable) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busyId == null ? () => _useItem(item) : null,
                          icon: const Icon(Icons.touch_app_outlined, size: 18),
                          label: const Text('使用'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (isRefine) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busyId == null ? () => _refineItem(item) : null,
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('洗练'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        ),
                        onPressed: _busyId == null ? () => _discard(item) : null,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('丢弃'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _usable(PetBagItemModel item) =>
      item.category == 'consumable' &&
      const {'feed', 'clean', 'toy', 'heal'}.contains(item.effectType);

  String _categoryLabel(String category) => switch (category) {
        'egg' => '蛋',
        'consumable' => '消耗品',
        'tool' => '工具',
        _ => '物品',
      };

  /// 效果描述（依据 pet_items.effect 结构化字段生成，不臆测数值）
  String _effectDesc(PetBagItemModel item) {
    final parts = <String>[];
    void addNum(String key, String label) {
      final v = (item.effect[key] as num?)?.toInt();
      if (v != null && v > 0) parts.add('$label+$v');
    }

    switch (item.effectType) {
      case 'feed':
        addNum('hunger', '饱食');
        addNum('mood', '心情');
        addNum('exp', '经验');
      case 'clean':
        parts.add('清洁宠物');
        addNum('mood', '心情');
      case 'toy':
        parts.add('陪它玩耍');
        addNum('mood', '心情');
        addNum('exp', '经验');
      case 'rescue':
        parts.add('历险遇险时立即救回宠物');
      case 'heal':
        parts.add('恢复宠物健康（历险受伤后使用）');
      case 'refine_reassign':
        parts.add('重新分配宠物升级获得的属性加点（孵化基础属性不受影响）');
      default:
        if (item.isEgg) parts.add('点击立即孵化，见证新伙伴诞生');
    }
    return parts.join(' · ');
  }

  IconData _iconFor(PetBagItemModel item) {
    if (item.isEgg) return Icons.egg_outlined;
    return switch (item.effectType) {
      'feed' => Icons.restaurant,
      'clean' => Icons.shower_outlined,
      'toy' => Icons.toys_outlined,
      'rescue' => Icons.health_and_safety_outlined,
      'heal' => Icons.healing_outlined,
      'refine_reassign' => Icons.auto_fix_high,
      _ => Icons.inventory_2_outlined,
    };
  }
}
