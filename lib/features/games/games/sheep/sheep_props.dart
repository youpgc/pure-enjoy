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

/// 道具栏：展示三道具及剩余次数，点击使用。
class SheepPropBar extends StatelessWidget {
  final Map<SheepProp, int> remaining;
  final void Function(SheepProp) onUse;

  const SheepPropBar({
    super.key,
    required this.remaining,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: SheepProp.values.map((p) {
          final n = remaining[p] ?? 0;
          final enabled = n > 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.tonal(
                onPressed: enabled ? () => onUse(p) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(p.icon, size: 20),
                    const SizedBox(height: 2),
                    Text(n > 0 ? '${p.label} ×$n' : p.label,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
