import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/supabase_service.dart';
import '../../../life/models/reminder_model.dart';
import '../../../../utils/date_time_utils.dart';

/// 添加提醒底部弹窗
///
/// 用于快速创建一条提醒，包含标题、描述与提醒时间。
class AddReminderSheet extends StatefulWidget {
  final Function(ReminderModel) onSave;

  const AddReminderSheet({super.key, required this.onSave});

  @override
  State<AddReminderSheet> createState() => AddReminderSheetState();
}

class AddReminderSheetState extends State<AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final reminder = ReminderModel(
        id: const Uuid().v4(),
        userId: AuthService.instance.currentUserId ?? 'local_user',
        title: _titleController.text,
        description: _descController.text.isEmpty ? null : _descController.text,
        remindAt: _remindAt,
      );

      widget.onSave(reminder);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
            Text('添加提醒', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '标题'),
              validator: (v) => v?.isEmpty == true ? '请输入标题' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒时间'),
              trailing: Text(DateTimeUtils.formatStandard(_remindAt)),
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
                  context: this.context,
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
            const SizedBox(height: 16),
            FilledButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}
