part of 'g2048_game.dart';

/// 2048 经典模式「棋盘选择」底部弹窗：尺寸 3×3 .. 8×8。
/// 返回选定尺寸；用户点「返回」取消时返回 null。
///
/// 从 g2048_game.dart 抽离（审查 P1 单文件超 500 行），仍属同一库，
/// 调用方 import g2048_game.dart 即可，无需改动。
Future<int?> showG2048SizePicker(BuildContext context) {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('选择棋盘尺寸', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '经典模式 · 无通关条件 · 玩到无法移动为止',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (var s = 3; s <= 8; s++)
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text('${s}×${s}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('返回'),
            ),
          ),
        ],
      ),
    ),
  );
}
