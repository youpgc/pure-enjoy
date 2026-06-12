import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({super.key});

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'weight_records',
        filters: {'user_id': 'eq.$_userId'},
        order: 'date.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _records = result.data!;
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

  Future<void> _addRecord() async {
    if (_userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _WeightDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'weight_records',
          body: {
            ...result,
            'user_id': _userId,
          },
        );

        if (insertResult.isSuccess) {
          _loadRecords();
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

  Future<void> _deleteRecord(String id) async {
    try {
      final result = await ApiClient.delete(
        'weight_records',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadRecords();
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
        title: const Text('体重记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addRecord,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(child: Text('暂无记录'))
              : ListView.builder(
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final date = DateTime.parse(record['date']);
                    return Dismissible(
                      key: Key(record['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteRecord(record['id']),
                      child: ListTile(
                        leading: const Icon(Icons.monitor_weight),
                        title: Text('${record['weight']} kg'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(date),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog();

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  final _weightController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记录体重'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '体重 (kg)',
              ),
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
            if (_weightController.text.isEmpty) return;
            Navigator.pop(context, {
              'weight': double.parse(_weightController.text),
              'date': DateFormat('yyyy-MM-dd').format(_date),
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
