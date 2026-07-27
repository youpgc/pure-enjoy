import 'package:flutter/material.dart';
import '../models/novel_model.dart';

/// 聚合来源标注徽标（合规：明确内容来源，避免冒充自有内容）。
///
/// 仅对聚合小说（[NovelModel.isAggregated]）展示。普通书库小说返回空。
class NovelSourceBadge extends StatelessWidget {
  final NovelModel novel;

  /// 紧凑模式：仅显示图标 + 来源名（用于卡片封面角标）
  final bool compact;

  /// 是否在名称后追加「跳转原平台阅读」提示
  final bool showJumpHint;

  const NovelSourceBadge({
    super.key,
    required this.novel,
    this.compact = false,
    this.showJumpHint = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!novel.isAggregated) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bg = theme.colorScheme.secondaryContainer;
    final fg = theme.colorScheme.onSecondaryContainer;

    final label = compact
        ? novel.sourceDisplayName
        : '来源：${novel.sourceDisplayName}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_new, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: fg),
          ),
          if (!compact && showJumpHint) ...[
            const SizedBox(width: 4),
            Text('· 跳转原平台阅读', style: TextStyle(fontSize: 11, color: fg)),
          ],
        ],
      ),
    );
  }
}
