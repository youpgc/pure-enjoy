import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../services/dict_service.dart';
import '../models/novel_model.dart';
import '../widgets/novel_cover.dart';

/// 小说详情头部（封面 + 标题 + 作者 + 分类）
class NovelDetailHeader extends StatelessWidget {
  final NovelModel novel;

  const NovelDetailHeader({super.key, required this.novel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 背景封面（模糊效果）
            Positioned.fill(
              child: NovelCover(
                coverUrl: novel.cover,
                title: novel.title,
                borderRadius: 0,
              ),
            ),
            // 渐变遮罩
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      colorScheme.surface,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // 小说信息
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 封面缩略图
                  NovelCover(
                    coverUrl: novel.cover,
                    title: novel.title,
                    width: 90,
                    height: 120,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 16),
                  // 标题和作者
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          novel.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          novel.author ?? '佚名',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (novel.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              DictService.instance.getLabelOrDefault(
                                dictNovelCategory,
                                novel.category!,
                                defaultValue: novel.category!,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
