import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../services/dict_service.dart';
import '../models/novel_model.dart';
import './novel_cover.dart';
import './novel_source_badge.dart';

/// 继续阅读横向卡片（高度自约束，避免 RenderFlex 垂直溢出）。
///
/// 与 [NovelCard] 的区别：本卡片仅让封面 [Expanded] 占据剩余空间，
/// 信息区按【自然高度】排布（不抢 flex 空间）。这样即便系统字体放大，
/// 信息区也只会变高、封面变矮，整卡绝不会触发「超出高度的限制」。
/// [NovelCard] 的 3:2 固定切分仅适配网格（高 ~263px），塞进 180px
/// 横向条时在大字体下信息区会溢出，故横向条单独用本组件。
class ContinueReadingCard extends StatelessWidget {
  final NovelModel novel;
  final VoidCallback onTap;

  const ContinueReadingCard({
    super.key,
    required this.novel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面：占据剩余高度；信息区自然高度，整卡不溢出
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NovelCover(
                      coverUrl: novel.cover,
                      title: novel.title,
                      borderRadius: 0,
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
            ),
            // 信息区：自然高度（mainAxisSize.min），字体放大也不溢出
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    novel.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    novel.author ?? '佚名',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (novel.category != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DictService.instance.getLabelOrDefault(
                        dictNovelCategory,
                        novel.category!,
                        defaultValue: novel.category!,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
