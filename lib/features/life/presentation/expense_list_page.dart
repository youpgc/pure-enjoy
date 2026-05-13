import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';
import '../data/expense_model.dart';

/// 消费记录列表页面
class ExpenseListPage extends ConsumerStatefulWidget {
  const ExpenseListPage({super.key});

  @override
  ConsumerState<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends ConsumerState<ExpenseListPage> {
  List<ExpenseModel> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    final box = StorageService().expenseBox;
    setState(() {
      _expenses = box.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  double get _totalAmount {
    return _expenses.fold(0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消费记录'),
      ),
      body: Column(
        children: [
          // 统计卡片
          _buildStatsCard(),
          // 列表
          Expanded(
            child: _expenses.isEmpty
                ? _buildEmptyState()
                : _buildExpenseList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月消费',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥ ${_totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '共 ${_expenses.length} 笔记录',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有消费记录',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角添加第一笔记录',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(expense.category),
                color: AppTheme.primaryColor,
              ),
            ),
            title: Text(expense.category),
            subtitle: Text(
              DateFormat('MM-dd HH:mm').format(expense.date),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: Text(
              '-¥${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
            onLongPress: () => _deleteExpense(expense),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '餐饮': return Icons.restaurant;
      case '交通': return Icons.directions_car;
      case '购物': return Icons.shopping_bag;
      case '居住': return Icons.home;
      case '医疗': return Icons.local_hospital;
      case '教育': return Icons.school;
      case '娱乐': return Icons.movie;
      case '通讯': return Icons.phone;
      default: return Icons.attach_money;
    }
  }

  void _showAddDialog() {
    final amountController = TextEditingController();
    String selectedCategory = AppConstants.expenseCategories.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加消费记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '金额',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: '分类',
              ),
              items: AppConstants.expenseCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedCategory = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                final expense = ExpenseModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  amount: amount,
                  category: selectedCategory,
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                await StorageService().expenseBox.put(expense.id, expense);
                SyncService().uploadExpense(expense); // 同步到云端
                Navigator.pop(context);
                _loadExpenses();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条消费记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await StorageService().expenseBox.delete(expense.id);
              SyncService().deleteRemote('expenses', expense.id); // 从云端删除
              Navigator.pop(context);
              _loadExpenses();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
