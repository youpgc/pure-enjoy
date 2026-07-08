import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/dict_service.dart';
import '../../../utils/date_time_utils.dart';
import '../models/expense_model.dart';
import '../widgets/app_date_picker.dart';

/// 支出表单组件（底部弹窗用）
class ExpenseForm extends StatefulWidget {
  final String userId;
  final ExpenseModel? expense;
  final Function(ExpenseModel) onSave;

  const ExpenseForm({
    super.key,
    required this.userId,
    this.expense,
    required this.onSave,
  });

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _noteController;
  String _selectedCategoryCode = '';
  late DateTime _selectedDate;
  bool _isSaving = false;

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

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
                final picked = await AppDatePicker.show(
                  context,
                  type: DateTimeType.date,
                  initialDate: _selectedDate,
                  minDate: DateTime(2020),
                  maxDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
