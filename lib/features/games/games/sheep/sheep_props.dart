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

// 说明：原 SheepPropBar（叠在牌堆上方的道具栏）已移除 —— 道具按钮统一由
// GameShell 的底部控制栏渲染（按钮与游戏视图分离），避免遮挡盘面。
