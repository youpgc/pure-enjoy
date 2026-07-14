import 'package:flutter/material.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../novel/models/novel_model.dart';
import '../../../novel/widgets/novel_cover.dart';

/// 最近阅读区块组件
///
/// 展示用户最近阅读的小说列表。
class RecentReadingSection extends StatefulWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> novels;
  final Function(NovelModel novel, int lastChapter) onContinueReading;

  const RecentReadingSection({
    super.key,
    required this.isLoading,
    required this.novels,
    required this.onContinueReading,
  });

  @override
  State<RecentReadingSection> createState() => _RecentReadingSectionState();
}

class _RecentReadingSectionState extends State<RecentReadingSection> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近阅读',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: widget.isLoading
              ? SizedBox(
                  height: 230,
                  child: SkeletonLoading.grid(
                    itemCount: 3,
                    crossAxisCount: 3,
                    aspectRatio: 0.75,
                  ),
                )
              : widget.novels.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '暂无阅读记录',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(12),
                        itemCount: widget.novels.length,
                        itemBuilder: (context, index) {
                          final item = widget.novels[index];
                          final novel = item['novel'] as NovelModel;
                          final lastChapter = item['lastChapter'] as int;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => widget.onContinueReading(
                                novel,
                                lastChapter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 120,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    NovelCover(
                                      coverUrl: novel.cover,
                                      title: novel.title,
                                      width: 120,
                                      height: 160,
                                      borderRadius: 8,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      novel.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '第$lastChapter章',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
