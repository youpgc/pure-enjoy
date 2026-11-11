import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';

/// 右下角圆形控制钮共用几何：暂停与功成同尺寸，位置随摇杆区顶边上移。
abstract final class JourneyControlGeometry {
  static const double size = 56;
  static const double right = 16;
  static const double gap = 16;
  static const double step = 68;
}

/// 按屏高计算右下控制钮的 bottom：贴摇杆区顶边之上，并按顶部 HUD
/// 信息区下沿钳制，避免小屏与槽栏/妖王血条相撞。
(double pause, double settle) journeyControlBottoms({
  required double screenH,
  required double topInset,
  double hudBottomInset = 300,
}) {
  final maxBottom = screenH -
      topInset -
      hudBottomInset -
      JourneyControlGeometry.gap -
      JourneyControlGeometry.size -
      JourneyControlGeometry.step;
  final pause = math
      .min(screenH / 2 + JourneyControlGeometry.gap, maxBottom)
      .clamp(JourneyControlGeometry.size, screenH)
      .toDouble();
  return (pause, pause + JourneyControlGeometry.step);
}

class _JourneyRoundButton extends StatelessWidget {
  const _JourneyRoundButton({
    required this.onTap,
    required this.bottom,
    required this.primary,
    required this.child,
  });

  final VoidCallback onTap;
  final double bottom;
  final bool primary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: JourneyControlGeometry.right,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(JourneyControlGeometry.size / 2),
          child: Container(
            width: JourneyControlGeometry.size,
            height: JourneyControlGeometry.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: primary
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        JourneyTheme.goldSoft,
                        JourneyTheme.gold,
                      ],
                    )
                  : null,
              color: primary ? null : JourneyTheme.panelRaised,
              border: Border.all(
                color: primary ? JourneyTheme.goldDeep : JourneyTheme.gold,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 满足通关条件后亮出的主动结算按钮（暂停键正上方）。
class JourneySettleButton extends StatelessWidget {
  const JourneySettleButton({
    super.key,
    required this.onTap,
    required this.bottom,
  });

  final VoidCallback onTap;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return _JourneyRoundButton(
      onTap: onTap,
      bottom: bottom,
      primary: true,
      child: const Text(
        '功成',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3A2A12),
        ),
      ),
    );
  }
}

/// 暂停按钮：同款圆形底板配次级色，视觉体量与功成按钮一致。
class JourneyPauseButton extends StatelessWidget {
  const JourneyPauseButton({
    super.key,
    required this.onTap,
    required this.bottom,
  });

  final VoidCallback onTap;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return _JourneyRoundButton(
      onTap: onTap,
      bottom: bottom,
      primary: false,
      child: const Icon(Icons.pause, color: JourneyTheme.gold, size: 30),
    );
  }
}
