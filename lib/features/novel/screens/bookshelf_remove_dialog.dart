import 'package:flutter/material.dart';

/// 确认移出书架
void showBookshelfRemoveDialog(
  BuildContext context, {
  required VoidCallback onRemove,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认移除'),
      content: const Text('确定要将这本小说从书架移除吗？阅读进度将不会保留。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onRemove();
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('移除'),
        ),
      ],
    ),
  );
}
