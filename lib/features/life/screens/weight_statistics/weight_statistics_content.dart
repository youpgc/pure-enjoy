import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';

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

/// 时间区间标题与选择按钮（无数据时复用）。
class _WeightRangeHeader extends StatelessWidget {
  const _WeightRangeHeader({
    required this.rangeText,
    required this.startMonth,
    required this.endMonth,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final String rangeText;
  final DateTime startMonth;
  final DateTime endMonth;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            rangeText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onPickStartMonth,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  '${startMonth.year}-${startMonth.month.toString().padLeft(2, '0')}',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('至'),
              ),
              OutlinedButton.icon(
                onPressed: onPickEndMonth,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 空数据占位（含区间选择）。
class _WeightEmptyState extends StatelessWidget {
  const _WeightEmptyState({
    required this.rangeText,
    required this.startMonth,
    required this.endMonth,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final String rangeText;
  final DateTime startMonth;
  final DateTime endMonth;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monitor_weight_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '$rangeText暂无体重记录',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onPickStartMonth,
                icon: const Icon(Icons.date_range),
                label: Text(
                  '${startMonth.year}-${startMonth.month.toString().padLeft(2, '0')}',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('至'),
              ),
              OutlinedButton.icon(
                onPressed: onPickEndMonth,
                icon: const Icon(Icons.date_range),
                label: Text(
                  '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 已加载数据的主区域。
class _WeightStatisticsLoaded extends StatelessWidget {
  const _WeightStatisticsLoaded({
    required this.records,
    required this.startMonth,
    required this.endMonth,
    required this.rangeText,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final List<Map<String, dynamic>> records;
  final DateTime startMonth;
  final DateTime endMonth;
  final String rangeText;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;

  @override
  Widget build(BuildContext context) {
    // 反转数据按日期升序排列
    final sortedRecords = records.reversed.toList();

    // 提取数据点
    final spots = sortedRecords.asMap().entries.map((entry) {
      final index = entry.key;
      final record = entry.value;
      return FlSpot(index.toDouble(), (record['weight'] ?? 0).toDouble());
    }).toList();

    // 计算统计信息
    final weights = sortedRecords.map((r) => (r['weight'] ?? 0).toDouble()).toList();
    final currentWeight = weights.isNotEmpty ? weights.last : 0.0;
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeightRangeHeader(
            rangeText: rangeText,
            startMonth: startMonth,
            endMonth: endMonth,
            onPickStartMonth: onPickStartMonth,
            onPickEndMonth: onPickEndMonth,
          ),
          const SizedBox(height: 16),
          _WeightStatRow(
            currentWeight: currentWeight,
            minWeight: minWeight,
            maxWeight: maxWeight,
          ),
          const SizedBox(height: 24),
          Text(
            '体重变化曲线',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _WeightChart(sortedRecords: sortedRecords, spots: spots),
          const SizedBox(height: 24),
          Text(
            '最近记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _WeightRecordList(sortedRecords: sortedRecords),
        ],
      ),
    );
  }
}

/// 当前 / 最低 / 最高三张统计卡片。
class _WeightStatRow extends StatelessWidget {
  const _WeightStatRow({
    required this.currentWeight,
    required this.minWeight,
    required this.maxWeight,
  });

  final double currentWeight;
  final double minWeight;
  final double maxWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '当前',
            value: '${currentWeight.toStringAsFixed(1)} kg',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: '最低',
            value: '${minWeight.toStringAsFixed(1)} kg',
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: '最高',
            value: '${maxWeight.toStringAsFixed(1)} kg',
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

/// 体重曲线图。
class _WeightChart extends StatelessWidget {
  const _WeightChart({
    required this.sortedRecords,
    required this.spots,
  });

  final List<Map<String, dynamic>> sortedRecords;
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (sortedRecords.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedRecords.length) {
                    final date = sortedRecords[index]['date'];
                    if (date != null) {
                      return Text(
                        DateFormat('MM/dd').format(DateTime.parse(date.toString())),
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: spots.length < 20,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < sortedRecords.length) {
                    final date = sortedRecords[index]['date'];
                    return LineTooltipItem(
                      '${DateFormat('MM/dd').format(DateTime.parse(date.toString()))}\n${spot.y.toStringAsFixed(1)} kg',
                      const TextStyle(color: Colors.white),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 最近记录列表。
class _WeightRecordList extends StatelessWidget {
  const _WeightRecordList({required this.sortedRecords});

  final List<Map<String, dynamic>> sortedRecords;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sortedRecords.reversed.take(10).map((record) {
        final date = DateTime.parse(record['date'].toString());
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.monitor_weight)),
          title: Text('${record['weight']} kg'),
          subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
          trailing: record['bmi'] != null
              ? Text('BMI: ${(record['bmi']).toStringAsFixed(1)}')
              : null,
        );
      }).toList(),
    );
  }
}

/// 统计卡片组件
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
