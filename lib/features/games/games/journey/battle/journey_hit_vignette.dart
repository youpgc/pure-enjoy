import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';
import 'journey_battle_controller.dart';

/// 受击提醒：玩家每次有效受击时，屏幕边缘泛起一次红色呼吸光晕。
/// 中心保持透明，且不拦截摇杆、按钮等任何输入。
class JourneyHitVignette extends StatefulWidget {
  const JourneyHitVignette({super.key, required this.controller});

  final JourneyBattleController controller;

  @override
  State<JourneyHitVignette> createState() => _JourneyHitVignetteState();
}

class _JourneyHitVignetteState extends State<JourneyHitVignette>
    with SingleTickerProviderStateMixin {
  static const Duration _pulseDuration = Duration(milliseconds: 700);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );
  int _lastPulse = 0;

  @override
  void initState() {
    super.initState();
    _lastPulse = widget.controller.hud.hitPulse.value;
    widget.controller.hud.hitPulse.addListener(_onHit);
  }

  void _onHit() {
    final pulse = widget.controller.hud.hitPulse.value;
    if (pulse == _lastPulse || !mounted) return;
    _lastPulse = pulse;
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.hud.hitPulse.removeListener(_onHit);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          // 单峰呼吸：一次受击对应一次 0→峰值→0 的泛红
          final breath = math.sin(_anim.value * math.pi);
          if (breath <= 0.001) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                stops: const <double>[0.55, 0.82, 1.0],
                colors: <Color>[
                  Colors.transparent,
                  JourneyTheme.danger.withValues(alpha: 0.18 * breath),
                  JourneyTheme.danger.withValues(alpha: 0.62 * breath),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
