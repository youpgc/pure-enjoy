import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/weight_record_model.dart';

/// 体重记录页面
class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({super.key});

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  List<WeightRecordModel> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('weight_records') ?? [];
      
      final records = recordsJson
          .map((json) => WeightRecordModel.fromJson(jsonDecode(json)))
          .toList();
      
      records.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _records = records.length > 30 ? records.sublist(0, 30) : records;
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

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = _records
        .map((record) => jsonEncode(record.toJson()))
        .toList();
    await prefs.setStringList('weight_records', recordsJson);
  }

  Future<void> _deleteRecord(WeightRecordModel record) async {
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
        _records.removeWhere((r) => r.id == record.id);
      });
      await _saveRecords();
    }
  }

  void _showRecordForm([WeightRecordModel? record]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordForm(
        record: record,
        onSave: () {
          Navigator.pop(context);
          _loadRecords();
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
                                title: Text(
                                  '${record.weight.toStringAsFixed(1)} kg',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  DateFormat('yyyy-MM-dd').format(record.date),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (record.note != null)
                                      Icon(
                                        Icons.note,
                                        size: 16,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showRecordForm(record),
                                    ),
                                  ],
                                ),
                                onLongPress: () => _deleteRecord(record),
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
  final WeightRecordModel? record;
  final VoidCallback onSave;

  const _RecordForm({this.record, required this.onSave});

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _weightController.text = widget.record!.weight.toString();
      _noteController.text = widget.record!.note ?? '';
      _selectedDate = widget.record!.date;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('weight_records') ?? [];
    
    final newRecord = WeightRecordModel(
      id: widget.record?.id ?? 'weight_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'local_user',
      weight: double.parse(_weightController.text),
      note: _noteController.text.isEmpty ? null : _noteController.text,
      date: _selectedDate,
      createdAt: widget.record?.createdAt ?? DateTime.now(),
    );
    
    // 更新或添加记录
    final existingIndex = recordsJson.indexWhere((json) {
      final record = WeightRecordModel.fromJson(jsonDecode(json));
      return record.id == newRecord.id;
    });
    
    if (existingIndex >= 0) {
      recordsJson[existingIndex] = jsonEncode(newRecord.toJson());
    } else {
      recordsJson.add(jsonEncode(newRecord.toJson()));
    }
    
    await prefs.setStringList('weight_records', recordsJson);
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
              widget.record != null ? '编辑记录' : '添加记录',
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
            
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
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
