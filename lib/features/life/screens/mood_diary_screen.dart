import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => _MoodDiaryScreenState();
}

class _MoodDiaryScreenState extends State<MoodDiaryScreen> {
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
        'mood_records',
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
      builder: (context) => const _MoodDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'mood_records',
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
        'mood_records',
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
        title: const Text('心情日记'),
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
                        leading: _buildMoodIcon(record['mood_level']),
                        title: Text(record['note'] ?? '无备注'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(date),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildMoodIcon(int? level) {
    final icon = switch (level) {
      1 => Icons.sentiment_very_dissatisfied,
      2 => Icons.sentiment_dissatisfied,
      3 => Icons.sentiment_neutral,
      4 => Icons.sentiment_satisfied,
      5 => Icons.sentiment_very_satisfied,
      _ => Icons.sentiment_neutral,
    };

    final color = switch (level) {
      1 => Colors.red,
      2 => Colors.orange,
      3 => Colors.yellow,
      4 => Colors.lightGreen,
      5 => Colors.green,
      _ => Colors.grey,
    };

    return Icon(icon, color: color, size: 32);
  }
}

class _MoodDialog extends StatefulWidget {
  const _MoodDialog();

  @override
  State<_MoodDialog> createState() => _MoodDialogState();
}

class _MoodDialogState extends State<_MoodDialog> {
  int _moodLevel = 3;
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记录心情'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    icon: Icon(
                      i <= _moodLevel
                          ? Icons.sentiment_very_satisfied
                          : Icons.sentiment_very_satisfied_outlined,
                      color: i <= _moodLevel ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => setState(() => _moodLevel = i),
                  ),
              ],
            ),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '今天发生了什么...',
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
            Navigator.pop(context, {
              'mood_level': _moodLevel,
              'note': _noteController.text,
              'date': DateFormat('yyyy-MM-dd').format(_date),
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
