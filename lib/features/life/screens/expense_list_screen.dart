import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../widgets/common_widgets.dart';
import '../models/expense_model.dart';

/// 支出列表页面 - Supabase 数据同步
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

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /// 初始化加载：先确保字典加载完成，再读缓存，最后静默刷新
  Future<void> _initLoad() async {
    try {
      await DictService.instance.initialize();
      await _loadCache();
      await _loadExpenses();
    } catch (e, stackTrace) {
      debugPrint('❌ ExpenseListScreen _initLoad 异常: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
      }
    }
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyExpenses);
    if (cached.isNotEmpty && mounted) {
      final allExpenses = cached.map((e) => ExpenseModel.fromJson(e)).toList();
      setState(() {
        _expenses = allExpenses;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExpenses() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final filters = <String, String>{
        'user_id': 'eq.$userId',
        'date.gte': startOfMonth.toIso8601String().split('T').first,
        'date.lt': endOfMonth.toIso8601String().split('T').first,
      };

      if (_selectedCategory != 'all') {
        filters['category'] = 'eq.$_selectedCategory';
      }

      final result = await ApiClient.get(
        'expenses',
        filters: filters,
        order: 'date.desc',
      );

      if (result.isSuccess) {
        final data = result.data!;
        var allExpenses = data.map((e) => ExpenseModel.fromJson(e)).toList();

        setState(() {
          _expenses = allExpenses;
          _isLoading = false;
        });

        // 写入缓存（保存全部数据，不按月筛选）
        await CacheHelper.instance.saveList(
          CacheHelper.keyExpenses,
          allExpenses.map((e) => e.toJson()).toList(),
        );
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _addExpense(ExpenseModel expense) async {
    try {
      final result = await ApiClient.post(
        'expenses',
        expense.toJson(),
      );

      if (result.isSuccess) {
        await _loadExpenses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这条记录吗？');

    if (confirm == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'expenses',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          await _loadExpenses();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${result.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateExpense(ExpenseModel expense) async {
    try {
      final result = await ApiClient.patchByFilter(
        'expenses',
        filters: {'id': 'eq.${expense.id}'},
        body: {
          'amount': expense.amount,
          'category': expense.category,
          'description': expense.description,
          'note': expense.note,
          'date': expense.date.toIso8601String().split('T').first,
        },
      );

      if (result.isSuccess) {
        await _loadExpenses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  void _showEditExpenseForm(ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseForm(
        userId: _userId ?? 'local_user',
        expense: expense,
        onSave: (updatedExpense) {
          Navigator.pop(context);
          _updateExpense(updatedExpense);
        },
      ),
    );
  }

  void _showExpenseForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseForm(
        userId: _userId ?? 'local_user',
        onSave: (newExpense) {
          Navigator.pop(context);
          _addExpense(newExpense);
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
                  '${_selectedMonth.year}年${_selectedMonth.month.toString().padLeft(2, '0')}月',
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
                CategoryChip(
                  label: '全部',
                  isSelected: _selectedCategory == 'all',
                  onTap: () {
                    setState(() => _selectedCategory = 'all');
                    _loadExpenses();
                  },
                ),
                ...DictService.instance.getItemsSync('expense_category').map((cat) => CategoryChip(
                  label: cat.label,
                  isSelected: _selectedCategory == cat.code,
                  onTap: () {
                    setState(() => _selectedCategory = cat.code);
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
                ? const LoadingWidget()
                : _expenses.isEmpty
                    ? const EmptyWidget(icon: Icons.receipt_long_outlined, message: '暂无记录')
                    : RefreshIndicator(
                        onRefresh: _loadExpenses,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            final categoryLabel = DictService.instance.getLabelOrDefault(
                              'expense_category',
                              expense.category,
                              defaultValue: expense.category,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.receipt),
                                title: Text(categoryLabel),
                                subtitle: Text(
                                  '${DateTimeUtils.formatStandard(expense.createdAt ?? expense.date)}${expense.description != null ? ' - ${expense.description}' : ''}',
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
                                    EditDeletePopupMenu(
                                      onEdit: () => _showEditExpenseForm(expense),
                                      onDelete: () => _deleteExpense(expense.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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

class _ExpenseForm extends StatefulWidget {
  final String userId;
  final ExpenseModel? expense;
  final Function(ExpenseModel) onSave;

  const _ExpenseForm({required this.userId, this.expense, required this.onSave});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _noteController;
  String _selectedCategoryCode = '';
  late DateTime _selectedDate;

  bool get _isEditing => widget.expense != null;

  /// 获取支出分类选项列表（从字典服务）
  List<String> get _categoryCodes {
    return DictService.instance.getItemsSync('expense_category').map((e) => e.code).toList();
  }

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amountController = TextEditingController(
      text: expense != null ? expense.amount.toString() : '',
    );
    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    _noteController = TextEditingController(
      text: expense?.note ?? '',
    );
    _selectedCategoryCode = expense?.category ?? DictService.instance.getDefaultCode('expense_category');
    if (_selectedCategoryCode.isEmpty && _categoryCodes.isNotEmpty) {
      _selectedCategoryCode = _categoryCodes.first;
    }
    _selectedDate = expense?.date ?? DateTime.now();
    // 监听字典刷新
    DictService.instance.refreshNotifier.addListener(_onDictRefresh);
  }

  void _onDictRefresh() {
    if (mounted) {
      setState(() {
        // 字典数据加载完成，刷新 UI
        if (_selectedCategoryCode.isEmpty && _categoryCodes.isNotEmpty) {
          _selectedCategoryCode = _categoryCodes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    DictService.instance.refreshNotifier.removeListener(_onDictRefresh);
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newExpense = ExpenseModel(
      id: _isEditing ? widget.expense!.id : const Uuid().v4(),
      userId: _isEditing ? widget.expense!.userId : widget.userId,
      amount: double.parse(_amountController.text),
      category: _selectedCategoryCode,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      date: _selectedDate,
    );

    widget.onSave(newExpense);
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
              '添加支出',
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
              children: _categoryCodes.map((code) {
                final label = DictService.instance.getLabelOrDefault('expense_category', code, defaultValue: code);
                return ChoiceChip(
                  label: Text(label),
                  selected: _selectedCategoryCode == code,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategoryCode = code);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 描述
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
              ),
            ),
            const SizedBox(height: 16),

            // 备注
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
            ),
            const SizedBox(height: 16),

            // 日期选择
            ListTile(
              title: const Text('日期'),
              trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
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
