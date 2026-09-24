import 'package:flutter/material.dart';

/// 分类项（key 用于筛选比对，label 展示，icon 可选）
class PetCategoryItem {
  const PetCategoryItem(this.key, this.label, {this.icon});

  final String key;
  final String label;
  final IconData? icon;
}

/// 宠物模块分类导航（背包页 / 商城页共用）
///
/// 定版布局（2026-09-24）：分类从**顶部横排 chip** 改为**左侧竖排栅格 tile**——
/// 一屏放得下的分类数不再受横向宽度限制，超出时右侧显形滚动条；
/// 项与格位网格同为「格子」视觉语言，不再用 Tag 形态。
///
/// 自带 [ScrollController]：`thumbVisibility` 与拖动都依赖 controller，
/// 不显式给出时只能靠 PrimaryScrollController 兜底（嵌套在 Row 里时不保证命中）。
class PetCategoryRail extends StatefulWidget {
  const PetCategoryRail({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.width = 78,
  });

  final List<PetCategoryItem> items;
  final String selected;
  final ValueChanged<String> onSelect;
  final double width;

  static const double tileHeight = 62;
  static const double tileSpacing = 8;
  static const double verticalPadding = 16;

  @override
  State<PetCategoryRail> createState() => _PetCategoryRailState();
}

class _PetCategoryRailState extends State<PetCategoryRail> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = widget.items;
    return SizedBox(
      width: widget.width,
      child: LayoutBuilder(
        builder: (context, box) {
          final contentH = items.length * PetCategoryRail.tileHeight +
              (items.isEmpty
                  ? 0
                  : (items.length - 1) * PetCategoryRail.tileSpacing) +
              PetCategoryRail.verticalPadding;
          return RawScrollbar(
            controller: _scroll,
            // 只在真的放不下时显形（不常驻，避免无谓的竖条）
            thumbVisibility: contentH > box.maxHeight,
            thickness: 4,
            radius: const Radius.circular(2),
            color: cs.outlineVariant,
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(
                  vertical: PetCategoryRail.verticalPadding / 2),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: PetCategoryRail.tileSpacing),
              itemBuilder: (context, i) => _tile(cs, items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(ColorScheme cs, PetCategoryItem item) {
    final on = item.key == widget.selected;
    return InkWell(
      onTap: () => widget.onSelect(item.key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: PetCategoryRail.tileHeight,
        decoration: BoxDecoration(
          color: on ? cs.secondaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? cs.secondary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon != null)
              Icon(
                item.icon,
                size: 19,
                color: on ? cs.onSecondaryContainer : cs.onSurfaceVariant,
              ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
