import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_model.dart';
import '../../../services/database_service.dart';
import '../../../services/supabase_service.dart';

/// 提醒事项页面
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, completed

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      setState(() {
        _reminders = [];
        _isLoading = false;
      });
      return;
    }
    final reminders = await _db.getReminders(userId);
    setState(() {
      _reminders = reminders;
      _isLoading = false;
    });
  }

  List<ReminderModel> get _filteredReminders {
    switch (_filter) {
      case 'pending':
        return _reminders.where((r) => !r.isCompleted).toList();
      case 'completed':
        return _reminders.where((r) => r.isCompleted).toList();
      default:
        return _reminders;
    }
  }

  Future<void> _addReminder() async {
    final result = await showDialog<ReminderModel>(
      context: context,
      builder: (context) => const ReminderEditDialog(),
    );
    if (result != null) {
      await _db.insertReminder(result);
      _loadReminders();
    }
  }

  Future<void> _editReminder(ReminderModel reminder) async {
    final result = await showDialog<ReminderModel>(
      context: context,
      builder: (context) => ReminderEditDialog(reminder: reminder),
    );
    if (result != null) {
      await _db.updateReminder(result);
      _loadReminders();
    }
  }

  Future<void> _deleteReminder(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个提醒吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteReminder(id);
      _loadReminders();
    }
  }

  Future<void> _toggleComplete(ReminderModel reminder) async {
    final updated = reminder.copyWith(isCompleted: !reminder.isCompleted);
    await _db.updateReminder(updated);
    _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒事项'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('全部')),
              ButtonSegment(value: 'pending', label: Text('待办')),
              ButtonSegment(value: 'completed', label: Text('已完成')),
            ],
            selected: {_filter},
            onSelectionChanged: (set) {
              setState(() => _filter = set.first);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReminders.isEmpty
              ? const Center(child: Text('暂无提醒事项'))
              : ListView.builder(
                  itemCount: _filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _filteredReminders[index];
                    return ReminderCard(
                      reminder: reminder,
                      onToggle: () => _toggleComplete(reminder),
                      onEdit: () => _editReminder(reminder),
                      onDelete: () => _deleteReminder(reminder.id),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _priorityColor {
    switch (reminder.priority) {
      case 'high':
        return Colors.red;
      case 'normal':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String get _priorityText {
    switch (reminder.priority) {
      case 'high':
        return '高';
      case 'normal':
        return '中';
      case 'low':
        return '低';
      default:
        return '普通';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Checkbox(
          value: reminder.isCompleted,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder.description != null && reminder.description!.isNotEmpty)
              Text(reminder.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(_priorityText),
                  backgroundColor: _priorityColor.withOpacity(0.1),
                  side: BorderSide(color: _priorityColor),
                  padding: EdgeInsets.zero,
                  labelStyle: TextStyle(color: _priorityColor, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  '${reminder.remindAt.month}/${reminder.remindAt.day} ${reminder.remindAt.hour}:${reminder.remindAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: reminder.remindAt.isBefore(DateTime.now()) && !reminder.isCompleted
                        ? Colors.red
                        : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}

class ReminderEditDialog extends StatefulWidget {
  final ReminderModel? reminder;

  const ReminderEditDialog({super.key, this.reminder});

  @override
  State<ReminderEditDialog> createState() => _ReminderEditDialogState();
}

class _ReminderEditDialogState extends State<ReminderEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));
  String _priority = 'normal';

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _descController.text = widget.reminder!.description ?? '';
      _remindAt = widget.reminder!.remindAt;
      _priority = widget.reminder!.priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reminder == null ? '新建提醒' : '编辑提醒'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '标题'),
                validator: (v) => v?.isEmpty == true ? '请输入标题' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '描述（可选）'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('提醒时间'),
                subtitle: Text('${_remindAt.month}/${_remindAt.day} ${_remindAt.hour}:${_remindAt.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _remindAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_remindAt),
                    );
                    if (time != null) {
                      setState(() {
                        _remindAt = DateTime(
                          date.year, date.month, date.day,
                          time.hour, time.minute,
                        );
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'high', label: Text('高')),
                  ButtonSegment(value: 'normal', label: Text('中')),
                  ButtonSegment(value: 'low', label: Text('低')),
                ],
                selected: {_priority},
                onSelectionChanged: (set) {
                  setState(() => _priority = set.first);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final userId = AuthService.instance.currentUserId ?? 'local_user';
              final reminder = ReminderModel(
                id: widget.reminder?.id ?? const Uuid().v4(),
                userId: widget.reminder?.userId ?? userId,
                title: _titleController.text,
                description: _descController.text.isEmpty ? null : _descController.text,
                remindAt: _remindAt,
                isCompleted: widget.reminder?.isCompleted ?? false,
                priority: _priority,
                createdAt: widget.reminder?.createdAt ?? DateTime.now(),
              );
              Navigator.pop(context, reminder);
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
