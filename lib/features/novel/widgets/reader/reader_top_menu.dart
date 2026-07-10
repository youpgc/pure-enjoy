import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../../models/novel_chapter_model.dart';
import '../reader_enums.dart';
import '../../screens/novel_detail_screen.dart';

/// 小说阅读器顶部菜单（菜单显示时才显示，层级高）
class ReaderTopMenu extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ReaderBackground background;
  final NovelModel novel;
  final NovelChapterModel? currentChapter;
  final int currentChapterIndex;
  final int chapterCount;
  final bool hasStartedReading;
  final Duration currentReadingDuration;
  final bool isCollected;
  final VoidCallback onBack;
  final VoidCallback onToggleCollection;
  final VoidCallback onShowTtsPanel;

  const ReaderTopMenu({
    super.key,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.background,
    required this.novel,
    this.currentChapter,
    required this.currentChapterIndex,
    required this.chapterCount,
    required this.hasStartedReading,
    required this.currentReadingDuration,
    required this.isCollected,
    required this.onBack,
    required this.onToggleCollection,
    required this.onShowTtsPanel,
  });

  String _formatReadingDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}小时${duration.inMinutes.remainder(60)}分钟';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '${duration.inSeconds}秒';
    }
  }

  void _showDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: novel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Container(
          color: background.bgColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: background.textColor, size: 20),
                    onPressed: onBack,
                    tooltip: '返回',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 4),
                  // 小说名 + 章节进度 + 阅读时长
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          novel.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: background.textColor.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentChapter != null && chapterCount > 0)
                          Text(
                            '${currentChapter!.title} · ${currentChapterIndex + 1}/$chapterCount章${hasStartedReading ? ' · 已读${_formatReadingDuration(currentReadingDuration)}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: background.textColor.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // 收藏
                  IconButton(
                    icon: Icon(
                      isCollected ? Icons.favorite : Icons.favorite_border,
                      color: isCollected ? Theme.of(context).colorScheme.error : background.textColor,
                    ),
                    onPressed: onToggleCollection,
                    tooltip: '收藏',
                  ),
                  // 听书
                  IconButton(
                    icon: Icon(Icons.headphones_outlined, color: background.textColor),
                    onPressed: onShowTtsPanel,
                    tooltip: '听书',
                  ),
                  // 详情
                  IconButton(
                    icon: Icon(Icons.info_outline, color: background.textColor),
                    onPressed: () => _showDetail(context),
                    tooltip: '详情',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
