import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';

/// 图鉴页签：选中态高亮，点击交由页面切换当前页签。
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
