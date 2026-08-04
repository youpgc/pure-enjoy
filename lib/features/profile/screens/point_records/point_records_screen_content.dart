import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import './point_record_info.dart';
import '../../models/point_record_model.dart';
import '../../../../utils/date_time_utils.dart';

part 'point_records_parts.dart';

/// {@template point_records_content}
/// [PointRecordsScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。进一步拆为 Summary / Streak / Empty / Item 子组件。
/// {@endtemplate}
class PointRecordsContent extends StatelessWidget {
  /// {@macro point_records_content}
  const PointRecordsContent({
    super.key,
    required this.availablePoints,
    required this.isLoadingPoints,
    required this.hasCheckedInToday,
    required this.isCheckingIn,
    required this.consecutiveCheckinDays,
    required this.records,
    required this.isLoading,
    required this.scrollController,
    required this.loadMoreIndicator,
    required this.onShowRules,
    required this.onRefresh,
    required this.onCheckin,
  });

  final int availablePoints;
  final bool isLoadingPoints;
  final bool hasCheckedInToday;
  final bool isCheckingIn;
  final int consecutiveCheckinDays;
  final List<PointRecord> records;
  final bool isLoading;
  final ScrollController scrollController;
  final Widget loadMoreIndicator;
  final VoidCallback onShowRules;
  final Future<void> Function() onRefresh;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: onShowRules,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          controller: scrollController,
          children: [
            PointRecordsSummaryCard(
              availablePoints: availablePoints,
              isLoadingPoints: isLoadingPoints,
              hasCheckedInToday: hasCheckedInToday,
              isCheckingIn: isCheckingIn,
              onCheckin: onCheckin,
            ),
            if (consecutiveCheckinDays > 0)
              PointRecordsStreakBanner(consecutiveCheckinDays: consecutiveCheckinDays),
            if (records.isEmpty && !isLoading)
              const PointRecordsEmpty(),
            ...records.map((record) {
              final typeInfo = _getTypeInfo(record.type);
              final isPositive = record.amount > 0;
              final expiryInfo = _getExpiryInfo(record);
              return PointRecordListItem(
                record: record,
                typeInfo: typeInfo,
                isPositive: isPositive,
                expiryInfo: expiryInfo,
              );
            }),
            if (isLoading && records.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: loadMoreIndicator,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 总积分卡片 + 签到按钮
class PointRecordsSummaryCard extends StatelessWidget {
  const PointRecordsSummaryCard({
    super.key,
    required this.availablePoints,
    required this.isLoadingPoints,
    required this.hasCheckedInToday,
    required this.isCheckingIn,
    required this.onCheckin,
  });

  final int availablePoints;
  final bool isLoadingPoints;
  final bool hasCheckedInToday;
  final bool isCheckingIn;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$availablePoints',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '可用积分',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (isLoadingPoints)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: (hasCheckedInToday || isCheckingIn) ? null : onCheckin,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCheckingIn)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else ...[
                      Icon(
                        hasCheckedInToday
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                      ),
                      const SizedBox(width: 4),
                      Text(hasCheckedInToday ? '已签到' : '签到'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 连续签到天数提示条
class PointRecordsStreakBanner extends StatelessWidget {
  const PointRecordsStreakBanner({super.key, required this.consecutiveCheckinDays});

  final int consecutiveCheckinDays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(
            UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_fire_department,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '已连续签到 $consecutiveCheckinDays 天',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态
class PointRecordsEmpty extends StatelessWidget {
  const PointRecordsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.monetization_on_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '暂无积分记录',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


