import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';
import 'journey_battle_controller.dart';

/// 局内升级三选一弹窗（全宽竖排卡牌，金色品质光效）。
///
/// 竖排全宽而非三列横排：真机窄屏下每列仅 ~100dp，长文案必然截断；
/// 全宽卡文案区 ~270dp，标题与描述不限行完整展示。
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
          // 弹窗内容（竖排三卡）在矮屏×窄屏组合下可能越过 bottom sheet
          // 默认上限（屏高×9/16，isScrollControlled:false），滚动兜底防溢出
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('第 $level 层 · 神通三选一',
                    style: JourneyTheme.titleLg.copyWith(
                        color: JourneyTheme.gold)),
                const SizedBox(height: 12),
                for (var i = 0; i < choices.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 8),
                  _ChoiceCard(
                    choice: choices[i],
                    onPick: () {
                      Navigator.of(context).pop();
                      onPick(choices[i]);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final JourneyUpgradeChoice choice;
  final VoidCallback onPick;

  const _ChoiceCard({required this.choice, required this.onPick});

  /// 类型 → 图标：习得/顿悟 ✦、被动 盾、触发 ⚡、攻击 火、移速 风、
  /// 生命 心、回复 十、磁引 罗盘；一眼区分成长类别。
  static IconData _iconOf(JourneyUpgradeKind kind) => switch (kind) {
        JourneyUpgradeKind.slotLearn ||
        JourneyUpgradeKind.slotUpgrade =>
          Icons.auto_awesome,
        JourneyUpgradeKind.passiveGrant => Icons.shield,
        JourneyUpgradeKind.effectGrant => Icons.bolt,
        JourneyUpgradeKind.attack => Icons.local_fire_department,
        JourneyUpgradeKind.moveSpeed => Icons.air,
        JourneyUpgradeKind.maxHp => Icons.favorite,
        JourneyUpgradeKind.regen => Icons.healing,
        JourneyUpgradeKind.pickupRange => Icons.explore,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(12),
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
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: JourneyTheme.bgBase,
                  border: Border.all(
                      color: JourneyTheme.gold.withValues(alpha: 0.85),
                      width: 1.2),
                ),
                child: Icon(_iconOf(choice.kind),
                    color: JourneyTheme.gold, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      choice.title,
                      style: JourneyTheme.title.copyWith(fontSize: 15),
                    ),
                    Text(
                      choice.desc,
                      style: JourneyTheme.faint,
                      // 不限行数：描述完整展示（竖排全宽卡空间充足）
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: JourneyTheme.gold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
