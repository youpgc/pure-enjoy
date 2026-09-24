import 'package:flutter/material.dart';

import '../models/pet_rpc_models.dart';
import '../utils/pet_bag_meta.dart';
import 'pet_item_icon.dart';

/// 背包容量条（已用格数 / 总容量）
class PetBagCapacityBar extends StatelessWidget {
  const PetBagCapacityBar({
    super.key,
    required this.used,
    required this.capacity,
    this.hint,
    this.onHintTap,
  });

  final int used;
  final int capacity;
  final String? hint;
  final VoidCallback? onHintTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = capacity <= 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$used / $capacity 格',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ratio >= 1 ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: onHintTap,
                child: Text(
                  hint!,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个格位（坐标 = pet_bag_items.slot_index，空格也占位）
///
/// 长按拖动到任意格换位/移入；[canAccept] 由页面判定（同道具不落地，
/// 服务端换位不合并堆叠，引导走「整理」）。
class PetBagSlotCell extends StatelessWidget {
  const PetBagSlotCell({
    super.key,
    required this.slot,
    required this.canAccept,
    required this.onDrop,
    this.item,
    this.dimmed = false,
    this.busy = false,
    this.onTap,
    this.onDragStarted,
    this.onDragEnded,
  });

  final int slot;
  final PetBagItemModel? item;

  /// 页签过滤时非本分类的格子：置灰但保持坐标不变
  final bool dimmed;
  final bool busy;
  final bool Function(int? fromSlot) canAccept;
  final void Function(int fromSlot) onDrop;
  final VoidCallback? onTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final it = item;
    return Opacity(
      opacity: dimmed ? 0.28 : 1,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => canAccept(d.data),
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (context, enters, rejected) {
          final hot = enters.isNotEmpty;
          final borderColor = hot
              ? cs.primary
              : rejected.isNotEmpty
                  ? cs.error.withValues(alpha: 0.7)
                  : cs.outlineVariant.withValues(alpha: 0.7);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: hot
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: hot ? 2 : 1,
              ),
            ),
            child: it == null ? _emptySlot(cs) : _filledSlot(context, cs, it),
          );
        },
      ),
    );
  }

  Widget _emptySlot(ColorScheme cs) => Center(
        child: Icon(
          Icons.add,
          size: 16,
          color: cs.outlineVariant.withValues(alpha: 0.9),
        ),
      );

  Widget _filledSlot(BuildContext context, ColorScheme cs, PetBagItemModel it) {
    final face = _SlotFace(
      item: it,
      busy: busy,
      onTap: onTap,
    );
    return LongPressDraggable<int>(
      data: slot,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 56,
          height: 56,
          child: _SlotFace(item: it, busy: false, onTap: null),
        ),
      ),
      childWhenDragging: _emptySlot(cs),
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded?.call(),
      child: face,
    );
  }
}

class _SlotFace extends StatelessWidget {
  const _SlotFace({
    required this.item,
    required this.busy,
    this.onTap,
  });

  final PetBagItemModel item;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
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
                  // 2026-09-24 定版：每行 4 格、格内图标 + 名称（单行不换行，
                  // 超宽等比缩小）；其余信息（效果/数量上限/操作）看详情弹窗。
                  // 数量角标保留——一格多份是背包的必要信息，去掉会看不出堆了几张。
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PetItemIcon(
                        iconKey: item.iconKey,
                        fallback: petBagFallbackIcon(item),
                        size: 30,
                        color: item.isEgg ? cs.tertiary : cs.primary,
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 12,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.name,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!item.isEgg && (item.quantity > 1 || item.isStackFull))
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: item.isStackFull
                              ? cs.tertiaryContainer
                              : cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          // 堆满时数量已等于上限，角标改示「满」，具体数值看详情
                          item.isStackFull ? '满' : '${item.quantity}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: item.isStackFull
                                ? cs.onTertiaryContainer
                                : cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
