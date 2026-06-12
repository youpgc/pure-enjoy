import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'reminders',
        filters: {'user_id': 'eq.$_userId'},
        order: 'reminder_time.asc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _reminders = result.data!;
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

  Future<void> _addReminder() async {
    if (_userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _ReminderDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'reminders',
          body: {
            ...result,
            'user_id': _userId,
          },
        );

        if (insertResult.isSuccess) {
          _loadReminders();
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

  Future<void> _toggleReminder(String id, bool isActive) async {
    try {
      final result = await ApiClient.patch(
        'reminders',
        filters: {'id': 'eq.$id'},
        body: {'is_active': !isActive},
      );

      if (result.isSuccess) {
        _loadReminders();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      final result = await ApiClient.delete(
        'reminders',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadReminders();
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
        title: const Text('提醒事项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addReminder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? const Center(child: Text('暂无提醒'))
              : ListView.builder(
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _reminders[index];
                    final time = DateTime.parse(reminder['reminder_time']);
                    final isActive = reminder['is_active'] ?? true;
                    return Dismissible(
                      key: Key(reminder['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteReminder(reminder['id']),
                      child: ListTile(
                        leading: Icon(
                          isActive ? Icons.alarm_on : Icons.alarm_off,
                          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        title: Text(reminder['title'] ?? '无标题'),
                        subtitle: Text(
                          DateFormat('MM-dd HH:mm').format(time),
                        ),
                        trailing: Switch(
                          value: isActive,
                          onChanged: (_) => _toggleReminder(reminder['id'], isActive),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog();

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _titleController = TextEditingController();
  DateTime _reminderTime = DateTime.now().add(const Duration(hours: 1));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加提醒'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('提醒时间'),
              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_reminderTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _reminderTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_reminderTime),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _reminderTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
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
            if (_titleController.text.isEmpty) return;
            Navigator.pop(context, {
              'title': _titleController.text,
              'reminder_time': _reminderTime.toUtc().toIso8601String(),
              'is_active': true,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
