import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../services/dict_service.dart';
import '../../../utils/format_utils.dart';
import '../models/novel_model.dart';
import '../widgets/novel_cover.dart';
import '../widgets/novel_source_badge.dart';

/// {@template novel_card_content}
/// [NovelCard] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。进一步拆为 Cover / Info 两个子组件。
/// {@endtemplate}
class NovelCardContent extends StatelessWidget {
  /// {@macro novel_card_content}
  const NovelCardContent({
    super.key,
    required this.novel,
    required this.onTap,
    this.onAddToBookshelf,
    this.isInBookshelf = false,
  });

  final NovelModel novel;
  final VoidCallback onTap;
  final VoidCallback? onAddToBookshelf;
  final bool isInBookshelf;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovelCardCover(
              novel: novel,
              onAddToBookshelf: onAddToBookshelf,
              isInBookshelf: isInBookshelf,
            ),
            NovelCardInfo(novel: novel),
          ],
        ),
      ),
    );
  }
}

/// 小说卡片封面区：封面 + 加入书架/已加入/聚合来源标记。
class NovelCardCover extends StatelessWidget {
  const NovelCardCover({
    super.key,
    required this.novel,
    this.onAddToBookshelf,
    this.isInBookshelf = false,
  });

  final NovelModel novel;
  final VoidCallback? onAddToBookshelf;
  final bool isInBookshelf;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      flex: 3,
      child: Stack(
        children: [
          Positioned.fill(
            child: NovelCover(
              coverUrl: novel.cover,
              title: novel.title,
              borderRadius: 0,
            ),
          ),
          if (onAddToBookshelf != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onAddToBookshelf,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          if (isInBookshelf)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '已加入',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          if (novel.isAggregated)
            Positioned(
              top: 4,
              left: 4,
              child: NovelSourceBadge(novel: novel, compact: true),
            ),
        ],
      ),
    );
  }
}

/// 小说卡片信息区：标题 / 作者 / 分类·字数。
class NovelCardInfo extends StatelessWidget {
  const NovelCardInfo({super.key, required this.novel});

  final NovelModel novel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              novel.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              novel.author ?? '佚名',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
            ),
            const Spacer(),
            Row(
              children: [
                if (novel.category != null)
                  Text(
                    DictService.instance.getLabelOrDefault(
                      dictNovelCategory,
                      novel.category!,
                      defaultValue: novel.category!,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  )
                else
                  Text(
                    '${novel.chapterCount} 章',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                if (novel.wordCount != null && novel.wordCount! > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '·',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    FormatUtils.formatWordCount(novel.wordCount!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
