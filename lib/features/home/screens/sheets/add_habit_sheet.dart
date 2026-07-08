import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/supabase_service.dart';
import '../../../life/models/habit_model.dart';
import '../../../life/models/reminder_schedule_model.dart';
import '../../../life/widgets/reminder_schedule_picker.dart';

/// 添加习惯底部弹窗
///
/// 用于快速创建一个习惯追踪项，包含名称、描述、目标天数与提醒计划。
class AddHabitSheet extends StatefulWidget {
  final Function(HabitModel, ReminderScheduleModel?) onSave;

  const AddHabitSheet({super.key, required this.onSave});

  @override
  State<AddHabitSheet> createState() => AddHabitSheetState();
}

class AddHabitSheetState extends State<AddHabitSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _targetDaysController = TextEditingController(text: '21');
  ReminderScheduleModel? _reminderSchedule;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _targetDaysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入习惯名称')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final targetDays = int.tryParse(_targetDaysController.text) ?? 21;

      final habit = HabitModel(
        id: const Uuid().v4(),
        userId: AuthService.instance.currentUserId ?? 'local_user',
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        targetDays: targetDays,
        isActive: true,
      );

      widget.onSave(habit, _reminderSchedule);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加习惯', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '习惯名称 *',
              hintText: '例如：早起、阅读、运动',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '描述（可选）',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetDaysController,
            decoration: const InputDecoration(
              labelText: '目标天数',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ReminderSchedulePicker(
            initialSchedule: _reminderSchedule,
            onChanged: (schedule) => setState(() => _reminderSchedule = schedule),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
