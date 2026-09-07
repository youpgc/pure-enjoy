import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';

import '../../models/match3_mode.dart';
import 'candy_component.dart';
import 'match3_objective.dart';

/// 目标达成条件横幅（游戏容器内上方）：`图标 ×N` 文案居中，
/// 多个要求并排居中、间距 8px，随消除进度实时减少（2026-09-07 拍板）。
///
/// - collect 模式：每个颜色目标一枚「色块图标 ×剩余」
/// - obstacle 模式：冰块一枚（❄ ×剩余冰块）+ 附加颜色目标（若有）
///
/// 由 Match3Game 的 hudTick 驱动重建，无需自有状态。
class Match3GoalBanner extends StatelessWidget {
  final Match3Objective objective;

  const Match3GoalBanner({super.key, required this.objective});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (objective.mode == Match3Mode.obstacle) {
      chips.add(_chip(
        icon: Icon(Icons.ac_unit,
            size: 16, color: Colors.lightBlueAccent.shade100),
        remaining: objective.iceLeft,
        done: objective.iceLeft == 0,
      ));
    }
    for (final g in objective.collectGoals) {
      final color =
          kCandyColors[g.type.clamp(0, kCandyColors.length - 1)];
      chips.add(_chip(
        icon: _candyDot(color),
        remaining: g.remaining,
        done: g.done,
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8, // 多个要求中间间距 8px
          runSpacing: 4,
          children: chips,
        ),
      ),
    );
  }

  /// 单个目标 chip：图标 + ×剩余（达成后打勾置灰）
  Widget _chip({
    required Widget icon,
    required int remaining,
    required bool done,
  }) {
    final fg = done ? AppTheme.success : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done
            ? AppTheme.success.withAlpha(26)
            : AppTheme.neutral500.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          icon,
          const SizedBox(width: 4),
          Text(
            done ? '✓' : '×$remaining',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: done ? AppTheme.success : fg,
            ),
          ),
        ],
      ),
    );
  }

  /// 糖果色块图标（与引擎绘制同源色板）
  Widget _candyDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }
}
