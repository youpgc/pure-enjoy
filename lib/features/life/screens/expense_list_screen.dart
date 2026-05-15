import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';

/// 支出列表页面
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getStringList('expenses') ?? [];
      
      var expenses = expensesJson
          .map((json) => ExpenseModel.fromJson(jsonDecode(json)))
          .toList();
      
      // 按月份筛选
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      expenses = expenses.where((e) {
        return e.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
               e.date.isBefore(endOfMonth.add(const Duration(days: 1)));
      }).toList();
      
      // 按分类筛选
      if (_selectedCategory != 'all') {
        expenses = expenses.where((e) => e.category == _selectedCategory).toList();
      }
      
      expenses.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = _expenses
        .map((expense) => jsonEncode(expense.toJson()))
        .toList();
    await prefs.setStringList('expenses', expensesJson);
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _expenses.removeWhere((e) => e.id == expense.id);
      });
      await _saveExpenses();
    }
  }

  void _showExpenseForm([ExpenseModel? expense]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseForm(
        expense: expense,
        onSave: () {
          Navigator.pop(context);
          _loadExpenses();
        },
      ),
    );
  }

  double get _totalAmount {
    return _expenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账'),
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
                setState(() => _selectedMonth = picked);
                _loadExpenses();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('yyyy年MM月').format(_selectedMonth),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '总支出: ¥${_totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // 分类筛选
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: '全部',
                  isSelected: _selectedCategory == 'all',
                  onTap: () {
                    setState(() => _selectedCategory = 'all');
                    _loadExpenses();
                  },
                ),
                ...ExpenseCategory.values.map((cat) => _CategoryChip(
                  label: cat.label,
                  isSelected: _selectedCategory == cat.name,
                  onTap: () {
                    setState(() => _selectedCategory = cat.name);
                    _loadExpenses();
                  },
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // 支出列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(child: Text('暂无记录'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
                          final category = ExpenseCategory.values.firstWhere(
                            (c) => c.name == expense.category,
                            orElse: () => ExpenseCategory.other,
                          );
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(category.icon),
                              title: Text(category.label),
                              subtitle: Text(
                                DateFormat('MM-dd HH:mm').format(expense.date),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '¥${expense.amount.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showExpenseForm(expense),
                                  ),
                                ],
                              ),
                              onLongPress: () => _deleteExpense(expense),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  final ExpenseModel? expense;
  final VoidCallback onSave;

  const _ExpenseForm({this.expense, required this.onSave});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toString();
      _descriptionController.text = widget.expense!.description ?? '';
      _selectedCategory = ExpenseCategory.values.firstWhere(
        (c) => c.name == widget.expense!.category,
        orElse: () => ExpenseCategory.food,
      );
      _selectedDate = widget.expense!.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];
    
    final newExpense = ExpenseModel(
      id: widget.expense?.id ?? 'expense_${DateTime.now().millisecondsSinceEpoch}',
      amount: double.parse(_amountController.text),
      category: _selectedCategory.name,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      date: _selectedDate,
    );
    
    // 更新或添加支出
    final existingIndex = expensesJson.indexWhere((json) {
      final expense = ExpenseModel.fromJson(jsonDecode(json));
      return expense.id == newExpense.id;
    });
    
    if (existingIndex >= 0) {
      expensesJson[existingIndex] = jsonEncode(newExpense.toJson());
    } else {
      expensesJson.add(jsonEncode(newExpense.toJson()));
    }
    
    await prefs.setStringList('expenses', expensesJson);
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.expense != null ? '编辑支出' : '添加支出',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // 金额输入
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入金额';
                if (double.tryParse(value) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 分类选择
            Text('分类', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ExpenseCategory.values.map((cat) => ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 16),
                    const SizedBox(width: 4),
                    Text(cat.label),
                  ],
                ),
                selected: _selectedCategory == cat,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
            
            // 备注
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
            ),
            const SizedBox(height: 16),
            
            // 日期选择
            ListTile(
              title: const Text('日期'),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),
            
            FilledButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
