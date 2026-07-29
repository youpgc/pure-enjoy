import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import '../widgets/novel_cover.dart';

/// {@template recommendation_card_content}
/// [RecommendationScreen] 中的推荐卡片（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。信息列拆为 [RecommendationCardInfo]。
/// {@endtemplate}
class RecommendationCardContent extends StatelessWidget {
  /// {@macro recommendation_card_content}
  const RecommendationCardContent({
    super.key,
    required this.novel,
    required this.reasonChip,
    required this.onTap,
    required this.onNotInterested,
  });

  final NovelModel novel;
  final Widget reasonChip;
  final VoidCallback onTap;
  final VoidCallback onNotInterested;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          // 长按显示不感兴趣选项
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('不感兴趣'),
                    subtitle: Text('减少「${novel.category ?? '此类'}」推荐'),
                    onTap: () {
                      Navigator.pop(context);
                      onNotInterested();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.visibility_off),
                    title: const Text('屏蔽此小说'),
                    onTap: () {
                      Navigator.pop(context);
                      onNotInterested();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.close,
                        color: colorScheme.onSurfaceVariant),
                    title: Text('取消',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              NovelCover(
                coverUrl: novel.cover,
                title: novel.title,
                width: 80,
                height: 110,
                borderRadius: 4,
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: RecommendationCardInfo(
                  novel: novel,
                  reasonChip: reasonChip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 推荐卡片信息列：标题+原因标签 / 作者 / 简介 / 分类·评分。
class RecommendationCardInfo extends StatelessWidget {
  const RecommendationCardInfo({
    super.key,
    required this.novel,
    required this.reasonChip,
  });

  final NovelModel novel;
  final Widget reasonChip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                novel.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            reasonChip,
          ],
        ),
        const SizedBox(height: 4),
        Text(
          novel.author ?? '佚名',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          novel.description ?? '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (novel.category != null)
              Text(
                novel.category!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                ),
              ),
            const Spacer(),
            if (novel.rating != null) ...[
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 2),
              Text(
                novel.rating!.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
