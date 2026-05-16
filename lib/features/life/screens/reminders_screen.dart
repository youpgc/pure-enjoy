import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_model.dart';
import '../../../services/database_service.dart';

/// 提醒事项页面
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final DatabaseService _db = DatabaseService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  List<ReminderModel> _reminders = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, completed

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadReminders();
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);
  }

  Future<void> _scheduleNotification(ReminderModel reminder) async {
    final scheduledDate = reminder.remindAt;
    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      '提醒事项',
      channelDescription: '日程提醒通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.schedule(
      reminder.id.hashCode,
      reminder.title,
      reminder.description ?? '您有一个待办事项',
      scheduledDate,
      details,
    );
  }

  Future<void> _cancelNotification(String reminderId) async {
    await _notifications.cancel(reminderId.hashCode);
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final items = await _db.getReminders();
      setState(() {
        _reminders = items..sort((a, b) {
          // 未完成的排在前面
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          // 按时间排序
          return a.remindAt.compareTo(b.remindAt);
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载提醒失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _toggleComplete(ReminderModel reminder) async {
    try {
      final updated = reminder.copyWith(
        isCompleted: !reminder.isCompleted,
        updatedAt: DateTime.now(),
      );
      await _db.updateReminder(updated);
      
      if (updated.isCompleted) {
        await _cancelNotification(reminder.id);
      } else {
        await _scheduleNotification(updated);
      }
      
      _loadReminders();
    } catch (e) {
      _showError('操作失败: $e');
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
      try {
        await _cancelNotification(id);
        await _db.deleteReminder(id);
        _loadReminders();
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _showEditDialog({ReminderModel? reminder}) async {
    final isEditing = reminder != null;
    final titleController = TextEditingController(text: reminder?.title ?? '');
    final descController =
        TextEditingController(text: reminder?.description ?? '');
    DateTime selectedDate = reminder?.remindAt ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String priority = reminder?.priority ?? 'normal';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑提醒' : '添加提醒'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '标题 *',
                    hintText: '输入提醒标题',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '输入提醒描述（可选）',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('日期'),
                  subtitle: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('时间'),
                  subtitle: Text(
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: '优先级'),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('高')),
                    DropdownMenuItem(value: 'normal', child: Text('普通')),
                    DropdownMenuItem(value: 'low', child: Text('低')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => priority = value);
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
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  _showError('请输入标题');
                  return;
                }

                final remindAt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final newReminder = ReminderModel(
                  id: isEditing ? reminder.id : const Uuid().v4(),
                  title: titleController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  remindAt: remindAt,
                  isCompleted: reminder?.isCompleted ?? false,
                  priority: priority,
                  createdAt: isEditing ? reminder.createdAt : DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                try {
                  if (isEditing) {
                    await _db.updateReminder(newReminder);
                  } else {
                    await _db.insertReminder(newReminder);
                  }
                  
                  if (!newReminder.isCompleted) {
                    await _scheduleNotification(newReminder);
                  }
                  
                  Navigator.pop(context);
                  _loadReminders();
                } catch (e) {
                  _showError('保存失败: $e');
                }
              },
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒事项'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('全部')),
              const PopupMenuItem(value: 'pending', child: Text('待完成')),
              const PopupMenuItem(value: 'completed', child: Text('已完成')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无提醒事项',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _filteredReminders[index];
                    return _ReminderCard(
                      reminder: reminder,
                      priorityColor: _getPriorityColor(reminder.priority),
                      onToggleComplete: () => _toggleComplete(reminder),
                      onEdit: () => _showEditDialog(reminder: reminder),
                      onDelete: () => _deleteReminder(reminder.id),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final Color priorityColor;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.priorityColor,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = reminder.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: reminder.isCompleted ? Colors.grey : priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Checkbox(
              value: reminder.isCompleted,
              onChanged: (_) => onToggleComplete(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: reminder.isCompleted
                              ? colorScheme.outline
                              : null,
                        ),
                  ),
                  if (reminder.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: reminder.isCompleted
                            ? colorScheme.outline
                            : colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: isOverdue ? Colors.red : colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(reminder.remindAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : colorScheme.outline,
                          fontWeight:
                              isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '已过期',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
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
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (date == today) {
      dateStr = '今天';
    } else if (date == today.add(const Duration(days: 1))) {
      dateStr = '明天';
    } else {
      dateStr =
          '${dateTime.month}/${dateTime.day}';
    }

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }
}
