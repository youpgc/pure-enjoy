import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      // 定版动物头像图标（与盘面同源 SVG），替代旧色点——色点在深底上
      // 辨识度差且与新版图标脱节（2026-09-10 用户反馈「全是黑点」）
      chips.add(_chip(
        icon: _candyIcon(g.type),
        remaining: g.remaining,
        done: g.done,
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    // 与引擎盘面同底色（游戏容器深色区内上方，视觉一体化）
    return Container(
      width: double.infinity,
      color: const Color(0xFF26263A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  /// 糖果图标：定版动物头像 SVG（candy_<type>.svg，与盘面渲染同源）
  Widget _candyIcon(int type) {
    final t = type.clamp(0, 5);
    return SvgPicture.asset(
      'assets/games/match3/candy_$t.svg',
      width: 22,
      height: 22,
    );
  }
}
