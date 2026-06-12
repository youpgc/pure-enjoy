import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  double _totalAmount = 0;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'expenses',
        filters: {'user_id': 'eq.$_userId'},
        order: 'date.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        final data = result.data!;
        double total = 0;
        for (final item in data) {
          total += (item['amount'] as num?)?.toDouble() ?? 0;
        }
        setState(() {
          _expenses = data;
          _totalAmount = total;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addExpense() async {
    if (_userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _ExpenseDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'expenses',
          body: {
            ...result,
            'user_id': _userId,
          },
        );

        if (insertResult.isSuccess) {
          _loadExpenses();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('添加失败: ${insertResult.errorMessage}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      final result = await ApiClient.delete(
        'expenses',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadExpenses();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addExpense,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 总支出卡片
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '总支出',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${_totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // 支出列表
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(child: Text('暂无记录'))
                      : ListView.builder(
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            final date = DateTime.parse(expense['date']);
                            return Dismissible(
                              key: Key(expense['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteExpense(expense['id']),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  child: Icon(
                                    _getCategoryIcon(expense['category']),
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                title: Text(expense['description'] ?? '未命名'),
                                subtitle: Text(
                                  DateFormat('MM-dd').format(date),
                                ),
                                trailing: Text(
                                  '-¥${(expense['amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_bus;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'housing':
        return Icons.home;
      default:
        return Icons.attach_money;
    }
  }
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'food';
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记一笔'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥',
              ),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: '分类',
              ),
              items: const [
                DropdownMenuItem(value: 'food', child: Text('餐饮')),
                DropdownMenuItem(value: 'transport', child: Text('交通')),
                DropdownMenuItem(value: 'shopping', child: Text('购物')),
                DropdownMenuItem(value: 'entertainment', child: Text('娱乐')),
                DropdownMenuItem(value: 'housing', child: Text('住房')),
                DropdownMenuItem(value: 'other', child: Text('其他')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_amountController.text.isEmpty) return;
            Navigator.pop(context, {
              'amount': double.parse(_amountController.text),
              'description': _descriptionController.text,
              'category': _category,
              'date': DateFormat('yyyy-MM-dd').format(_date),
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
