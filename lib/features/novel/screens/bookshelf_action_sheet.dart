import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'bookshelf_helpers.dart';

/// 显示书架项操作底部弹窗
void showBookshelfActionSheet(
  BuildContext context,
  Map<String, dynamic> item, {
  required VoidCallback onContinueReading,
  required VoidCallback onOpenDetail,
  required void Function(String) onUpdateReadingStatus,
  required void Function(String) onConfirmRemove,
}) {
  final userNovelId = item['id'].toString();
  final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
  final currentStatus = getReadingStatus(progress);
  final lastChapter = item['last_chapter'] as int? ?? 1;
  final novelData = item['novels'] as Map<String, dynamic>?;
  final chapterCount = novelData?['chapter_count'] as int? ?? 0;

  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 继续阅读
          ListTile(
            leading: Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary),
            title: const Text('继续阅读'),
            subtitle: Text('第 $lastChapter / $chapterCount 章'),
            onTap: () {
              Navigator.pop(context);
              onContinueReading();
            },
          ),
          // 查看详情
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('查看详情'),
            onTap: () {
              Navigator.pop(context);
              onOpenDetail();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '更改阅读状态',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories),
            title: const Text('在读'),
            trailing: currentStatus == 'reading'
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              Navigator.pop(context);
              if (currentStatus != 'reading') {
                onUpdateReadingStatus('reading');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.done_all),
            title: const Text('已读完'),
            trailing: currentStatus == 'completed'
                ? const Icon(Icons.check, color: AppTheme.success)
                : null,
            onTap: () {
              Navigator.pop(context);
              if (currentStatus != 'completed') {
                onUpdateReadingStatus('completed');
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('移出书架', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              onConfirmRemove(userNovelId);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
