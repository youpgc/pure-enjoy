import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../models/weight_record_model.dart';

/// 体重记录页面 - Supabase 数据同步
class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({super.key});

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  List<WeightRecordModel> _records = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
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

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/weight_records?user_id=eq.$userId&select=*&order=date.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final records = data.map((e) => WeightRecordModel.fromJson(e)).toList();

        setState(() {
          _records = records.length > 30 ? records.sublist(0, 30) : records;
          _isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
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

  Future<void> _createWeightRecord(WeightRecordModel record) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/weight_records'),
        headers: SupabaseConfig.headers,
        body: jsonEncode(record.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteWeightRecord(String id) async {
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
      setState(() => _isLoading = true);
      try {
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/weight_records?id=eq.$id'),
          headers: SupabaseConfig.headers,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          await _loadRecords();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateWeightRecord(WeightRecordModel record) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/weight_records?id=eq.${record.id}'),
        headers: SupabaseConfig.headers,
        body: jsonEncode({
          'weight': record.weight,
          'bmi': record.bmi,
          'body_fat': record.bodyFat,
          'note': record.note,
          'date': record.date.toIso8601String().split('T').first,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  void _showEditRecordForm(WeightRecordModel record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordForm(
        userId: _userId ?? 'local_user',
        record: record,
        onSave: (updatedRecord) {
          Navigator.pop(context);
          _updateWeightRecord(updatedRecord);
        },
      ),
    );
  }

  void _showRecordForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordForm(
        userId: _userId ?? 'local_user',
        onSave: (newRecord) {
          Navigator.pop(context);
          _createWeightRecord(newRecord);
        },
      ),
    );
  }

  double? get _latestWeight => _records.isNotEmpty ? _records.first.weight : null;
  double? get _previousWeight => _records.length > 1 ? _records[1].weight : null;
  double? get _weightChange {
    if (_latestWeight == null || _previousWeight == null) return null;
    return _latestWeight! - _previousWeight!;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('体重记录'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前体重卡片
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            '当前体重',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _latestWeight != null
                                ? '${_latestWeight!.toStringAsFixed(1)} kg'
                                : '-- kg',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          if (_weightChange != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _weightChange! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16,
                                  color: _weightChange! > 0 ? colorScheme.error : colorScheme.primary,
                                ),
                                Text(
                                  '${_weightChange!.abs().toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    color: _weightChange! > 0 ? colorScheme.error : colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 记录列表
                  Text(
                    '历史记录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _records.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('暂无记录'),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.monitor_weight),
                                title: Row(
                                  children: [
                                    Text(
                                      '${record.weight.toStringAsFixed(1)} kg',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (record.bodyFat != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        '体脂 ${record.bodyFat!.toStringAsFixed(1)}%',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (record.bmi != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        'BMI ${record.bmi!.toStringAsFixed(1)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('yyyy-MM-dd').format(record.date)),
                                    if (record.note != null && record.note!.isNotEmpty)
                                      Text(
                                        record.note!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showEditRecordForm(record);
                                        break;
                                      case 'delete':
                                        _deleteWeightRecord(record.id);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('编辑'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('删除', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordForm extends StatefulWidget {
  final String userId;
  final WeightRecordModel? record;
  final Function(WeightRecordModel) onSave;

  const _RecordForm({required this.userId, this.record, required this.onSave});

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _bmiController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;

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
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _bmiController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

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
