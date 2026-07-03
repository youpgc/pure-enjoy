import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../widgets/common_widgets.dart';
import '../models/reminder_model.dart';

/// 提醒事项页面 - Supabase 数据同步
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String _filter = 'pending'; // all, pending, completed

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _reminders = [];
        _isLoading = false;
      });
      return;
    }

    // 1. 先加载本地缓存
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyReminders);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _reminders = cached.map((e) => ReminderModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = true);
    }

    // 2. 静默从网络刷新
    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };

      switch (_filter) {
        case 'pending':
          filters['is_completed'] = 'eq.false';
        case 'completed':
          filters['is_completed'] = 'eq.true';
      }

      final result = await ApiClient.get(
        'reminders',
        filters: filters,
        order: 'remind_at.desc',
      );

      if (result.isSuccess) {
        final data = result.data!;
        final reminders = data.map((e) => ReminderModel.fromJson(e)).toList();
        // 保存缓存
        await CacheHelper.instance.saveList(CacheHelper.keyReminders, data);
        if (mounted) {
          setState(() {
            _reminders = reminders;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_reminders.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _addReminder() async {
    final result = await showDialog<ReminderModel>(
      context: context,
      builder: (context) => const ReminderEditDialog(),
    );
    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiResult = await ApiClient.post(
          'reminders',
          result.toJson(),
        );

        if (apiResult.isSuccess) {
          _loadReminders();
        } else {
          throw Exception('HTTP ${apiResult.statusCode}: ${apiResult.errorMessage}');
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
  }

  Future<void> _editReminder(ReminderModel reminder) async {
    final result = await showDialog<ReminderModel>(
      context: context,
      builder: (context) => ReminderEditDialog(reminder: reminder),
    );
    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiResult = await ApiClient.patchByFilter(
          'reminders',
          filters: {'id': 'eq.${reminder.id}'},
          body: result.toJsonForUpdate(),
        );

        if (apiResult.isSuccess) {
          _loadReminders();
        } else {
          throw Exception('HTTP ${apiResult.statusCode}: ${apiResult.errorMessage}');
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
  }

  Future<void> _deleteReminder(String id) async {
    final confirmed = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这个提醒吗？');
    if (confirmed == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'reminders',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          _loadReminders();
        } else {
          throw Exception('HTTP ${result.statusCode}');
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
      final result = await ApiClient.patchByFilter(
        'reminders',
        filters: {'id': 'eq.${reminder.id}'},
        body: {'is_completed': !reminder.isCompleted},
      );

      if (result.isSuccess) {
        _loadReminders();
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
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
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('全部')),
              ButtonSegment(value: 'pending', label: Text('待办')),
              ButtonSegment(value: 'completed', label: Text('已完成')),
            ],
            selected: {_filter},
            onSelectionChanged: (set) {
              setState(() => _filter = set.first);
              _loadReminders();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _reminders.isEmpty
              ? const EmptyWidget(icon: Icons.notifications_outlined, message: '暂无提醒事项')
              : RefreshIndicator(
                  onRefresh: _loadReminders,
                  child: ListView.builder(
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      return ReminderCard(
                        reminder: reminder,
                        onToggle: () => _toggleComplete(reminder),
                        onEdit: () => _editReminder(reminder),
                        onDelete: () => _deleteReminder(reminder.id),
                      );
                    },
                  ),
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
            Text(
              DateTimeUtils.formatStandard(reminder.remindAt),
              style: TextStyle(
                color: reminder.remindAt.isBefore(DateTime.now()) && !reminder.isCompleted
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: EditDeletePopupMenu(
          onEdit: onEdit,
          onDelete: onDelete,
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

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _descController.text = widget.reminder!.description ?? '';
      _remindAt = widget.reminder!.remindAt;
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '描述（可选）'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('提醒时间'),
                subtitle: Text(DateTimeUtils.formatStandard(_remindAt)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _remindAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  if (!mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_remindAt),
                  );
                  if (time == null) return;
                  if (!mounted) return;
                  setState(() {
                    _remindAt = DateTime(
                      date.year, date.month, date.day,
                      time.hour, time.minute,
                    );
                  });
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
