import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class AnniversariesScreen extends StatefulWidget {
  const AnniversariesScreen({super.key});

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> {
  List<Map<String, dynamic>> _anniversaries = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadAnniversaries();
  }

  Future<void> _loadAnniversaries() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'anniversaries',
        filters: {'user_id': 'eq.$_userId'},
        order: 'date.asc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _anniversaries = result.data!;
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

  Future<void> _addAnniversary() async {
    if (_userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AnniversaryDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'anniversaries',
          body: {
            ...result,
            'user_id': _userId,
          },
        );

        if (insertResult.isSuccess) {
          _loadAnniversaries();
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

  Future<void> _deleteAnniversary(String id) async {
    try {
      final result = await ApiClient.delete(
        'anniversaries',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadAnniversaries();
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

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final nextDate = DateTime(now.year, date.month, date.day);
    if (nextDate.isBefore(now)) {
      return DateTime(now.year + 1, date.month, date.day).difference(now).inDays;
    }
    return nextDate.difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('纪念日'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addAnniversary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _anniversaries.isEmpty
              ? const Center(child: Text('暂无纪念日'))
              : ListView.builder(
                  itemCount: _anniversaries.length,
                  itemBuilder: (context, index) {
                    final anniversary = _anniversaries[index];
                    final date = DateTime.parse(anniversary['date']);
                    final days = _daysUntil(date);

                    return Dismissible(
                      key: Key(anniversary['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteAnniversary(anniversary['id']),
                      child: ListTile(
                        leading: const Icon(Icons.favorite),
                        title: Text(anniversary['name'] ?? '无名称'),
                        subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                        trailing: Text(
                          '$days 天后',
                          style: TextStyle(
                            color: days <= 7 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AnniversaryDialog extends StatefulWidget {
  const _AnniversaryDialog();

  @override
  State<_AnniversaryDialog> createState() => _AnniversaryDialogState();
}

class _AnniversaryDialogState extends State<_AnniversaryDialog> {
  final _nameController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加纪念日'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
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
                  firstDate: DateTime(1900),
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
            if (_nameController.text.isEmpty) return;
            Navigator.pop(context, {
              'name': _nameController.text,
              'date': DateFormat('yyyy-MM-dd').format(_date),
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
