import 'package:flutter/material.dart';

import '../utils/pet_art_resolver.dart';

/// 宠物头像卡：以弯曲树中性帧 c1_neutral（与舞台形象同源同款）作头像内容,
/// 用于寄养仓库等列表的物品化展示（此前纯文字视觉单薄,20261021 用户需求）。
///
/// 取图链：弯曲树中性帧 → 整只底图 → 通用爪印兜底（素材未产出种属自动
/// 降级,铁律 8）。默认 40×40,可点（[onTap] 由调用方定义交互）。
class PetAvatarCard extends StatelessWidget {
  const PetAvatarCard({
    super.key,
    required this.speciesCode,
    required this.stage,
    this.size = 40,
    this.onTap,
  });

  final String speciesCode;
  final int stage;
  final double size;
  final VoidCallback? onTap;

  String? _art() {
    final dir = petBendGeo(speciesCode, stage)?.dir;
    if (dir != null) return '$dir/c1_neutral.png';
    return petBaseArt(speciesCode, stage);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final img = _art();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(2),
        child: img == null
            ? Icon(Icons.pets,
                size: size * 0.5, color: cs.onSurfaceVariant)
            : Image.asset(
                img,
                fit: BoxFit.contain,
                cacheWidth:
                    petDecodeWidth(size, MediaQuery.devicePixelRatioOf(context)),
                errorBuilder: (_, __, ___) => Icon(Icons.pets,
                    size: size * 0.5, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }
}
