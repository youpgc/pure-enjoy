import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 宠物道具/界面图标（洛克风 SVG，2026-09-17 拍板稿落地）
///
/// 资源约定：pet_items.icon 形如 icon/<key>，双端资源
/// assets/pets/items/<key>.svg（App）与 public/pet-icons/<key>.svg（Admin）。
/// 无键或资源缺失时回退 [fallback] Material 图标（与旧版渲染一致）。
class PetItemIcon extends StatelessWidget {
  const PetItemIcon({
    super.key,
    this.iconKey,
    required this.fallback,
    this.size = 26,
    this.color,
  });

  /// 图标资源键（null 或资源缺失时回退）
  final String? iconKey;

  /// 回退 Material 图标
  final IconData fallback;

  final double size;

  /// 回退时的着色（SVG 资源自带配色，不着色）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final key = iconKey;
    if (key == null || key.isEmpty) {
      return Icon(fallback, size: size, color: color);
    }
    return SvgPicture.asset(
      'assets/pets/items/$key.svg',
      width: size,
      height: size,
      // 资源缺失时回退 Material 图标（与 Admin onError 回退键名策略对齐）
      errorBuilder: (_, __, ___) {
        if (kDebugMode) debugPrint('PetItemIcon 资源缺失: $key');
        return Icon(fallback, size: size, color: color);
      },
    );
  }
}
