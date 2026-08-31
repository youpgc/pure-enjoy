import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';

/// 底部控制栏的一个操作项。
class GameAction {
  /// 图标
  final IconData icon;

  /// 文案
  final String label;

  /// 角标（如道具剩余次数）；为 null 不显示
  final String? badge;

  /// 角标下方的小标签（如「免2」表示剩余免费次数）；为 null 不显示
  final String? extraTag;

  /// 点击回调；为 null 表示禁用
  final VoidCallback? onPressed;

  /// 是否使用强调样式（主操作，如「新游戏」「重新开始」）
  final bool primary;

  const GameAction({
    required this.icon,
    required this.label,
    this.badge,
    this.extraTag,
    this.onPressed,
    this.primary = false,
  });
}

/// 游戏页统一外壳：**顶部信息条 / 中间游戏视图 / 底部控制栏** 三段完全分离。
///
/// 设计约束（需求硬性要求）：
/// - 游戏视图独占中间容器，其上**不叠加任何按钮或信息**，避免遮挡盘面。
/// - 所有内置按钮统一收纳到底部 [actions] 控制栏，与游戏内容不在同一容器。
/// - 成绩记录入口不在此处，统一放在页面 AppBar 右上角（见 buildGameAppBar）。
class GameShell extends StatelessWidget {
  /// 顶部信息项（得分 / 目标 / 剩余步数 等），横向排布，不覆盖游戏视图
  final List<Widget> statusItems;

  /// 状态条下方的横幅（如 Boss 血条 / 目标进度条），同样不覆盖游戏视图
  final Widget? banner;

  /// 游戏视图（独立容器）
  final Widget content;

  /// 底部控制栏操作（游戏内置按钮统一放这里）
  final List<GameAction> actions;

  /// 底部操作提示文案（如「滑动合并相同数字」）
  final String? hint;

  const GameShell({
    super.key,
    required this.content,
    this.statusItems = const <Widget>[],
    this.banner,
    this.actions = const <GameAction>[],
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (statusItems.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: statusItems
                  .map((w) => Flexible(child: Center(child: w)))
                  .toList(),
            ),
          ),
        // 游戏视图：独立容器，内部不含任何按钮
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: content,
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.neutral600),
            ),
          ),
        if (actions.isNotEmpty) _ControlBar(actions: actions),
      ],
    );
  }
}

/// 底部统一控制栏（与游戏视图分离的独立容器）
class _ControlBar extends StatelessWidget {
  final List<GameAction> actions;

  const _ControlBar({required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: actions.map((a) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: a.primary
                    ? FilledButton(
                        onPressed: a.onPressed,
                        child: _ActionLabel(action: a),
                      )
                    : FilledButton.tonal(
                        onPressed: a.onPressed,
                        child: _ActionLabel(action: a),
                      ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  final GameAction action;

  const _ActionLabel({required this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(action.icon, size: 20),
        const SizedBox(height: 2),
        Text(
          action.badge == null
              ? action.label
              : '${action.label} ×${action.badge}',
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (action.extraTag != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              action.extraTag!,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.success,
              ),
              maxLines: 1,
            ),
          ),
      ],
    );
  }
}

/// 顶部信息小卡（统一样式：标题 + 数值，数值变化带切换动画）
class GameStatusItem extends StatelessWidget {
  final String label;
  final String value;

  /// 数值强调色（如剩余步数告急时标红）
  final Color? valueColor;

  const GameStatusItem({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.neutral600),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            value,
            key: ValueKey<String>(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              // 未指定强调色时跟随主题前景色，保证深色主题下可读
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
