import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  /// 选中高亮态（如破坏锤待命中）：强调描边 + 高亮底色，提示玩家
  /// 「道具已选中，去盘面点击目标」（道具商城扩展，2026-09-09）。
  final bool selected;

  /// 图标资产文件名（game_items.icon 口子，2026-09-09）：非空时渲染
  /// `assets/games/items/<iconAsset>.svg` 定版图标，null 用内置 [icon]。
  final String? iconAsset;

  const GameAction({
    required this.icon,
    required this.label,
    this.badge,
    this.extraTag,
    this.onPressed,
    this.primary = false,
    this.selected = false,
    this.iconAsset,
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

  /// 游戏视图（独立容器）
  final Widget content;

  /// 底部控制栏操作（游戏内置按钮统一放这里）
  final List<GameAction> actions;

  /// 道具栏操作（渲染在 [actions] 上方的独立一行；道具商城扩展）。
  /// 与主控制栏分离：道具更常变动（解锁/库存），且视觉层级弱于主操作。
  final List<GameAction> propActions;

  /// 道具栏空态占位文案（2026-09-09）：[propActions] 为空时渲染固定高度
  /// 的占位行，防止布局因无道具而高度坍塌。传空字符串关闭占位。
  final String propPlaceholder;

  /// 底部操作提示文案（如「滑动合并相同数字」）
  final String? hint;

  const GameShell({
    super.key,
    required this.content,
    this.statusItems = const <Widget>[],
    this.actions = const <GameAction>[],
    this.propActions = const <GameAction>[],
    this.propPlaceholder = '当前对局无道具可用',
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
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint!,
              textAlign: TextAlign.center,
              // 通关条件单行展示：超宽时整体缩小而非换行（2026-09-10 简化文案）
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppTheme.neutral600),
            ),
          ),
        _PropBar(
          actions: propActions,
          placeholder: propActions.isEmpty ? propPlaceholder : null,
        ),
        if (actions.isNotEmpty) _ControlBar(actions: actions),
      ],
    );
  }
}

/// 道具栏（独立行，渲染于主控制栏上方；支持选中高亮态）
class _PropBar extends StatelessWidget {
  final List<GameAction> actions;

  /// 非空 = 空态占位（无道具），固定高度防布局坍塌。
  final String? placeholder;

  const _PropBar({required this.actions, this.placeholder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 2, 10, 0),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        height: 56,
        child: Center(
          child: placeholder != null
              ? Text(
                  placeholder!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Row(
                  children: actions.map((a) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _PropButton(action: a),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

/// 道具按钮：tonal 底 + 选中高亮描边（selected 时强调色边框 + 底色）
class _PropButton extends StatelessWidget {
  final GameAction action;

  const _PropButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = action.selected;
    final enabled = action.onPressed != null;
    final cs = theme.colorScheme;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.18)
            : cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? cs.primary : Colors.transparent,
            width: selected ? 2 : 0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: action.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _ActionLabel(action: action),
          ),
        ),
      ),
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
        // 压缩纵向内边距 + 上间距，降低「重新开始」等控制按钮整体高度占比
        margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                        style: FilledButton.styleFrom(
                          // 压低主控制按钮高度（2026-09-10：道具栏调高后主栏让出空间）
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _ActionLabel(action: a),
                      )
                    : FilledButton.tonal(
                        onPressed: a.onPressed,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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
    final Widget iconWidget = (action.iconAsset != null && action.iconAsset!.isNotEmpty)
        ? SvgPicture.asset(
            'assets/games/items/${action.iconAsset}.svg',
            width: 18,
            height: 18,
            // 资产缺失兜底：回退内置图标（后台 icon 配错文件名时防崩）
            errorBuilder: (_, __, ___) => Icon(action.icon, size: 16),
          )
        : Icon(action.icon, size: 16);
    // 角标信息合并为单行文字（「名称 ×3 免1」），避免多行导致 PropBar 纵向溢出
    var label = action.label;
    if (action.badge != null) label += ' ×${action.badge}';
    if (action.extraTag != null) label += ' ${action.extraTag}';
    return FittedBox(
      // 兜底：字体缩放/长文案超宽时等比缩小，杜绝 RenderFlex overflow
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          iconWidget,
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
              fontSize: 20,
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

/// 道具图标组件（2026-09-09 定版图标接入）：[iconAsset] 非空渲染
/// `assets/games/items/<iconAsset>.svg` 定版图标，空回退内置 [icon]。
/// 供确认弹窗、商城卡片等非 GameAction 场景复用，保证与道具栏图标一致。
class PropIcon extends StatelessWidget {
  final IconData icon;
  final String? iconAsset;
  final double size;

  const PropIcon({
    super.key,
    required this.icon,
    this.iconAsset,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (iconAsset != null && iconAsset!.isNotEmpty) {
      return SvgPicture.asset(
        'assets/games/items/$iconAsset.svg',
        width: size,
        height: size,
        // 资产缺失兜底：回退内置图标（后台 icon 配错文件名时防崩）
        errorBuilder: (_, __, ___) => Icon(icon, size: size),
      );
    }
    return Icon(icon, size: size);
  }
}

/// 道具类型 → 内置兜底图标（iconAsset 缺失时的统一兜底，与道具栏口径一致）。
IconData itemIconFor(String itemType) {
  switch (itemType) {
    case 'shuffle':
      return Icons.shuffle_outlined;
    case 'hammer':
      return Icons.construction_outlined;
    case 'hint':
      return Icons.lightbulb_outline;
    case 'force_swap':
      return Icons.swap_horiz_outlined;
    case 'magic_wand':
      return Icons.auto_fix_high_outlined;
    case 'add_steps':
      return Icons.exposure_plus_1;
    case 'add_time':
      return Icons.timer_outlined;
    case 'remove':
      return Icons.push_pin_outlined;
    case 'undo':
      return Icons.undo_outlined;
  }
  return Icons.extension_outlined;
}
