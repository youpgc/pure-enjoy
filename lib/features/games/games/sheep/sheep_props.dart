import 'package:flutter/material.dart';

/// 羊了个羊道具（每局各可用一次）
enum SheepProp {
  /// 移出：把槽位中最先的 3 块移出场，腾出槽位
  remove,

  /// 撤回：撤销上一步放置
  undo,

  /// 洗牌：重排棋盘剩余方块的类型
  shuffle,
}

extension SheepPropMeta on SheepProp {
  String get label {
    switch (this) {
      case SheepProp.remove:
        return '移出';
      case SheepProp.undo:
        return '撤回';
      case SheepProp.shuffle:
        return '洗牌';
    }
  }

  IconData get icon {
    switch (this) {
      case SheepProp.remove:
        return Icons.outbox_outlined;
      case SheepProp.undo:
        return Icons.undo;
      case SheepProp.shuffle:
        return Icons.shuffle;
    }
  }
}

/// 道具类型映射：把 `game_items.item_type` 字符串映射到 [SheepProp]，
/// 未知类型返回 null（对应「需购买道具卡」等不在三道具内的项）。
SheepProp? sheepPropFromType(String type) {
  switch (type) {
    case 'remove':
      return SheepProp.remove;
    case 'undo':
      return SheepProp.undo;
    case 'shuffle':
      return SheepProp.shuffle;
    default:
      return null;
  }
}

// 说明：原 SheepPropBar（叠在牌堆上方的道具栏）已移除 —— 道具按钮统一由
// GameShell 的底部控制栏渲染（按钮与游戏视图分离），避免遮挡盘面。

/// 使用道具前的确认弹窗：免费次数与购买库存均先确认，避免误触消耗。
///
/// 返回 `true` 表示用户确认使用；`false` / `null` 表示取消。
/// [free] / [owned] 分别为本局剩余免费次数与购买库存（用于文案展示）。
Future<bool?> confirmUsePropDialog(
  BuildContext context,
  SheepProp p,
  int free,
  int owned,
) async {
  final useFree = free > 0;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('使用${p.label}？'),
      content: Text(
        useFree
            ? '确定要使用「${p.label}」吗？将消耗 1 次免费次数（剩余 $free 次），使用后不可撤销。'
            : '确定要使用「${p.label}」吗？将消耗 1 张道具卡（库存剩余 $owned 张），使用后不可撤销。',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确定使用'),
        ),
      ],
    ),
  );
}
