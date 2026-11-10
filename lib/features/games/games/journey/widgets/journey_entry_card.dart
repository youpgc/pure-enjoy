import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';

/// hub 入口卡（图标 + 文案 + 点击），入口行统一视觉。
class JourneyEntryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const JourneyEntryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: JourneyTheme.panelDecoration(),
          child: Column(
            children: <Widget>[
              Icon(icon, color: JourneyTheme.gold, size: 18),
              const SizedBox(height: 4),
              Text(label, style: JourneyTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}
