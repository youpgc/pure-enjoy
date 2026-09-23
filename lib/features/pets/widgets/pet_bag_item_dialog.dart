import 'package:flutter/material.dart';

import '../models/pet_rpc_models.dart';
import '../utils/pet_bag_meta.dart';
import 'pet_item_icon.dart';

/// 背包物品悬浮窗（信息 + 操作按钮）
///
/// 按钮先关闭弹窗再回调，调用方无需自行 pop；[busy] 为 true 时按钮全部禁用。
/// [extraAction] 是 P2 道具的专属去向（开通功能 / 去养成页洗练 / 去孵蛋页加速），
/// 与「使用」「丢弃」并列显示；null 即无附加动作。
Future<void> showPetBagItemDialog(
  BuildContext context, {
  required PetBagItemModel item,
  required bool busy,
  required bool canUse,
  ({String label, VoidCallback onTap})? extraAction,
  VoidCallback? onHatch,
  VoidCallback? onUse,
  VoidCallback? onDiscard,
}) {
  final cs = Theme.of(context).colorScheme;
  final desc = petBagEffectDesc(item);
  void fire(VoidCallback? action) {
    Navigator.of(context).pop();
    action?.call();
  }

  return showDialog<void>(
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
                    fallback: petBagFallbackIcon(item),
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
                        // 上限 = pet_items.stack_limit（缺列兜底后台 pet_config.stack_limit_default）；
                        // 两者皆无时不猜数值，只显示数量
                        '${petBagCategoryLabel(item.category)} · '
                        '数量 ${item.quantity}'
                        '${item.stackLimit == null ? '' : '/${item.stackLimit}'}',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(desc,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (item.isEgg)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => fire(onHatch),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      // 蛋统一叫「孵化」：即开型当场出宠，等待型由调用方转孵蛋页
                      label: const Text('孵化'),
                    ),
                  )
                else ...[
                  if (canUse) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => fire(onUse),
                        icon: const Icon(Icons.touch_app_outlined, size: 18),
                        label: const Text('使用'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side:
                            BorderSide(color: cs.error.withValues(alpha: 0.5)),
                      ),
                      onPressed: busy ? null : () => fire(onDiscard),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('丢弃'),
                    ),
                  ),
                ],
              ],
            ),
            ..._extraActionButtons(extraAction, busy, fire),
          ],
        ),
      ),
    ),
  );
}

/// 附加动作按钮（P2 道具的去向）。动作与文案都来自调用方，本函数只负责排版。
List<Widget> _extraActionButtons(
  ({String label, VoidCallback onTap})? action,
  bool busy,
  void Function(VoidCallback) fire,
) {
  if (action == null) return const [];
  final label = action.label;
  final onTap = action.onTap;
  return [
    const SizedBox(height: 10),
    SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: busy ? null : () => fire(onTap),
        icon: const Icon(Icons.arrow_forward_circle, size: 18),
        label: Text(label),
      ),
    ),
  ];
}
