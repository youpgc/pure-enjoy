import 'package:flutter/material.dart';
import '../reader_enums.dart';
import '../reader_toolbar_button.dart';

/// 小说阅读器底部悬浮工具栏
class ReaderBottomToolbar extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ReaderBackground background;
  final int currentChapterIndex;
  final int chapterCount;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onOpenDrawer;
  final VoidCallback onShowBookmarkList;
  final VoidCallback onShowAnnotationList;
  final VoidCallback onShowSettings;
  final VoidCallback onToggleDayNight;

  const ReaderBottomToolbar({
    super.key,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.background,
    required this.currentChapterIndex,
    required this.chapterCount,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onOpenDrawer,
    required this.onShowBookmarkList,
    required this.onShowAnnotationList,
    required this.onShowSettings,
    required this.onToggleDayNight,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Container(
          color: background.bgColor,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: currentChapterIndex > 0 ? onPreviousChapter : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: background.textColor,
                              side: BorderSide(color: background.textColor.withValues(alpha: 0.3)),
                            ),
                            child: const Text('上一章'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: FilledButton(
                            onPressed: currentChapterIndex < chapterCount - 1 ? onNextChapter : null,
                            child: const Text('下一章'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ReaderToolbarButton(
                        icon: Icons.list_outlined,
                        label: '目录',
                        textColor: background.textColor,
                        onTap: onOpenDrawer,
                      ),
                      ReaderToolbarButton(
                        icon: Icons.bookmark_outline,
                        label: '书签',
                        textColor: background.textColor,
                        onTap: onShowBookmarkList,
                      ),
                      ReaderToolbarButton(
                        icon: Icons.comment_outlined,
                        label: '批注',
                        textColor: background.textColor,
                        onTap: onShowAnnotationList,
                      ),
                      ReaderToolbarButton(
                        icon: Icons.settings_outlined,
                        label: '设置',
                        textColor: background.textColor,
                        onTap: onShowSettings,
                      ),
                      ReaderToolbarButton(
                        icon: background == ReaderBackground.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        label: background == ReaderBackground.dark ? '日间' : '夜间',
                        textColor: background.textColor,
                        onTap: onToggleDayNight,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
