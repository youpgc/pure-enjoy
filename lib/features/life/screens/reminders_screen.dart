import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/cache_helper.dart';
import '../models/reminder_model.dart';

/// 提醒页面 - Supabase 数据同步
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    await _loadCache();
    await _loadReminders();
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyReminders);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _reminders = cached.map((e) => ReminderModel.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReminders() async {
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

    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/reminders?user_id=eq.$userId&select=*&order=date_time.asc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final reminders = data.map((e) => ReminderModel.fromJson(e)).toList();

        setState(() {
          _reminders = reminders;
          _isLoading = false;
        });

        // 写入缓存
        await CacheHelper.instance.saveList(
          CacheHelper.keyReminders,
          reminders.map((r) => r.toJson()).toList(),
        );
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

  Future<void> _addReminder(ReminderModel reminder) async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/reminders'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode(reminder.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _updateReminder(ReminderModel reminder) async {
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/reminders?id=eq.${reminder.id}'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({
          'title': reminder.title,
          'date_time': reminder.dateTime.toIso8601String(),
          'repeat_type': reminder.repeatType,
          'category': reminder.category,
          'note': reminder.note,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条提醒吗？'),
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
      try {
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/reminders?id=eq.$id'),
          headers: SupabaseConfig.writeHeaders,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          await _loadReminders();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleComplete(ReminderModel reminder) async {
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/reminders?id=eq.${reminder.id}'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({'is_completed': !reminder.isCompleted}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(reminder.isCompleted ? '已标记为未完成' : '已标记为完成')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _showReminderForm([ReminderModel? reminder]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReminderForm(
        userId: _userId ?? 'local_user',
        reminder: reminder,
        onSave: (newReminder) {
          Navigator.pop(context);
          if (reminder != null) {
            _updateReminder(newReminder);
          } else {
            _addReminder(newReminder);
          }
        },
      ),
    );
  }

  List<ReminderModel> get _filteredReminders {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'upcoming':
        return _reminders.where((r) => r.dateTime.isAfter(now)).toList();
      case 'completed':
        return _reminders.where((r) => r.isCompleted).toList();
      case 'overdue':
        return _reminders.where((r) => r.dateTime.isBefore(now) && !r.isCompleted).toList();
      default:
        return _reminders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒'),
      ),
      body: Column(
        children: [
          // 筛选栏
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: '全部',
                  isSelected: _selectedFilter == 'all',
                  onTap: () => setState(() => _selectedFilter = 'all'),
                ),
                _FilterChip(
                  label: '待办',
                  isSelected: _selectedFilter == 'upcoming',
                  onTap: () => setState(() => _selectedFilter = 'upcoming'),
                ),
                _FilterChip(
                  label: '已完成',
                  isSelected: _selectedFilter == 'completed',
                  onTap: () => setState(() => _selectedFilter = 'completed'),
                ),
                _FilterChip(
                  label: '已过期',
                  isSelected: _selectedFilter == 'overdue',
                  onTap: () => setState(() => _selectedFilter = 'overdue'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 提醒列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReminders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无提醒',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReminders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredReminders.length,
                          itemBuilder: (context, index) {
                            final reminder = _filteredReminders[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Checkbox(
                                  value: reminder.isCompleted,
                                  onChanged: (_) => _toggleComplete(reminder),
                                ),
                                title: Text(
                                  reminder.title,
                                  style: TextStyle(
                                    decoration: reminder.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: reminder.isCompleted
                                        ? colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_formatDateTime(reminder.dateTime)}${reminder.note != null ? ' - ${reminder.note}' : ''}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showReminderForm(reminder);
                                        break;
                                      case 'delete':
                                        _deleteReminder(reminder.id);
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
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReminderForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ReminderForm extends StatefulWidget {
  final String userId;
  final ReminderModel? reminder;
  final Function(ReminderModel) onSave;

  const _ReminderForm({required this.userId, this.reminder, required this.onSave});

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDateTime;
  late String _selectedRepeatType;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _titleController.text = reminder?.title ?? '';
    _noteController.text = reminder?.note ?? '';
    _selectedDateTime = reminder?.dateTime ?? DateTime.now().add(const Duration(hours: 1));
    _selectedRepeatType = reminder?.repeatType ?? 'none';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newReminder = ReminderModel(
      id: widget.reminder?.id ?? const Uuid().v4(),
      userId: widget.userId,
      title: _titleController.text,
      dateTime: _selectedDateTime,
      repeatType: _selectedRepeatType,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    widget.onSave(newReminder);
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
              '添加提醒',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入标题';
                return null;
              },
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期时间'),
              trailing: Text(
                '${_selectedDateTime.year}-${_selectedDateTime.month.toString().padLeft(2, '0')}-${_selectedDateTime.day.toString().padLeft(2, '0')} '
                '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDateTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _selectedDateTime = DateTime(
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
            const SizedBox(height: 16),

            Text('重复', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['none', 'daily', 'weekly', 'monthly'].map((type) => ChoiceChip(
                label: Text(_getRepeatLabel(type)),
                selected: _selectedRepeatType == type,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedRepeatType = type);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
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

  String _getRepeatLabel(String type) {
    switch (type) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '不重复';
    }
  }
}
