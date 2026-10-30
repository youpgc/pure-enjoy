import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/dict_service.dart';
import '../../../utils/date_time_utils.dart';
import '../models/expense_model.dart';
import './app_date_picker.dart';
import '../../../core/widgets/widgets.dart';

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
  String _selectedType = ExpenseModel.typeExpense;
  String _selectedCategoryCode = '';
  late DateTime _selectedDate;

  bool get _isEditing => widget.expense != null;

  /// 当前类型对应的分类字典码：支出→expense_category，收入→income_category
  String get _dictCode =>
      _selectedType == ExpenseModel.typeIncome ? 'income_category' : 'expense_category';

  /// 获取当前类型下的分类选项列表（从字典服务）
  List<String> get _categoryCodes {
    return DictService.instance.getItemsSync(_dictCode).map((e) => e.code).toList();
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
    _selectedType = expense?.type ?? ExpenseModel.typeExpense;
    _selectedCategoryCode = expense?.category ?? DictService.instance.getDefaultCode(_dictCode);
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

  /// 切换收入/支出类型：分类字典随类型切换，选中分类重置为新字典的默认项（防空选）
  void _onTypeChanged(String type) {
    if (type == _selectedType) return;
    setState(() {
      _selectedType = type;
      _selectedCategoryCode = DictService.instance.getDefaultCode(_dictCode);
      if (_selectedCategoryCode.isEmpty && _categoryCodes.isNotEmpty) {
        _selectedCategoryCode = _categoryCodes.first;
      }
    });
  }

  @override
  void dispose() {
    DictService.instance.refreshNotifier.removeListener(_onDictRefresh);
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final newExpense = ExpenseModel(
        id: _isEditing ? widget.expense!.id : const Uuid().v4(),
        userId: _isEditing ? widget.expense!.userId : widget.userId,
        amount: double.parse(_amountController.text),
        category: _selectedCategoryCode,
        type: _selectedType,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        date: _selectedDate,
      );

      widget.onSave(newExpense);
  }

  @override
  Widget build(BuildContext context) {
    // SheetContainer：键盘避让 + 手势条 SafeArea + 滚动兜底（统一容器规范）
    return SheetContainer(
      maxHeightFactor: 0.85,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_isEditing ? '编辑' : '添加'}${_selectedType == ExpenseModel.typeIncome ? '收入' : '支出'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 收入/支出类型切换
            SegmentedButton<String>(
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
              selected: {_selectedType},
              onSelectionChanged: (selection) => _onTypeChanged(selection.first),
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

            // 分类选择（选项随收入/支出类型切换到对应字典）
            Text('分类', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categoryCodes.map((code) {
                final label = DictService.instance.getLabelOrDefault(_dictCode, code, defaultValue: code);
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

            AsyncSubmitButton(label: '保存', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
