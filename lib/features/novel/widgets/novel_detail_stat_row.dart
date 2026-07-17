import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../services/dict_service.dart';
import '../models/novel_model.dart';
import 'novel_detail_helpers.dart';

/// 小说详情统计信息行（字数/章节/状态/评分）
class NovelDetailStatRow extends StatelessWidget {
  final NovelModel novel;
  final double? userRating;
  final VoidCallback onRateTap;

  const NovelDetailStatRow({
    super.key,
    required this.novel,
    required this.userRating,
    required this.onRateTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            StatItem(
              label: '字数',
              value: formatNovelWordCount(novel.wordCount),
            ),
            Container(width: 1, height: 32, color: colorScheme.outlineVariant),
            StatItem(
              label: '章节',
              value: '${novel.chapterCount} 章',
            ),
            Container(width: 1, height: 32, color: colorScheme.outlineVariant),
            StatItem(
              label: '状态',
              value: DictService.instance.getLabelOrDefault(
                dictNovelStatus,
                novel.status ?? '',
                defaultValue: novel.status == novelStatusCompleted ? '已完结' : '连载中',
              ),
            ),
            Container(width: 1, height: 32, color: colorScheme.outlineVariant),
            StatItem(
              label: '评分',
              value: novel.rating != null ? '${novel.rating}' : '--',
            ),
            Container(width: 1, height: 32, color: colorScheme.outlineVariant),
            InkWell(
              onTap: onRateTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final filled = i < (userRating?.round() ?? 0);
                        return Icon(
                          filled ? Icons.star : Icons.star_border,
                          size: 18,
                          color: filled ? Colors.amber : colorScheme.outline,
                        );
                      }),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userRating != null ? '我的评分: ${userRating!.toStringAsFixed(1)}' : '点击评分',
                      style: TextStyle(fontSize: 10, color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
