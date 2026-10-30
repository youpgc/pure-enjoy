import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../services/dict_service.dart';
import '../../models/expense_model.dart';
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
    required this.selectedType,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
    required this.onSelectType,
  });

  final List<Map<String, dynamic>> expenses;
  final bool isLoading;
  final String error;
  final DateTime startMonth;
  final DateTime endMonth;
  final String rangeText;

  /// 当前统计类型：expense=支出 / income=收入
  final String selectedType;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;
  final ValueChanged<String> onSelectType;

  /// 类型对应的分类字典码：支出→expense_category，收入→income_category
  String get _dictCode =>
      selectedType == ExpenseModel.typeIncome ? 'income_category' : 'expense_category';

  /// 类型中文名：支出 / 收入
  String get _typeLabel =>
      selectedType == ExpenseModel.typeIncome ? '收入' : '支出';

  @override
  Widget build(BuildContext context) {
    // 收支切换常驻顶部：空态/加载态/错误态下也保留切换入口，避免无数据时被锁死在当前类型
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: ExpenseModel.typeExpense,
                icon: Icon(Icons.remove_circle_outline),
                label: Text('支出'),
              ),
              ButtonSegment(
                value: ExpenseModel.typeIncome,
                icon: Icon(Icons.add_circle_outline),
                label: Text('收入'),
              ),
            ],
            selected: {selectedType},
            onSelectionChanged: (selection) => onSelectType(selection.first),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }
    if (error.isNotEmpty) {
      return Center(child: Text(error));
    }
    if (expenses.isEmpty) {
      return ExpenseEmptyState(
        rangeText: rangeText,
        typeLabel: _typeLabel,
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
      selectedType: selectedType,
      dictCode: _dictCode,
      typeLabel: _typeLabel,
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
    required this.selectedType,
    required this.dictCode,
    required this.typeLabel,
    required this.onPickStartMonth,
    required this.onPickEndMonth,
  });

  final List<Map<String, dynamic>> expenses;
  final DateTime startMonth;
  final DateTime endMonth;
  final String rangeText;
  final String selectedType;
  final String dictCode;
  final String typeLabel;
  final VoidCallback onPickStartMonth;
  final VoidCallback onPickEndMonth;

  @override
  State<_ExpenseStatisticsLoaded> createState() => _ExpenseStatisticsLoadedState();
}

class _ExpenseStatisticsLoadedState extends State<_ExpenseStatisticsLoaded> {
  /// 当前选中的分类下标；null 表示未选中（展示总额）。
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _ExpenseStatisticsLoaded oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 类型切换后分类集合整体变化，清除残留选中态，避免高亮指向新类型下的错误分类
    if (widget.selectedType != oldWidget.selectedType) {
      _selectedIndex = null;
    }
  }

  /// 点击扇区/分类：仅切换选中态（放大 + 中心明细 + 列表高亮），再次点击取消。
  /// 跳转由下方「查看对应消费记录」按钮触发，避免选中态被跳转吞掉（闭环修复 缺口2）。
  void _toggleSelect(int index) {
    setState(() => _selectedIndex = _selectedIndex == index ? null : index);
  }

  /// 跳转至该分类在统计区间内的记录列表（只读明细模式，携带当前收支类型）。
  void _openCategoryRecords(int index, String categoryKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseListScreen(
          initialCategory: categoryKey,
          initialType: widget.selectedType,
          initialStartMonth: widget.startMonth,
          initialEndMonth: widget.endMonth,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 按分类统计（数据已按当前收支类型在查询层过滤）
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
            widget.dictCode,
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
          ExpenseTotalCard(
            total: total,
            count: widget.expenses.length,
            isIncome: widget.selectedType == ExpenseModel.typeIncome,
          ),
          const SizedBox(height: 24),
          Text(
            '${widget.typeLabel}分类',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ExpensePieChart(
            categories: categories,
            colors: colors,
            total: total,
            totalLabel: '${widget.typeLabel}总额',
            dictCode: widget.dictCode,
            selectedIndex: _selectedIndex,
            onTouched: _toggleSelect,
          ),
          const SizedBox(height: 16),
          ExpenseCategoryList(
            categories: categories,
            colors: colors,
            dictCode: widget.dictCode,
            selectedIndex: _selectedIndex,
            onTap: _toggleSelect,
          ),
          if (hasSelection && selectedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('查看$selectedLabel对应${widget.typeLabel}记录'),
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
