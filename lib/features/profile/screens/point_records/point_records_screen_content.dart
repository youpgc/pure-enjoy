import 'package:flutter/material.dart';
import './point_record_info.dart';
import '../../models/point_record_model.dart';
import '../../../../utils/date_time_utils.dart';

part 'point_records_parts.dart';

/// {@template point_records_content}
/// [PointRecordsScreen] 的主体内容（积分明细列表）。
/// 仅读取传入字段与回调，不持有状态。签到/补签已拆分到 CheckinScreen。
/// {@endtemplate}
class PointRecordsContent extends StatelessWidget {
  /// {@macro point_records_content}
  const PointRecordsContent({
    super.key,
    required this.records,
    required this.isLoading,
    required this.expiringPoints,
    required this.scrollController,
    required this.loadMoreIndicator,
    required this.onShowRules,
    required this.onRefresh,
  });

  final List<PointRecord> records;
  final bool isLoading;
  final int expiringPoints;
  final ScrollController scrollController;
  final Widget loadMoreIndicator;
  final VoidCallback onShowRules;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分明细'),
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
            if (expiringPoints > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$expiringPoints 积分将于 30 天内过期',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
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
              '暂无积分明细',
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
