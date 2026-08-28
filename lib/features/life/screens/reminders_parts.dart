part of './reminders_screen.dart';

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
  bool _remindEnabled = false;
  List<RemindOffset> _remindOffsets = [];
  String? _repeatType;

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _descController.text = widget.reminder!.description ?? '';
      _remindAt = widget.reminder!.remindAt;
      _remindEnabled = widget.reminder!.remindEnabled;
      _remindOffsets = List.from(widget.reminder!.remindOffsets);
      _repeatType = widget.reminder!.repeatType;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '标题'),
                textAlign: TextAlign.start,
                validator: (v) => v?.isEmpty == true ? '请输入标题' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '描述（可选）'),
                maxLines: 3,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提醒时间'),
                subtitle: Text(DateTimeUtils.formatStandard(_remindAt)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // 选择器统一按北京墙钟交互（与展示口径一致，避免模拟器 UTC 时区偏 8 小时）
                  final bjNow =
                      DateTimeUtils.toBeijingWallClock(DateTime.now());
                  final bjInitial =
                      DateTimeUtils.toBeijingWallClock(_remindAt);
                  final date = await AppDatePicker.show(
                    context,
                    type: DateTimeType.date,
                    initialDate: bjInitial,
                    minDate: bjNow,
                    maxDate: bjNow.add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await AppDatePicker.show(
                    context, // ignore: use_build_context_synchronously
                    type: DateTimeType.time,
                    initialDate: bjInitial,
                  );
                  if (time == null || !mounted) return;
                  setState(() {
                    // 北京墙钟还原为设备时刻后写回（存储/调度瞬时值不变）
                    _remindAt = DateTimeUtils.fromBeijingWallClock(DateTime(
                      date.year, date.month, date.day,
                      time.hour, time.minute,
                    ));
                  });
                },
              ),
              RemindOffsetSelector(
                // 标签展示用北京墙钟口径（与提醒时间展示一致）
                baseTime: DateTimeUtils.toBeijingWallClock(_remindAt),
                initialEnabled: _remindEnabled,
                initialOffsets: _remindOffsets,
                onChanged: (settings) {
                  setState(() {
                    _remindEnabled = settings.enabled;
                    _remindOffsets = settings.offsets;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '重复'),
                value: _repeatType,
                items: const [
                  DropdownMenuItem(value: null, child: Text('不重复')),
                  DropdownMenuItem(value: 'daily', child: Text('每天')),
                  DropdownMenuItem(value: 'weekly', child: Text('每周')),
                  DropdownMenuItem(value: 'monthly', child: Text('每月')),
                  DropdownMenuItem(value: 'yearly', child: Text('每年')),
                ],
                onChanged: (v) => setState(() => _repeatType = v),
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
                remindEnabled: _remindEnabled,
                remindOffsets: _remindOffsets,
                // 周期仅存储（铁律③），不在此展开重复实例/不挂 habits
                repeatType: _repeatType,
                isRepeated: _repeatType != null,
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
