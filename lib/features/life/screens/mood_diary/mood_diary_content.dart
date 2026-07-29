import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../services/dict_service.dart';
import '../../../../utils/date_time_utils.dart';
import '../../models/mood_diary_model.dart';

/// {@template mood_diary_content}
/// [MoodDiaryScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。
/// {@endtemplate}
class MoodDiaryContent extends StatelessWidget {
  /// {@macro mood_diary_content}
  const MoodDiaryContent({
    super.key,
    required this.diaries,
    required this.isLoading,
    required this.scrollController,
    required this.onRefresh,
    required this.onShowEditForm,
    required this.onDelete,
    required this.buildLoadMoreIndicator,
  });

  final List<MoodDiaryModel> diaries;
  final bool isLoading;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(MoodDiaryModel) onShowEditForm;
  final void Function(String) onDelete;
  final Widget Function() buildLoadMoreIndicator;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }
    if (diaries.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: const CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyWidget(
                icon: Icons.mood_outlined,
                message: '暂无日记，点击右下角按钮添加',
              ),
            ),
          ],
        ),
      );
    }
    return _MoodDiaryList(
      diaries: diaries,
      scrollController: scrollController,
      onRefresh: onRefresh,
      onShowEditForm: onShowEditForm,
      onDelete: onDelete,
      buildLoadMoreIndicator: buildLoadMoreIndicator,
    );
  }
}

/// 心情日记列表。
class _MoodDiaryList extends StatelessWidget {
  const _MoodDiaryList({
    required this.diaries,
    required this.scrollController,
    required this.onRefresh,
    required this.onShowEditForm,
    required this.onDelete,
    required this.buildLoadMoreIndicator,
  });

  final List<MoodDiaryModel> diaries;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(MoodDiaryModel) onShowEditForm;
  final void Function(String) onDelete;
  final Widget Function() buildLoadMoreIndicator;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: diaries.length + 1,
        itemBuilder: (context, index) {
          if (index == diaries.length) {
            return buildLoadMoreIndicator();
          }
          final diary = diaries[index];
          return _MoodDiaryTile(
            diary: diary,
            onShowEditForm: onShowEditForm,
            onDelete: onDelete,
          );
        },
      ),
    );
  }
}

/// 单条心情日记卡片。
class _MoodDiaryTile extends StatelessWidget {
  const _MoodDiaryTile({
    required this.diary,
    required this.onShowEditForm,
    required this.onDelete,
  });

  final MoodDiaryModel diary;
  final void Function(MoodDiaryModel) onShowEditForm;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    final moodLabel = DictService.instance.getLabelOrDefault(
      'mood_type',
      diary.mood,
      defaultValue: diary.mood,
    );
    final moodEmoji = DictService.instance.getEmoji(
      'mood_type',
      diary.mood,
    );
    final displayDate = diary.createdAt != null &&
            diary.createdAt!.year == diary.entryDate.year &&
            diary.createdAt!.month == diary.entryDate.month &&
            diary.createdAt!.day == diary.entryDate.day
        ? diary.createdAt!
        : diary.entryDate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onShowEditForm(diary),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          moodEmoji.isNotEmpty ? moodEmoji : '😊',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        Text(moodLabel),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateTimeUtils.formatStandard(displayDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  EditDeletePopupMenu(
                    onEdit: () => onShowEditForm(diary),
                    onDelete: () => onDelete(diary.id),
                  ),
                ],
              ),
              if (diary.content != null && diary.content!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  diary.content!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
