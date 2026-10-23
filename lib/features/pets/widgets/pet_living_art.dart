import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../constants/pet_bend.dart';
import '../../../constants/pet_render.dart';
import '../utils/pet_action_machine.dart';
import 'pet_bend_art.dart';

/// 父约束无界时的宠物显示基准边长（仅用于推算占位尺寸）
const double _kFallbackArtSize = 320;

/// 2D 宠物生命体（分层弯曲 + 骨架占位）
///
/// 2026-10 表现定版：整条演出由 [PetBendArt] 承担——被弯曲的是图像内部的
/// 一行行像素（归零线以下真·不动），编排读 `kPetBendActs`（用户已验收冻结）。
/// 本组件只做三件事：
/// - 给了 [bendGeo] 且该动作在 `kPetBendActs` 有编排 → 全权委托 [PetBendArt]；
/// - 一次性动作播完按 [PetActionMachine.durationOf] 计时回调 [onActionEnd]，
///   宿主据此把动作回落到环境态；
/// - 缺几何 / 缺编排（未登记形态或新动作没进表）→ 画骨架占位剪影
///   （铁律 8：配置缺码一律不崩溃，素材落位后同路径自动换回真图）。
///
/// 着色器本身不可用时的退化由 `PetBendArt` 内部承担，同样不会让宠物消失。
///
/// 静默闸门：画面演的是 [PetAction.played]（`kPetActionsSilenced` 里登记的
/// 动作改播 idle），计时/回落/粒子/音效仍按动作本体走——所以喂完食
/// 依然是「宠物呼吸 5 秒后回到待机」，只是不再演那套姿态。
class PetLivingArt extends StatefulWidget {
  const PetLivingArt({
    super.key,
    this.action = PetAction.idle,
    this.onActionEnd,
    this.bendGeo,
    this.bendRevealDir,
  });

  /// 当前动作（环境态循环播放，一次性动作播完回调 [onActionEnd]）
  final PetAction action;

  /// 一次性动作播完通知；宿主据此把动作回落到环境态
  final ValueChanged<PetAction>? onActionEnd;

  /// 分层弯曲几何（`petBendGeo` 解析）；null = 该形态无弯曲素材，画骨架占位
  final PetBendGeo? bendGeo;

  /// 进化末段替换的目标阶目录（`petBendRevealDir` 解析）
  final String? bendRevealDir;

  @override
  State<PetLivingArt> createState() => _PetLivingArtState();
}

class _PetLivingArtState extends State<PetLivingArt>
    with TickerProviderStateMixin {
  /// 占位呼吸时钟（仅在骨架占位路径常驻 repeat）
  late final AnimationController _clock;

  Timer? _endTimer;
  PetAction _playing = PetAction.idle;

  /// 画面实际演出的动作：静默闸门（`kPetActionsSilenced`）改播 idle。
  /// [PetAction] 本体仍按真动作计时与回落，粒子/音效不受这张表支配。
  PetAction get _visual => _playing.played;

  static Duration _duration(PetAction action) =>
      PetActionMachine.durationOf(action);

  /// 当前动作的分层弯曲编排；null = 无编排（未登记形态或表里没登记），占位兜底
  PetActDef? get _bendAct =>
      widget.bendGeo == null ? null : kPetBendActs[_visual.code];

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _playing = widget.action;
    _applyPlayMode();
  }

  /// 弯曲路径只保留一次性动作的回落计时；占位路径让呼吸时钟常驻
  void _applyPlayMode() {
    _endTimer?.cancel();
    if (_bendAct != null) {
      // 逐帧姿态由 PetBendArt 自己的时钟承担，本文件的控制器不参与画面
      //（留着跑会白刷一层 AnimatedBuilder）
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
    if (_playing.ambient) return;
    _endTimer = Timer(_duration(_playing), () {
      if (mounted) widget.onActionEnd?.call(_playing);
    });
  }

  @override
  void didUpdateWidget(covariant PetLivingArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action ||
        oldWidget.bendGeo != widget.bendGeo) {
      // 换形态也要重算播放模式（弯曲↔占位之间可能切换，时钟不能留在旧状态）
      _playing = widget.action;
      _applyPlayMode();
    }
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final geo = widget.bendGeo;
    final act = _bendAct;
    if (geo != null && act != null) {
      return PetBendArt(
        geo: geo,
        act: act,
        revealDir: widget.bendRevealDir,
        primaryColor: cs.primary,
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final box = constraints.biggest;
      // 基准边长：无父约束时回退 320（弹窗/列表缩略图等 loose 场景）
      final ref = box.width.isFinite && box.height.isFinite
          ? math.min(box.width, box.height)
          : _kFallbackArtSize;
      return _SkeletonPlaceholder(ref: ref, clock: _clock);
    });
  }
}

/// 素材未产出形态的骨架占位：四足动物剪影（头+双耳+身+尾），
/// 剪影内一道斜向亮带随环境态时钟往复扫动（骨架屏 shimmer 蒙层）。
/// 语义 = 「这里会有一只，素材还在路上」；真图就位后本占位自动隐退。
class _SkeletonPlaceholder extends StatelessWidget {
  const _SkeletonPlaceholder({required this.ref, required this.clock});

  /// 基准边长（与真图同源，占位尺寸随舞台缩放）
  final double ref;

  /// 环境态时钟：驱动呼吸明暗与扫光相位
  final Animation<double> clock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, _) {
          final t = clock.value;
          final breathe = 0.5 - 0.5 * math.sin(2 * math.pi * t);
          return SizedBox(
            width: ref * 0.62,
            height: ref * 0.46,
            child: CustomPaint(
              painter: _PetSkeletonPainter(
                base: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                shimmer: (cs.primary.withValues(alpha: 0.30))
                    .withValues(alpha: 0.12 + 0.22 * breathe),
                phase: t,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 通用宠物骨架画笔（剪影 = 身/头/双耳/前后腿/尾 + 相位扫光）。
/// 舞台缺素材占位专用（图鉴「未获取」曾复用后改为锁定徽章样式）。
/// 静态用法传固定 phase（0~1，0.25 = 扫光居中）。
class _PetSkeletonPainter extends CustomPainter {
  _PetSkeletonPainter({
    required this.base,
    required this.shimmer,
    required this.phase,
  });

  final Color base;
  final Color shimmer;

  /// 扫光相位（0~1 往复）
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 剪影 = 身（椭圆）+ 头（圆）+ 双耳（三角）+ 前后腿（圆角短柱）+ 尾（弧线）
    final path = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.56, h * 0.62), width: w * 0.64, height: h * 0.5))
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.25, h * 0.34), width: w * 0.36, height: h * 0.36))
      ..moveTo(w * 0.13, h * 0.26)
      ..lineTo(w * 0.19, h * 0.05)
      ..lineTo(w * 0.28, h * 0.20)
      ..close()
      ..moveTo(w * 0.30, h * 0.20)
      ..lineTo(w * 0.38, h * 0.03)
      ..lineTo(w * 0.43, h * 0.23)
      ..close();
    final fill = Paint()
      ..color = base
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
    final leg = Paint()
      ..color = base
      ..strokeWidth = h * 0.085
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.42, h * 0.78), Offset(w * 0.42, h * 0.96), leg);
    canvas.drawLine(Offset(w * 0.70, h * 0.78), Offset(w * 0.70, h * 0.96), leg);
    final tail = Path()
      ..moveTo(w * 0.86, h * 0.60)
      ..quadraticBezierTo(w * 1.02, h * 0.48, w * 0.90, h * 0.26);
    canvas.drawPath(
        tail,
        Paint()
          ..color = base
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.055
          ..strokeCap = StrokeCap.round);
    // 扫光蒙层：斜向亮带按 phase 在 [-0.3w, 1.3w] 区间往复，裁剪进剪影
    canvas.save();
    canvas.clipPath(path);
    final sweep = (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
    final x = -w * 0.3 + w * 1.6 * sweep;
    canvas.drawRect(Rect.fromLTWH(x, 0, w * 0.24, h), Paint()..color = shimmer);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PetSkeletonPainter old) =>
      old.phase != phase || old.base != base || old.shimmer != shimmer;
}
