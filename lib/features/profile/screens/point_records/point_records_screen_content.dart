import 'package:flutter/material.dart';
import './point_record_info.dart';
import './checkin_calendar_card.dart';
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
    required this.displayMonth,
    required this.checkedDates,
    required this.isLoadingCalendar,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onMakeup,
    required this.canGoNext,
    required this.makeupCardCount,
    required this.onOpenMall,
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

  // 日历打卡卡所需
  final DateTime displayMonth;
  final Set<String> checkedDates;
  final bool isLoadingCalendar;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime) onMakeup;
  final bool canGoNext;
  final int makeupCardCount;
  final VoidCallback onOpenMall;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            onPressed: onOpenMall,
            tooltip: '积分商城',
          ),
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
            CheckinCalendarCard(
              availablePoints: availablePoints,
              isLoadingPoints: isLoadingPoints,
              hasCheckedInToday: hasCheckedInToday,
              isCheckingIn: isCheckingIn,
              consecutiveCheckinDays: consecutiveCheckinDays,
              displayMonth: displayMonth,
              checkedDates: checkedDates,
              isLoadingCalendar: isLoadingCalendar,
              onCheckin: onCheckin,
              onPrevMonth: onPrevMonth,
              onNextMonth: onNextMonth,
              onMakeup: onMakeup,
              canGoNext: canGoNext,
              makeupCardCount: makeupCardCount,
            ),
            if (records.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '积分明细',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
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

// 旧「总积分卡片 / 连续签到提示条」已迁移为 CheckinCalendarCard（见 checkin_calendar_card.dart）。

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


