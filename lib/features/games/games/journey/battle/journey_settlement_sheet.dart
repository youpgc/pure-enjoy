import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import 'journey_battle_controller.dart';

/// 西行·对局结算弹窗（功德单明细：铜钱拾取+通关奖励，复用卡牌语言）。
class JourneySettlementSheet extends StatelessWidget {
  const JourneySettlementSheet({
    super.key,
    required this.result,
    required this.meritGranted,
    required this.firstClear,
    required this.onRetry,
    required this.onExit,
  });

  final JourneyRunResult result;
  final int meritGranted;
  final bool firstClear;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  static Future<void> show(
    BuildContext context, {
    required JourneyRunResult result,
    required int meritGranted,
    required bool firstClear,
    required VoidCallback onRetry,
    required VoidCallback onExit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      // 拦截系统返回键关闭弹窗（must choose button）：返回键路径走 doNotPop
      // 不触 Navigator 过渡断言；出口按钮的命令式 pop 不受 PopScope 影响
      builder: (_) => PopScope(
        canPop: false,
        child: JourneySettlementSheet(
          result: result,
          meritGranted: meritGranted,
          firstClear: firstClear,
          onRetry: onRetry,
          onExit: onExit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleared = result.cleared;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: JourneyTheme.bgDeep.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(JourneyTheme.radiusPanel),
          border: Border.all(
            color: cleared ? JourneyTheme.gold : JourneyTheme.danger,
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Text(
                cleared ? '功德圆满' : '此难未过',
                style: JourneyTheme.titleLg.copyWith(
                  color: cleared ? JourneyTheme.gold : JourneyTheme.danger,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '第 ${result.levelNo} 难 · ${result.levelTitle}',
                style: JourneyTheme.caption,
              ),
            ),
            const SizedBox(height: 14),
            JourneyPanel(
              child: Column(
                children: <Widget>[
                  _row('击杀妖怪', '${result.kills}'),
                  _row('功德铜钱', '+${result.meritFromCoins}'),
                  _row('通关奖励', '+${result.meritClearBonus}'),
                  if (firstClear)
                    _row('首通天赋点', '+1'),
                  const Divider(color: JourneyTheme.panelStroke, height: 18),
                  _row(
                    '实际入账功德',
                    '+$meritGranted',
                    highlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: JourneyButton(
                    text: '再战此难',
                    secondary: true,
                    onTap: onRetry,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: JourneyButton(
                    text: cleared ? '继续西行' : '返回',
                    onTap: onExit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: JourneyTheme.body)),
          Text(
            value,
            style: highlight
                ? JourneyTheme.title.copyWith(color: JourneyTheme.gold)
                : JourneyTheme.body,
          ),
        ],
      ),
    );
  }
}
