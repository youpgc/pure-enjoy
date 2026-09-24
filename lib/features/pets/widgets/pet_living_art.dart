import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../constants/pet_render.dart';
import '../utils/pet_action_machine.dart';
import '../utils/pet_art_resolver.dart';

/// 父约束无界时的宠物显示基准边长（仅用于推算解码宽度与光晕尺寸）
const double _kFallbackArtSize = 320;

/// 2D 宠物生命体（帧序列 + 程序补间姿态 + 进化辉光）
///
/// 2026-09-24 表现层降维定版：3D 一期下线后，宠物「活起来」改由 2D 实现。
/// 纯帧序列在经济性上不成立（8 动作 × 6 帧 × 930KB ≈ 44MB/形态，且 1024²
/// RGBA 解码常驻 4MB/帧，64 帧就超过 Flutter 默认 100MB 图片缓存），故走混合
/// 路线：
/// - 帧序列：只有 [frames]（idle 眨眼/尾摆）这一种真帧素材，动作期间继续轮播；
/// - 程序补间：eat/petted/happy/sad/sleep/walk/evolve 全部由同一张图的位移、
///   旋转、压扁拉伸编排而成（见 `_pose`），零额外素材；
/// - 进化辉光：evolve 期间叠加径向白光，与粒子层 pet_fx_overlay 共同承担演出。
///
/// 与旧版差别：旧版只有一个 `excited` 布尔位（把帧率 3.5fps 提到 8fps），现在
/// 由 [action] 驱动完整姿态编排；[onActionEnd] 供宿主把动作回落到环境态。
class PetLivingArt extends StatefulWidget {
  const PetLivingArt({
    super.key,
    required this.frames,
    this.fallbackAsset,
    this.height,
    this.fit = BoxFit.contain,
    this.action = PetAction.idle,
    this.onActionEnd,
  });

  /// 真帧序列（`petStageFrames` 解析：该动作有真帧用它，否则沿用 idle 帧）；
  /// 空 = 无帧素材，走单图 + 补间
  final List<String> frames;

  /// 无帧序列时的单帧立绘回退
  final String? fallbackAsset;

  /// 可选固定高度；不传时按父约束 fit 撑满（满屏舞台用）
  final double? height;
  final BoxFit fit;

  /// 当前动作（环境态循环播放，一次性动作播完回调 [onActionEnd]）
  final PetAction action;

  /// 一次性动作播完通知；宿主据此把动作回落到环境态
  final ValueChanged<PetAction>? onActionEnd;

  @override
  State<PetLivingArt> createState() => _PetLivingArtState();
}

class _PetLivingArtState extends State<PetLivingArt>
    with TickerProviderStateMixin {
  /// 帧轮播时钟（常驻 repeat，只在有帧序列时驱动画面）
  late final AnimationController _frame;

  /// 动作姿态时钟（环境态 repeat，一次性动作 forward 一次）
  late final AnimationController _perf;

  Timer? _endTimer;
  PetAction _playing = PetAction.idle;

  /// 帧轮播一圈时长：待机 ~3.5fps，动作期间提速到 ~8fps
  Duration get _frameCycle {
    final fps = _playing.ambient ? 3.5 : 8.0;
    final perFrame = (1000 / fps).round();
    return Duration(milliseconds: perFrame * math.max(1, widget.frames.length));
  }

  static Duration _duration(PetAction action) =>
      PetActionMachine.durationOf(action);

  @override
  void initState() {
    super.initState();
    _frame = AnimationController(vsync: this, duration: _frameCycle);
    _syncFrameClock();
    _playing = widget.action;
    _perf = AnimationController(vsync: this, duration: _duration(_playing));
    _applyPlayMode();
  }

  /// 帧轮播时钟只在多帧素材时才跑（单图/无图不需要逐帧刷新）
  void _syncFrameClock() {
    if (widget.frames.length > 1) {
      if (!_frame.isAnimating) _frame.repeat();
    } else {
      _frame.stop();
    }
  }

  /// 环境态循环播放；一次性动作播完计时回调宿主回落
  void _applyPlayMode() {
    // 动作期间帧率提速到 ~8fps，环境态回落到 ~3.5fps
    _frame.duration = _frameCycle;
    _syncFrameClock();
    _perf.duration = _duration(_playing);
    if (_playing.ambient) {
      if (!_perf.isAnimating) _perf.repeat();
      return;
    }
    _perf.forward(from: 0);
    _endTimer?.cancel();
    _endTimer = Timer(_duration(_playing), () {
      if (mounted) widget.onActionEnd?.call(_playing);
    });
  }

  @override
  void didUpdateWidget(covariant PetLivingArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _syncFrameClock();
    }
    if (oldWidget.action != widget.action) {
      _playing = widget.action;
      _applyPlayMode();
    }
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    _frame.dispose();
    _perf.dispose();
    super.dispose();
  }

  int get _frameIndex {
    final n = widget.frames.length;
    if (n <= 1) return 0;
    return (_frame.value * n).floor().clamp(0, n - 1);
  }

  /// 姿态编排：所有动作共用一张图，靠位移/旋转/压扁拉伸区分（零额外素材）
  _Pose _pose() {
    final t = _perf.value;
    final wave = math.sin(2 * math.pi * t);
    switch (_playing) {
      case PetAction.petted:
        final sway = math.sin(4 * math.pi * t);
        return _Pose(
            dx: 5.5 * sway, rotate: 0.08 * sway, sy: 1 + 0.025 * sway.abs());
      case PetAction.eat:
        final dip = 0.5 - 0.5 * math.cos(4 * math.pi * t);
        return _Pose(
            dy: 9 * dip,
            rotate: 0.055 * math.sin(4 * math.pi * t),
            sy: 1 - 0.025 * dip);
      case PetAction.happy:
        // 4t(1-t) 抛物线跳起；起跳与落地前后各 14% 时长做压扁
        final hop = 26 * (4 * t * (1 - t));
        final squash = math.max(0.0, 1 - math.min(t, 1 - t) / 0.14);
        return _Pose(dy: -hop, sy: 1 - 0.07 * squash, sx: 1 + 0.07 * squash);
      case PetAction.sad:
        return _Pose(
            dy: 5 + 2.4 * wave, rotate: 0.10, sy: 1 - 0.022 + 0.010 * wave);
      case PetAction.sleep:
        return _Pose(dy: 3, rotate: 0.13, sy: 1 + 0.038 * wave);
      case PetAction.walk:
        return _Pose(
            dx: 32 * wave,
            dy: -3.5 * math.sin(4 * math.pi * t).abs(),
            rotate: 0.05 * math.sin(4 * math.pi * t));
      case PetAction.evolve:
        final pulse = math.sin(math.pi * t);
        return _Pose(
            dy: -6 * pulse,
            rotate: 0.05 * math.sin(10 * math.pi * t) * pulse,
            sx: 1 + 0.20 * pulse,
            sy: 1 + 0.20 * pulse);
      case PetAction.idle:
        return _Pose(dy: -1.8 * wave, sy: 1 + 0.012 * wave);
    }
  }

  /// 进化辉光：径向白→主色→透明的正方形光晕，随 pulse 淡入淡出
  Widget _glow(ColorScheme cs, double g, double dimension) {
    return Center(
      child: SizedBox.square(
        dimension: dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              stops: const [0.0, 0.45, 0.85],
              colors: [
                Colors.white.withValues(alpha: 0.75 * g),
                cs.primary.withValues(alpha: 0.25 * g),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final box = constraints.biggest;
      // 基准边长：无父约束时回退 320（弹窗/列表缩略图等 loose 场景）
      final ref = widget.height ??
          (box.width.isFinite && box.height.isFinite
              ? math.min(box.width, box.height)
              : _kFallbackArtSize);
      final cacheWidth =
          petDecodeWidth(ref, MediaQuery.devicePixelRatioOf(context));

      final path = widget.fallbackAsset;
      // 素材缺失/清单与包内文件脱节时画占位，不抛异常（铁律 8）
      final Widget placeholder = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Icon(Icons.pets, size: 64, color: cs.primary),
      );
      final Widget art = widget.frames.isNotEmpty
          ? Image.asset(widget.frames[_frameIndex],
              height: widget.height,
              fit: widget.fit,
              cacheWidth: cacheWidth,
              gaplessPlayback: true, // 帧切换不闪断
              errorBuilder: (context, error, stackTrace) => placeholder)
          : path != null
              ? Image.asset(path,
                  height: widget.height,
                  fit: widget.fit,
                  cacheWidth: cacheWidth,
                  errorBuilder: (context, error, stackTrace) => placeholder)
              : placeholder;

      return AnimatedBuilder(
        animation: Listenable.merge([_frame, _perf]),
        builder: (context, child) {
          final pose = _pose();
          final glow = _playing == PetAction.evolve
              ? math.sin(math.pi * _perf.value)
              : 0.0;
          return RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (glow > 0.01) _glow(cs, glow, ref * 1.7),
                Transform.translate(
                  offset: Offset(pose.dx, pose.dy),
                  // 等效 T·R·S：外层平移、中层绕底边中心旋转、内层压扁拉伸
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()..rotateZ(pose.rotate),
                    child: Transform.scale(
                      scaleX: pose.sx,
                      scaleY: pose.sy,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: art,
      );
    });
  }
}

/// 单帧姿态参数（相对底边中心做刚体变换）
class _Pose {
  const _Pose({
    this.dx = 0,
    this.dy = 0,
    this.rotate = 0,
    this.sx = 1,
    this.sy = 1,
  });

  final double dx;
  final double dy;

  /// 旋转弧度
  final double rotate;

  /// 横/纵向缩放（压扁拉伸）
  final double sx;
  final double sy;
}
