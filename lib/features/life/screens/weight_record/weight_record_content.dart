import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../utils/date_time_utils.dart';
import '../../models/weight_record_model.dart';

/// {@template weight_record_content}
/// [WeightRecordScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。
/// {@endtemplate}
class WeightRecordContent extends StatelessWidget {
  /// {@macro weight_record_content}
  const WeightRecordContent({
    super.key,
    required this.records,
    required this.isLoading,
    required this.latestWeight,
    required this.previousWeight,
    required this.weightChange,
    required this.scrollController,
    required this.onRefresh,
    required this.onShowEditForm,
    required this.onDelete,
    required this.buildLoadMoreIndicator,
  });

  final List<WeightRecordModel> records;
  final bool isLoading;
  final double? latestWeight;
  final double? previousWeight;
  final double? weightChange;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(WeightRecordModel) onShowEditForm;
  final void Function(String) onDelete;
  final Widget Function() buildLoadMoreIndicator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WeightCurrentCard(
          latestWeight: latestWeight,
          previousWeight: previousWeight,
          weightChange: weightChange,
        ),
        Expanded(
          child: _WeightRecordBody(
            isLoading: isLoading,
            records: records,
            scrollController: scrollController,
            onRefresh: onRefresh,
            onShowEditForm: onShowEditForm,
            onDelete: onDelete,
            buildLoadMoreIndicator: buildLoadMoreIndicator,
          ),
        ),
      ],
    );
  }
}

/// 当前体重卡片。
class _WeightCurrentCard extends StatelessWidget {
  const _WeightCurrentCard({
    required this.latestWeight,
    required this.previousWeight,
    required this.weightChange,
  });

  final double? latestWeight;
  final double? previousWeight;
  final double? weightChange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(
          UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前体重',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            latestWeight != null
                ? '${latestWeight!.toStringAsFixed(2)} kg'
                : '-- kg',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          if (weightChange != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  weightChange! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: weightChange! > 0 ? colorScheme.error : colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${weightChange!.abs().toStringAsFixed(2)} kg',
                  style: TextStyle(
                    color: weightChange! > 0 ? colorScheme.error : colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 列表区域：加载中 / 空 / 列表三态。
class _WeightRecordBody extends StatelessWidget {
  const _WeightRecordBody({
    required this.isLoading,
    required this.records,
    required this.scrollController,
    required this.onRefresh,
    required this.onShowEditForm,
    required this.onDelete,
    required this.buildLoadMoreIndicator,
  });

  final bool isLoading;
  final List<WeightRecordModel> records;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(WeightRecordModel) onShowEditForm;
  final void Function(String) onDelete;
  final Widget Function() buildLoadMoreIndicator;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }
    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: const CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyWidget(
                  icon: Icons.monitor_weight_outlined,
                  message: '暂无记录',
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _WeightRecordList(
      records: records,
      scrollController: scrollController,
      onRefresh: onRefresh,
      onShowEditForm: onShowEditForm,
      onDelete: onDelete,
      buildLoadMoreIndicator: buildLoadMoreIndicator,
    );
  }
}

/// 体重记录列表。
class _WeightRecordList extends StatelessWidget {
  const _WeightRecordList({
    required this.records,
    required this.scrollController,
    required this.onRefresh,
    required this.onShowEditForm,
    required this.onDelete,
    required this.buildLoadMoreIndicator,
  });

  final List<WeightRecordModel> records;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(WeightRecordModel) onShowEditForm;
  final void Function(String) onDelete;
  final Widget Function() buildLoadMoreIndicator;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: records.length + 1,
        itemBuilder: (context, index) {
          if (index == records.length) {
            return buildLoadMoreIndicator();
          }
          final record = records[index];
          return _WeightRecordTile(
            record: record,
            onShowEditForm: onShowEditForm,
            onDelete: onDelete,
          );
        },
      ),
    );
  }
}

/// 单条体重记录卡片。
class _WeightRecordTile extends StatelessWidget {
  const _WeightRecordTile({
    required this.record,
    required this.onShowEditForm,
    required this.onDelete,
  });

  final WeightRecordModel record;
  final void Function(WeightRecordModel) onShowEditForm;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    // date 与 created_at 日期相同时展示 created_at（含真实时分秒），不同时展示 date
    // 注意：createdAt 为 UTC，需先转本地时区再比较日期
    final createdAtLocal = record.createdAt?.toLocal();
    final isSameDate = createdAtLocal != null &&
        record.date.year == createdAtLocal.year &&
        record.date.month == createdAtLocal.month &&
        record.date.day == createdAtLocal.day;
    final displayDate = (isSameDate && record.createdAt != null)
        ? record.createdAt!
        : record.date;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.monitor_weight),
        title: Row(
          children: [
            Text(
              '${record.weight.toStringAsFixed(2)} kg',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (record.bodyFat != null) ...[
              const SizedBox(width: 12),
              Text(
                '体脂 ${record.bodyFat!.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (record.bmi != null) ...[
              const SizedBox(width: 12),
              Text(
                'BMI ${record.bmi!.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateTimeUtils.formatStandard(displayDate)),
            if (record.note != null && record.note!.isNotEmpty)
              Text(
                record.note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: EditDeletePopupMenu(
          onEdit: () => onShowEditForm(record),
          onDelete: () => onDelete(record.id),
        ),
      ),
    );
  }
}
