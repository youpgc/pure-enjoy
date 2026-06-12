import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<Map<String, dynamic>> _habits = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'habits',
        filters: {'user_id': 'eq.$_userId'},
        order: 'created_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _habits = result.data!;
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

  Future<void> _addHabit() async {
    if (_userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _HabitDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'habits',
          body: {
            ...result,
            'user_id': _userId,
          },
        );

        if (insertResult.isSuccess) {
          _loadHabits();
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

  Future<void> _checkInHabit(String id) async {
    try {
      final result = await ApiClient.patch(
        'habits',
        filters: {'id': 'eq.$id'},
        body: {
          'last_check_in': DateTime.now().toUtc().toIso8601String(),
          'check_in_count': (_habits.firstWhere((h) => h['id'] == id)['check_in_count'] as int? ?? 0) + 1,
        },
      );

      if (result.isSuccess) {
        _loadHabits();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('打卡失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打卡失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteHabit(String id) async {
    try {
      final result = await ApiClient.delete(
        'habits',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadHabits();
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
        title: const Text('习惯打卡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addHabit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? const Center(child: Text('暂无习惯'))
              : ListView.builder(
                  itemCount: _habits.length,
                  itemBuilder: (context, index) {
                    final habit = _habits[index];
                    final lastCheckIn = habit['last_check_in'] != null
                        ? DateTime.parse(habit['last_check_in'])
                        : null;
                    final isCheckedToday = lastCheckIn != null &&
                        DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day) ==
                            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

                    return Dismissible(
                      key: Key(habit['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteHabit(habit['id']),
                      child: ListTile(
                        leading: Icon(
                          isCheckedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCheckedToday ? Colors.green : Colors.grey,
                        ),
                        title: Text(habit['name'] ?? '无名称'),
                        subtitle: Text('连续打卡 ${habit['check_in_count'] ?? 0} 天'),
                        trailing: isCheckedToday
                            ? const Text('已打卡', style: TextStyle(color: Colors.green))
                            : TextButton(
                                onPressed: () => _checkInHabit(habit['id']),
                                child: const Text('打卡'),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _HabitDialog extends StatefulWidget {
  const _HabitDialog();

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加习惯'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: '习惯名称',
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
              'check_in_count': 0,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
