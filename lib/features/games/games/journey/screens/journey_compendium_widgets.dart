import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';

/// 图鉴分类页签：选中态高亮，点击交由页面切换当前分类，供多分类聚合布局复用。
class JourneyCompendiumTabChip extends StatelessWidget {
  const JourneyCompendiumTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? JourneyTheme.gold.withValues(alpha: 0.18)
                  : JourneyTheme.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? JourneyTheme.gold : JourneyTheme.panelStroke,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? JourneyTheme.goldSoft
                    : JourneyTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 图鉴解锁图标：可解锁显示金色锁并可点触发解锁，条件未达成显示灰色锁，
/// 已解锁不展示任何图标。两个图鉴共用同一交互口径。
class JourneyUnlockLock extends StatelessWidget {
  const JourneyUnlockLock({
    super.key,
    required this.unlocked,
    required this.unlockable,
    required this.onTap,
  });

  final bool unlocked;
  final bool unlockable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (unlocked) return const SizedBox.shrink();
    return GestureDetector(
      onTap: unlockable ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Icon(
          Icons.lock,
          size: 20,
          color: unlockable ? JourneyTheme.gold : JourneyTheme.locked,
        ),
      ),
    );
  }
}

/// 已入池角标（已解锁或无 relic 配置的法宝）。
class JourneyPoolBadge extends StatelessWidget {
  const JourneyPoolBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: JourneyTheme.gold, width: 1),
      ),
      child: const Text(
        '已入池',
        style: TextStyle(fontSize: 10, color: JourneyTheme.goldSoft),
      ),
    );
  }
}
