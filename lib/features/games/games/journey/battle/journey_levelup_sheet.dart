import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';
import 'journey_battle_controller.dart';

/// 局内升级三选一弹窗（卡牌式，金色品质光效）。
class JourneyLevelUpSheet extends StatelessWidget {
  const JourneyLevelUpSheet({
    super.key,
    required this.level,
    required this.choices,
    required this.onPick,
  });

  final int level;
  final List<JourneyUpgradeChoice> choices;
  final ValueChanged<JourneyUpgradeChoice> onPick;

  static Future<void> show(
    BuildContext context, {
    required int level,
    required List<JourneyUpgradeChoice> choices,
    required ValueChanged<JourneyUpgradeChoice> onPick,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      // 拦截系统返回键关闭弹窗（must pick）：返回键路径走 doNotPop 不触
      // Navigator 过渡断言；选卡按钮的命令式 pop 不受 PopScope 影响
      builder: (_) => PopScope(
        canPop: false,
        child: JourneyLevelUpSheet(
          level: level,
          choices: choices,
          onPick: onPick,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JourneyTheme.bgDeep.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(JourneyTheme.radiusPanel),
          border: Border.all(color: JourneyTheme.gold, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('第 $level 层 · 神通三选一',
                style: JourneyTheme.titleLg.copyWith(
                    color: JourneyTheme.gold)),
            const SizedBox(height: 12),
            Row(
              children: choices
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _ChoiceCard(
                            choice: c,
                            onPick: () {
                              Navigator.of(context).pop();
                              onPick(c);
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final JourneyUpgradeChoice choice;
  final VoidCallback onPick;

  const _ChoiceCard({required this.choice, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: JourneyTheme.panel,
            borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
            border: Border.all(color: JourneyTheme.goldDeep, width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: JourneyTheme.gold.withValues(alpha: 0.18),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.auto_awesome,
                  color: JourneyTheme.gold, size: 24),
              const SizedBox(height: 8),
              Text(
                choice.title,
                style: JourneyTheme.title.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                choice.desc,
                style: JourneyTheme.faint,
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
