import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/dict_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../life/models/expense_model.dart';
import '../../../../utils/date_time_utils.dart';

/// 添加支出底部弹窗
///
/// 用于快速记录一笔支出，包括金额、分类、描述与日期。
class AddExpenseSheet extends StatefulWidget {
  final Function(ExpenseModel) onSave;

  const AddExpenseSheet({super.key, required this.onSave});

  @override
  State<AddExpenseSheet> createState() => AddExpenseSheetState();
}

class AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategoryCode = '';
  DateTime _selectedDate = DateTime.now();
  bool _isDictLoading = true;
  bool _isSaving = false;

  /// 获取支出分类选项列表（从字典服务）
  List<String> get _categoryCodes {
    return DictService.instance.getItemsSync('expense_category').map((e) => e.code).toList();
  }

  @override
  void initState() {
    super.initState();
    _initDict();
    // 监听字典刷新
    DictService.instance.refreshNotifier.addListener(_onDictRefresh);
  }

  Future<void> _initDict() async {
    await DictService.instance.initialize();
    _selectedCategoryCode = DictService.instance.getDefaultCode('expense_category');
    if (_selectedCategoryCode.isEmpty && _categoryCodes.isNotEmpty) {
      _selectedCategoryCode = _categoryCodes.first;
    }
    if (mounted) {
      setState(() => _isDictLoading = false);
    }
  }

  void _onDictRefresh() {
    if (mounted) {
      setState(() {
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
      final expense = ExpenseModel(
        id: const Uuid().v4(),
        userId: AuthService.instance.currentUserId ?? 'local_user',
        amount: double.parse(_amountController.text),
        category: _selectedCategoryCode,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        date: _selectedDate,
      );

      widget.onSave(expense);
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
            Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            Text('分类', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            if (_isDictLoading)
              const Center(child: CircularProgressIndicator())
            else
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}
