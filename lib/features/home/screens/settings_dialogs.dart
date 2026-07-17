import 'package:flutter/material.dart';

/// 清除缓存确认弹窗
void showClearCacheDialog(BuildContext context, Future<void> Function() clearCache) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清除缓存'),
      content: const Text('确定要清除本地缓存数据吗？不会影响云端数据。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            await clearCache();
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

/// 注销账号确认弹窗
void showDeleteAccountDialog(BuildContext context, Future<void> Function() deleteAccount) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('注销账号', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      content: const Text(
        '警告：此操作将永久删除您的账号及所有相关数据，包括消费记录、体重记录、心情日记、笔记、收藏等。此操作不可恢复！\n\n请确认您已备份重要数据。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () async {
            Navigator.pop(context);
            await deleteAccount();
          },
          child: const Text('确认注销'),
        ),
      ],
    ),
  );
}
