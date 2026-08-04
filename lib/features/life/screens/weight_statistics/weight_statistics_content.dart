import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';

part 'weight_statistics_parts.dart';
part 'weight_statistics_chart.dart';

/// {@template weight_statistics_content}
/// [WeightStatisticsScreen] 的主体内容（从超长 _buildBody 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。
/// {@endtemplate}
class WeightStatisticsContent extends StatelessWidget {
  /// {@macro weight_statistics_content}
  const WeightStatisticsContent({
    super.key,
    required this.records,
    required this.isLoading,
    required this.error,
    required this.startMonth,
    required this.endMonth,
    required this.rangeText,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final List<Map<String, dynamic>> records;
  final bool isLoading;
  final String error;
  final DateTime startMonth;
  final DateTime endMonth;
  final String rangeText;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }
    if (error.isNotEmpty) {
      return Center(child: Text(error));
    }
    if (records.isEmpty) {
      return _WeightEmptyState(
        rangeText: rangeText,
        startMonth: startMonth,
        endMonth: endMonth,
        onPickStartMonth: onPickStartMonth,
        onPickEndMonth: onPickEndMonth,
      );
    }
    return _WeightStatisticsLoaded(
      records: records,
      startMonth: startMonth,
      endMonth: endMonth,
      rangeText: rangeText,
      onPickStartMonth: onPickStartMonth,
      onPickEndMonth: onPickEndMonth,
    );
  }
}
