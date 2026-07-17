import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/date_time_utils.dart';
import '../models/weight_record_model.dart';
import '../widgets/app_date_picker.dart';

/// 体重记录表单（新增/编辑），作为底部弹窗使用
class RecordForm extends StatefulWidget {
  final String userId;
  final WeightRecordModel? record;
  final Function(WeightRecordModel) onSave;

  // ignore: unused_element_parameter
  const RecordForm({super.key, required this.userId, this.record, required this.onSave});

  @override
  State<RecordForm> createState() => RecordFormState();
}

class RecordFormState extends State<RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _bmiController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  /// 用户身高（cm），用于自动计算 BMI/体脂率
  double? _userHeight;
  /// 用户年龄，用于计算体脂率
  int? _userAge;
  /// 用户性别，用于计算体脂率
  String? _userGender;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _weightController = TextEditingController(
      text: record != null ? record.weight.toString() : '',
    );
    _bodyFatController = TextEditingController(
      text: record?.bodyFat?.toString() ?? '',
    );
    _bmiController = TextEditingController(
      text: record?.bmi?.toString() ?? '',
    );
    _noteController = TextEditingController(
      text: record?.note ?? '',
    );
    _selectedDate = record?.date ?? DateTime.now();
    _loadUserProfile();
    _weightController.addListener(_autoCalculateMetrics);
  }

  /// 加载用户资料（身高、生日、性别），用于自动计算 BMI/体脂率
  Future<void> _loadUserProfile() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return;
      final result = await ApiClient.get(
        'users',
        filters: {ApiClient.userKey(userId): 'eq.$userId', 'is_deleted': 'eq.false'},
        limit: 1,
      );
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final user = result.data!.first;
        setState(() {
          _userHeight = user['height'] != null ? (user['height'] as num).toDouble() : null;
          _userGender = user['gender'] as String?;
          final birthdayStr = user['birthday'] as String?;
          if (birthdayStr != null && birthdayStr.isNotEmpty) {
            final birthday = DateTime.tryParse(birthdayStr);
            if (birthday != null) {
              final now = DateTime.now();
              _userAge = now.year - birthday.year;
              if (now.month < birthday.month ||
                  (now.month == birthday.month && now.day < birthday.day)) {
                _userAge = _userAge! - 1;
              }
            }
          }
        });
      }
    } catch (_) {
      // 静默失败，让用户手动维护
    }
  }

  /// 自动计算 BMI 和体脂率
  void _autoCalculateMetrics() {
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);
    final height = _userHeight;

    if (weight == null || weight <= 0 || height == null || height <= 0) return;

    // BMI = 体重(kg) / 身高(m)^2
    final heightInMeters = height / 100.0;
    final bmi = weight / (heightInMeters * heightInMeters);

    // 体脂率：基于 BMI，需要年龄和性别
    // 成年男性：1.2 * BMI + 0.23 * 年龄 - 16.2
    // 成年女性：1.2 * BMI + 0.23 * 年龄 - 5.4
    double? bodyFat;
    final age = _userAge;
    final gender = _userGender;
    if (age != null && age > 0 && gender != null && gender != '保密') {
      if (gender == '男') {
        bodyFat = 1.2 * bmi + 0.23 * age - 16.2;
      } else if (gender == '女') {
        bodyFat = 1.2 * bmi + 0.23 * age - 5.4;
      }
      if (bodyFat != null && bodyFat < 0) bodyFat = 0;
      if (bodyFat != null && bodyFat > 100) bodyFat = 100;
    }

    setState(() {
      _bmiController.text = bmi.toStringAsFixed(1);
      if (bodyFat != null) {
        _bodyFatController.text = bodyFat.toStringAsFixed(1);
      }
    });
  }

  @override
  void dispose() {
    _weightController.removeListener(_autoCalculateMetrics);
    _weightController.dispose();
    _bodyFatController.dispose();
    _bmiController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final newRecord = WeightRecordModel(
        id: _isEditing ? widget.record!.id : const Uuid().v4(),
        userId: _isEditing ? widget.record!.userId : widget.userId,
        weight: double.parse(_weightController.text),
        bmi: _bmiController.text.isNotEmpty ? double.tryParse(_bmiController.text) : null,
        bodyFat: _bodyFatController.text.isNotEmpty
            ? double.tryParse(_bodyFatController.text)
            : null,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        date: _selectedDate,
      );

      widget.onSave(newRecord);
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
              '添加记录',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '体重 (kg)',
                suffixText: 'kg',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入体重';
                if (double.tryParse(value) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '体脂率（可选）',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bmiController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'BMI（可选）',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '添加备注信息',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
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
