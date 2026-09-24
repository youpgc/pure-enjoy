import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_bag_meta.dart';
import '../utils/pet_errors.dart';
import 'pet_item_icon.dart';

/// 主页「口粮」选择浮层（2026-09-24 新增）
///
/// 定版口径：喂食**不限次数**——`free_feed_daily` 是每日**免费额度**，额度不可用
/// （冷却中 / 当日次数用完）时改吃背包里的口粮道具（服务端同一条 `rpc_pet_feed`
/// 的道具档：不占免费次数、不受冷却限制，见 feature_pet_feed_full_20260924.sql §2）。
/// 因此主页喂食钮只要"没吃饱"就可点，本浮层就是免费额度不可用时的出口。
///
/// 返回 true 表示成功喂掉一份口粮（调用方据此刷新总览并庆祝）。
Future<bool> showPetFeedSheet(BuildContext context, String petId) async {
  final (items, err) = await PetRpc.fetchBag();
  if (!context.mounted) return false;
  if (err != null) {
    showSnackBar(context, petRpcErrorText(err));
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
    isScrollControlled: true,
    builder: (_) =>
        _PetFeedSheet(petId: petId, foods: foods, onFed: () => fed = true),
  );
  return fed;
}

class _PetFeedSheet extends StatefulWidget {
  const _PetFeedSheet({
    required this.petId,
    required this.foods,
    required this.onFed,
  });

  final String petId;
  final List<PetBagItemModel> foods;
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
      showSnackBar(context, petRpcErrorText(err));
      return;
    }
    final desc = petBagEffectDesc(item);
    widget.onFed();
    Navigator.pop(context);
    showSnackBar(context, '已喂「${item.name}」${desc.isEmpty ? '' : ' · $desc'}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foods = widget.foods;
    return SafeArea(
      child: ConstrainedBox(
        // 口粮种类不多，限高避免空态时整屏空白
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text('用口粮喂食',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (foods.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  '背包里没有可喂食的道具，可在商城「食物」分类购买。',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              )
            else
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
                          : Text('×${item.quantity}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant)),
                      onTap: _busyId == null ? () => _feed(item) : null,
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
