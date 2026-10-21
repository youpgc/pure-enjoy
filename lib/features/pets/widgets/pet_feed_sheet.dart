import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_bag_meta.dart';
import '../utils/pet_errors.dart';
import 'pet_item_icon.dart';
import 'pet_toast.dart';

/// 主页「口粮」选择浮层（2026-09-24 新增）
///
/// 定版口径：喂食**不限次数**——`free_feed_daily` 是每日**免费额度**，额度不可用
/// （冷却中 / 当日次数用完）时改吃背包里的口粮道具（服务端同一条 `rpc_pet_feed`
/// 的道具档：不占免费次数、不受冷却限制，见 feature_pet_feed_full_20260924.sql §2）。
/// 因此主页喂食钮只要"没吃饱"就可点，本浮层就是免费额度不可用时的出口。
///
/// 返回 true 表示成功喂掉一份口粮（调用方据此刷新总览并庆祝）。
///
/// [full] = 宠物已饱（饱食 ≥ feed_full_hunger，调用方按 summary 同口径判定）：
/// 道具行整列禁用并标注「已饱」——饱时喂食会被服务端拒绝（口粮不消耗），
/// 提前禁用杜绝无效操作（20261021 用户拍板：满 100 禁用）。
Future<bool> showPetFeedSheet(BuildContext context, String petId,
    {bool full = false}) async {
  final (items, err) = await PetRpc.fetchBag();
  if (!context.mounted) return false;
  if (err != null) {
    showPetToast(context, petRpcErrorText(err));
    return false;
  }
  final foods = items
      .where((e) => e.effectType == PetItemEffectType.feed.code)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  var fed = false;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 与「更多」菜单弹窗同款配置：不带 isScrollControlled/constraints，
    // 全宽贴底；长列表由内部 Flexible + shrinkWrap 兜底
    builder: (_) => _PetFeedSheet(
        petId: petId, foods: foods, full: full, onFed: () => fed = true),
  );
  return fed;
}

class _PetFeedSheet extends StatefulWidget {
  const _PetFeedSheet({
    required this.petId,
    required this.foods,
    required this.full,
    required this.onFed,
  });

  final String petId;
  final List<PetBagItemModel> foods;

  /// 宠物已饱（饱食 ≥ feed_full_hunger）：整列禁用，明示原因
  final bool full;
  final VoidCallback onFed;

  @override
  State<_PetFeedSheet> createState() => _PetFeedSheetState();
}

class _PetFeedSheetState extends State<_PetFeedSheet> {
  String? _busyId;

  Future<void> _feed(PetBagItemModel item) async {
    if (_busyId != null) return;
    setState(() => _busyId = item.id);
    final err = await PetRpc.feed(widget.petId, itemId: item.itemId);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    final desc = petBagEffectDesc(item);
    widget.onFed();
    Navigator.pop(context);
    showPetToast(context, '已喂「${item.name}」${desc.isEmpty ? '' : ' · $desc'}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foods = widget.foods;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text('用口粮喂食',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (widget.full)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text('它已经吃得饱饱的啦，等消化后再喂吧',
                  style: TextStyle(
                      fontSize: 13, color: cs.error.withValues(alpha: 0.85))),
            )
          else if (foods.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '背包里没有可喂食的道具，可在商城「食物」分类购买。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            )
          else
            // Flexible + shrinkWrap：口粮少时按内容收缩，多时在弹层限高内滚动
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: foods.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = foods[i];
                  final busy = _busyId == item.id;
                  final desc = petBagEffectDesc(item);
                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: PetItemIcon(
                        iconKey: item.iconKey,
                        fallback: petBagFallbackIcon(item),
                        size: 26,
                        color: cs.primary,
                      ),
                    ),
                    title: Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: desc.isEmpty
                        ? null
                        : Text(desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : widget.full
                            ? Text('已饱',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant))
                            : Text('×${item.quantity}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant)),
                    // 已饱整列禁用：服务端会拒（口粮不消耗），提前禁明示原因
                    onTap: _busyId == null && !widget.full
                        ? () => _feed(item)
                        : null,
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Text('小贴士：解锁「高级食盆」后，长按主页喂食键可一键喂养全部伙伴',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
