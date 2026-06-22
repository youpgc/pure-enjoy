import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// 消费统计页面
class ExpenseStatisticsScreen extends StatefulWidget {
  const ExpenseStatisticsScreen({super.key});

  @override
  State<ExpenseStatisticsScreen> createState() => _ExpenseStatisticsScreenState();
}

class _ExpenseStatisticsScreenState extends State<ExpenseStatisticsScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _error = '';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = AuthService.instance.currentUserId;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '请先登录';
      });
      return;
    }

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      final result = await ApiClient.get(
        'expenses',
        filters: {
          'user_id': 'eq.$userId',
          'and': '(date.gte.${DateFormat('yyyy-MM-dd').format(startOfMonth)},date.lte.${DateFormat('yyyy-MM-dd').format(endOfMonth)})',
        },
        order: 'date.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        final List<dynamic> data = result.data!;
        setState(() {
          _expenses = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消费统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedMonth = picked;
                  _isLoading = true;
                });
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '${_selectedMonth.year}年${_selectedMonth.month}月暂无消费记录',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 按分类统计
    final categoryMap = <String, double>{};
    double total = 0;
    for (var expense in _expenses) {
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
          // 月份标题
          Center(
            child: Text(
              '${_selectedMonth.year}年${_selectedMonth.month}月',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),

          // 本月总消费
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '本月消费',
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
                    '${_expenses.length} 笔消费',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 分类饼图
          Text(
            '消费分类',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
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
          ),
          const SizedBox(height: 16),

          // 分类列表
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final categoryLabel = DictService.instance.getLabelOrDefault('expense_category', category.key, defaultValue: category.key);
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
          }),
        ],
      ),
    );
  }
}
