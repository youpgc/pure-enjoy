import 'package:flutter/material.dart';

/// 2D 宠物帧动画组件（gif 式多帧轮播）
///
/// 2026-09-17 重做：废弃「呼吸缩放 + 上下浮动」的伪动画，改为真正的
/// gif 式帧动画——同形态多帧序列按帧率轮播（眨眼/尾摆），让宠物动起来。
/// - [frames] 帧序列（petIdleFrames 注册表）；空列表时回退 [fallbackAsset]
///   单帧静态展示（未登记种属/高阶形态）；
/// - idle 帧率 3.5 fps，[excited]（喂食/抚摸后的开心态）提升到 8 fps；
/// - 无任何 Transform 位移/缩放，帧序列自身承担全部动效。
class PetLivingArt extends StatefulWidget {
  const PetLivingArt({
    super.key,
    required this.frames,
    this.fallbackAsset,
    this.height,
    this.fit = BoxFit.contain,
    this.excited = false,
    this.onTap,
  });

  /// gif 式帧序列（assets/pets/frames/*）；空 = 无帧动画
  final List<String> frames;

  /// 无帧序列时的单帧立绘回退
  final String? fallbackAsset;

  /// 可选固定高度；不传时按父约束 fit 撑满（满屏舞台用）
  final double? height;
  final BoxFit fit;
  final bool excited;
  final VoidCallback? onTap;

  @override
  State<PetLivingArt> createState() => _PetLivingArtState();
}

class _PetLivingArtState extends State<PetLivingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _index = 0;

  /// 单帧时长：常态 ~286ms（3.5fps）；开心态 ~125ms（8fps）
  Duration get _cycle => Duration(
      milliseconds: (1000 / (widget.excited ? 8.0 : 3.5)).round() *
          (widget.frames.isEmpty ? 1 : widget.frames.length));

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _cycle);
    if (widget.frames.length > 1) _ctrl.repeat();
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    if (widget.frames.isEmpty) return;
    final i =
        ((_ctrl.value * widget.frames.length).floor()).clamp(0, widget.frames.length - 1);
    if (i != _index) setState(() => _index = i);
  }

  @override
  void didUpdateWidget(covariant PetLivingArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.excited != widget.excited) {
      _ctrl.duration = _cycle;
    }
    if (oldWidget.frames != widget.frames) {
      _index = 0;
      if (widget.frames.length > 1) {
        _ctrl.duration = _cycle;
        if (!_ctrl.isAnimating) _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Widget art;
    if (widget.frames.isEmpty) {
      final path = widget.fallbackAsset;
      art = path != null
          ? Image.asset(path,
              height: widget.height, fit: widget.fit, gaplessPlayback: true)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Icon(Icons.pets, size: 64, color: cs.primary),
            );
    } else {
      art = Image.asset(
        widget.frames[_index],
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true, // 帧切换不闪断
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: art,
    );
  }
}
