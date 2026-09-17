import 'package:flutter/material.dart';

/// 2D 宠物立绘动效组件（呼吸浮动 + 点击互动反馈）
///
/// 静态立绘（assets/pets/*.png）之上叠加轻量动效，替代 3D 渲染层：
/// - idle：缓慢呼吸（缩放 1.0↔1.04）+ 上下浮动（±4px）；
/// - 点击：快速弹跳一次（回弹曲线）；
/// - [excited] 置 true 时呼吸加快幅度变大（喂食/领奖后的开心态）。
///
/// 素材未登记种属时回退占位图标（保持与 pet_art 解析规则一致）。
class PetLivingArt extends StatefulWidget {
  const PetLivingArt({
    super.key,
    required this.assetPath,
    this.height = 200,
    this.excited = false,
    this.onTap,
  });

  final String? assetPath;
  final double height;
  final bool excited;
  final VoidCallback? onTap;

  @override
  State<PetLivingArt> createState() => _PetLivingArtState();
}

class _PetLivingArtState extends State<PetLivingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 呼吸周期：常态 3.2s；开心态 1.6s（数值越短越快）
  Duration get _period =>
      Duration(milliseconds: widget.excited ? 1600 : 3200);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _period)..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PetLivingArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.excited != widget.excited) {
      _ctrl.duration = _period;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final art = widget.assetPath != null
        ? Image.asset(
            widget.assetPath!,
            height: widget.height,
            fit: BoxFit.contain,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Icon(Icons.pets, size: 64, color: cs.primary),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_ctrl.value);
          // 呼吸缩放：常态 1.0↔1.02，开心态 1.0↔1.05
          final scale = 1.0 + (widget.excited ? 0.05 : 0.02) * t;
          // 浮动：常态 ±4px，开心态 ±8px
          final dy = (widget.excited ? 8.0 : 4.0) * (t * 2 - 1);
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: art,
      ),
    );
  }
}
