import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../reader_enums.dart';

/// 小说阅读器顶部状态栏（始终显示，层级低）
class ReaderTopStatusBar extends StatelessWidget {
  final ReaderBackground background;
  final NovelChapterModel? currentChapter;
  final String novelTitle;
  final VoidCallback onBack;

  const ReaderTopStatusBar({
    super.key,
    required this.background,
    this.currentChapter,
    required this.novelTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: background.textColor.withValues(alpha: 0.7),
              ),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: '返回',
            ),
            Expanded(
              child: Text(
                currentChapter?.title ?? novelTitle,
                style: TextStyle(
                  fontSize: 13,
                  color: background.textColor.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小说阅读器底部状态栏（始终显示）
class ReaderBottomStatusBar extends StatelessWidget {
  final ReaderBackground background;
  final bool chaptersNotEmpty;
  final double readingProgress;
  final String currentTime;
  final int batteryLevel;

  const ReaderBottomStatusBar({
    super.key,
    required this.background,
    required this.chaptersNotEmpty,
    required this.readingProgress,
    required this.currentTime,
    required this.batteryLevel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 总体进度条
          if (chaptersNotEmpty)
            LinearProgressIndicator(
              value: readingProgress,
              backgroundColor: background.textColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 2,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currentTime  $batteryLevel%',
                  style: TextStyle(
                    fontSize: 12,
                    color: background.textColor.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '${(readingProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: background.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
