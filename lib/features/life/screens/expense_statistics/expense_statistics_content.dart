import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../services/dict_service.dart';
import './expense_statistics_widgets.dart';
import '../expense_list/expense_list_screen.dart';

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
      return ExpenseEmptyState(
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

/// 已加载数据的主区域。
///
/// 改为 StatefulWidget 以承载「选中分类」交互态（饼图扇区与分类列表双向联动）。
class _ExpenseStatisticsLoaded extends StatefulWidget {
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
  State<_ExpenseStatisticsLoaded> createState() => _ExpenseStatisticsLoadedState();
}

class _ExpenseStatisticsLoadedState extends State<_ExpenseStatisticsLoaded> {
  /// 当前选中的分类下标；null 表示未选中（展示总额）。
  int? _selectedIndex;

  /// 点击扇区/分类：仅切换选中态（放大 + 中心明细 + 列表高亮），再次点击取消。
  /// 跳转由下方「查看对应消费记录」按钮触发，避免选中态被跳转吞掉（闭环修复 缺口2）。
  void _toggleSelect(int index) {
    setState(() => _selectedIndex = _selectedIndex == index ? null : index);
  }

  /// 跳转至该分类在统计区间内的消费记录列表（只读明细模式）。
  void _openCategoryRecords(int index, String categoryKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseListScreen(
          initialCategory: categoryKey,
          initialStartMonth: widget.startMonth,
          initialEndMonth: widget.endMonth,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 按分类统计
    final categoryMap = <String, double>{};
    double total = 0;
    for (var expense in widget.expenses) {
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
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.primary,
    ];

    final hasSelection =
        _selectedIndex != null && _selectedIndex! < categories.length;
    final selectedKey =
        hasSelection ? categories[_selectedIndex!].key : null;
    final selectedLabel = hasSelection && selectedKey != null
        ? DictService.instance.getLabelOrDefault(
            'expense_category',
            selectedKey,
            defaultValue: selectedKey,
          )
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpenseRangeHeader(
            rangeText: widget.rangeText,
            startMonth: widget.startMonth,
            endMonth: widget.endMonth,
            onPickStartMonth: widget.onPickStartMonth,
            onPickEndMonth: widget.onPickEndMonth,
          ),
          const SizedBox(height: 16),
          ExpenseTotalCard(total: total, count: widget.expenses.length),
          const SizedBox(height: 24),
          Text(
            '消费分类',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ExpensePieChart(
            categories: categories,
            colors: colors,
            total: total,
            selectedIndex: _selectedIndex,
            onTouched: _toggleSelect,
          ),
          const SizedBox(height: 16),
          ExpenseCategoryList(
            categories: categories,
            colors: colors,
            selectedIndex: _selectedIndex,
            onTap: _toggleSelect,
          ),
          if (hasSelection && selectedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('查看$selectedLabel对应消费记录'),
                  onPressed: () =>
                      _openCategoryRecords(_selectedIndex!, selectedKey!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
