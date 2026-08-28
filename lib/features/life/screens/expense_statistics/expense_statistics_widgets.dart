import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/dict_service.dart';

/// 时间区间标题与选择按钮（有/无数据共用）。
class ExpenseRangeHeader extends StatelessWidget {
  const ExpenseRangeHeader({
    super.key,
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
class ExpenseEmptyState extends StatelessWidget {
  const ExpenseEmptyState({
    super.key,
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
          Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '$rangeText暂无消费记录',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

/// 总消费卡片。
class ExpenseTotalCard extends StatelessWidget {
  const ExpenseTotalCard({super.key, required this.total, required this.count});

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

/// 圆环中心信息（选中分类明细 / 未选中时展示总额）。
class PieCenterInfo extends StatelessWidget {
  const PieCenterInfo({
    super.key,
    required this.label,
    required this.amount,
    this.percentage,
  });

  final String label;
  final double amount;
  final double? percentage;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
            textAlign: TextAlign.center,
          ),
          if (percentage != null)
            Text(
              '${percentage!.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

/// 分类饼图（可交互：点击扇区选中，与分类列表双向联动）。
class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({
    super.key,
    required this.categories,
    required this.colors,
    required this.total,
    required this.selectedIndex,
    required this.onTouched,
  });

  final List<MapEntry<String, double>> categories;
  final List<Color> colors;
  final double total;
  final int? selectedIndex;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex != null && selectedIndex! < categories.length
        ? categories[selectedIndex!]
        : null;

    final centerChild = selected != null
        ? PieCenterInfo(
            label: DictService.instance.getLabelOrDefault(
              'expense_category',
              selected.key,
              defaultValue: selected.key,
            ),
            amount: selected.value,
            percentage: total > 0 ? selected.value / total * 100 : 0,
          )
        : PieCenterInfo(
            label: '总支出',
            amount: total,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sections: categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final percentage = total > 0 ? (category.value / total * 100) : 0.0;
                  final isSelected = selectedIndex == index;
                  // 选中态半径略大、未选中稍小；外半径 = centerSpaceRadius + radius 必须 ≤ 容器半高(145)，
                  // 否则选中交互放大后会溢出压住下方分类列表。
                  final radius = isSelected ? 74.0 : 64.0;
                return PieChartSectionData(
                  value: category.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  color: colors[index % colors.length],
                  radius: radius,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 58,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) return;
                  if (event is FlTapUpEvent) {
                    final idx = response?.touchedSection?.touchedSectionIndex;
                    if (idx != null && idx >= 0 && idx < categories.length) {
                      onTouched(idx);
                    }
                  }
                },
              ),
            ),
          ),
          centerChild,
        ],
      ),
      ),
    );
  }
}

/// 分类列表（可点击，与饼图选中态双向联动）。
class ExpenseCategoryList extends StatelessWidget {
  const ExpenseCategoryList({
    super.key,
    required this.categories,
    required this.colors,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<MapEntry<String, double>> categories;
  final List<Color> colors;
  final int? selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final isSelected = selectedIndex == index;
        final categoryLabel = DictService.instance.getLabelOrDefault(
          'expense_category',
          category.key,
          defaultValue: category.key,
        );
        return ListTile(
          selected: isSelected,
          selectedColor: Theme.of(context).colorScheme.onSurface,
          selectedTileColor:
              colors[index % colors.length].withValues(alpha: 0.12),
          leading: CircleAvatar(
            backgroundColor: colors[index % colors.length],
            radius: 12,
          ),
          title: Text(categoryLabel),
          trailing: Text(
            '¥${category.value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onTap: () => onTap(index),
        );
      }).toList(),
    );
  }
}
