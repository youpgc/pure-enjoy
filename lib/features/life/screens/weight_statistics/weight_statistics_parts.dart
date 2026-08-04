part of './weight_statistics_content.dart';

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
      elevation: AppTheme.cardElevation(context),
      shadowColor: AppTheme.cardShadowColor(color.withValues(alpha: 0.1)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
        ),
        side: AppTheme.cardBorderSide(context, color.withValues(alpha: 0.1)),
      ),
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
