import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/app_date_picker.dart';

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
  DateTime _startMonth = DateTime.now();
  DateTime _endMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startMonth = DateTime.now();
    _endMonth = DateTime.now();
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
      final startOfRange = DateTime(_startMonth.year, _startMonth.month, 1);
      final firstOfNextMonth = DateTime(_endMonth.year, _endMonth.month + 1, 1);

      final result = await ApiClient.get(
        'expenses',
        filters: {
          'user_id': 'eq.$userId',
          'and': '(date.gte.${DateFormat('yyyy-MM-dd').format(startOfRange)},date.lt.${DateFormat('yyyy-MM-dd').format(firstOfNextMonth)})',
        },
        order: 'date.desc',
        limit: 500,
      );

      if (!mounted) return;
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
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickStartMonth() async {
    final picked = await AppDatePicker.show(
      context,
      type: DateTimeType.yearMonth,
      initialDate: _startMonth,
      minDate: DateTime(2020),
      maxDate: DateTime.now(),
      title: '选择起始月份',
    );
    if (picked != null) {
      final newStart = DateTime(picked.year, picked.month);
      // 限制最多6个月
      final maxEnd = DateTime(newStart.year, newStart.month + 6, 0);
      setState(() {
        _startMonth = newStart;
        if (_endMonth.isBefore(_startMonth)) {
          _endMonth = _startMonth;
        } else if (_endMonth.isAfter(maxEnd)) {
          _endMonth = maxEnd;
        }
        _isLoading = true;
      });
      _loadData();
    }
  }

  Future<void> _pickEndMonth() async {
    final picked = await AppDatePicker.show(
      context,
      type: DateTimeType.yearMonth,
      initialDate: _endMonth,
      minDate: DateTime(2020),
      maxDate: DateTime.now(),
      title: '选择结束月份',
    );
    if (picked != null) {
      final newEnd = DateTime(picked.year, picked.month);
      // 限制最多6个月
      final minStart = DateTime(newEnd.year, newEnd.month - 5, 1);
      setState(() {
        _endMonth = newEnd;
        if (_startMonth.isAfter(_endMonth)) {
          _startMonth = _endMonth;
        } else if (_startMonth.isBefore(minStart)) {
          _startMonth = minStart;
        }
        _isLoading = true;
      });
      _loadData();
    }
  }

  String get _rangeText {
    final sameYear = _startMonth.year == _endMonth.year;
    if (_startMonth.year == _endMonth.year && _startMonth.month == _endMonth.month) {
      return '${_startMonth.year}年${_startMonth.month}月';
    }
    if (sameYear) {
      return '${_startMonth.year}年${_startMonth.month}月 - ${_endMonth.month}月';
    }
    return '${_startMonth.year}年${_startMonth.month}月 - ${_endMonth.year}年${_endMonth.month}月';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消费统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '选择时间区间',
            onPressed: () async {
              await _pickStartMonth();
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
              '$_rangeText暂无消费记录',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // 时间区间选择按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickStartMonth,
                  icon: const Icon(Icons.date_range),
                  label: Text('${_startMonth.year}-${_startMonth.month.toString().padLeft(2, '0')}'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickEndMonth,
                  icon: const Icon(Icons.date_range),
                  label: Text('${_endMonth.year}-${_endMonth.month.toString().padLeft(2, '0')}'),
                ),
              ],
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
          // 时间区间标题与选择
          Center(
            child: Column(
              children: [
                Text(
                  _rangeText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickStartMonth,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text('${_startMonth.year}-${_startMonth.month.toString().padLeft(2, '0')}'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('至'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickEndMonth,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text('${_endMonth.year}-${_endMonth.month.toString().padLeft(2, '0')}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 总消费
          Card(
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
