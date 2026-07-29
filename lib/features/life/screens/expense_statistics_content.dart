import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/dict_service.dart';

/// {@template expense_statistics_content}
/// [ExpenseStatisticsScreen] 的主体内容（从超长 _buildBody 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。
/// {@endtemplate}
class ExpenseStatisticsContent extends StatelessWidget {
  /// {@macro expense_statistics_content}
  const ExpenseStatisticsContent({
    super.key,
    required this.expenses,
    required this.isLoading,
    required this.error,
    required this.startMonth,
    required this.endMonth,
    required this.rangeText,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final List<Map<String, dynamic>> expenses;
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
    if (expenses.isEmpty) {
      return _ExpenseEmptyState(
        rangeText: rangeText,
        startMonth: startMonth,
        endMonth: endMonth,
        onPickStartMonth: onPickStartMonth,
        onPickEndMonth: onPickEndMonth,
      );
    }
    return _ExpenseStatisticsLoaded(
      expenses: expenses,
      startMonth: startMonth,
      endMonth: endMonth,
      rangeText: rangeText,
      onPickStartMonth: onPickStartMonth,
      onPickEndMonth: onPickEndMonth,
    );
  }
}

/// 时间区间标题与选择按钮（有/无数据共用）。
class _ExpenseRangeHeader extends StatelessWidget {
  const _ExpenseRangeHeader({
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
class _ExpenseEmptyState extends StatelessWidget {
  const _ExpenseEmptyState({
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
          const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '$rangeText暂无消费记录',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
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
class _ExpenseStatisticsLoaded extends StatelessWidget {
  const _ExpenseStatisticsLoaded({
    required this.expenses,
    required this.startMonth,
    required this.endMonth,
    required this.rangeText,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final List<Map<String, dynamic>> expenses;
  final DateTime startMonth;
  final DateTime endMonth;
  final String rangeText;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;

  @override
  Widget build(BuildContext context) {
    // 按分类统计
    final categoryMap = <String, double>{};
    double total = 0;
    for (var expense in expenses) {
      final category = expense['category'] ?? '其他';
      final amount = (expense['amount'] ?? 0).toDouble();
      categoryMap[category] = (categoryMap[category] ?? 0) + amount;
      total += amount;
    }

    final categories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      AppTheme.success,
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.primary,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExpenseRangeHeader(
            rangeText: rangeText,
            startMonth: startMonth,
            endMonth: endMonth,
            onPickStartMonth: onPickStartMonth,
            onPickEndMonth: onPickEndMonth,
          ),
          const SizedBox(height: 16),
          _ExpenseTotalCard(total: total, count: expenses.length),
          const SizedBox(height: 24),
          Text(
            '消费分类',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _ExpensePieChart(categories: categories, colors: colors, total: total),
          const SizedBox(height: 16),
          _ExpenseCategoryList(categories: categories, colors: colors),
        ],
      ),
    );
  }
}

/// 总消费卡片。
class _ExpenseTotalCard extends StatelessWidget {
  const _ExpenseTotalCard({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '总消费',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '¥${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '$count 笔消费',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类饼图。
class _ExpensePieChart extends StatelessWidget {
  const _ExpensePieChart({
    required this.categories,
    required this.colors,
    required this.total,
  });

  final List<MapEntry<String, double>> categories;
  final List<Color> colors;
  final double total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final percentage = total > 0 ? (category.value / total * 100) : 0;
            return PieChartSectionData(
              value: category.value,
              title: '${percentage.toStringAsFixed(1)}%',
              color: colors[index % colors.length],
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }
}

/// 分类列表。
class _ExpenseCategoryList extends StatelessWidget {
  const _ExpenseCategoryList({
    required this.categories,
    required this.colors,
  });

  final List<MapEntry<String, double>> categories;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final categoryLabel = DictService.instance.getLabelOrDefault(
          'expense_category',
          category.key,
          defaultValue: category.key,
        );
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colors[index % colors.length],
            radius: 12,
          ),
          title: Text(categoryLabel),
          trailing: Text(
            '¥${category.value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }
}
