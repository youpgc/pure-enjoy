import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../services/api_client.dart';
import '../../../core/widgets/widgets.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';
import '../widgets/reminder_schedule_picker.dart';

/// 习惯编辑对话框（新增/编辑），原 HabitsScreen._showEditDialog 抽出
Future<void> showHabitEditDialog({
  required BuildContext context,
  HabitModel? habit,
  required Map<String, ReminderScheduleModel> reminderSchedules,
  required String? currentUserId,
  required VoidCallback onSaved,
}) async {
  final isEditing = habit != null;
  final nameController = TextEditingController(text: habit?.name ?? '');
  final descController = TextEditingController(text: habit?.description ?? '');
  final targetDaysController = TextEditingController(
    text: (habit?.targetDays ?? 21).toString(),
  );

  // 提醒计划状态
  ReminderScheduleModel? reminderSchedule = isEditing
      ? reminderSchedules[habit.id]
      : null;

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(isEditing ? '编辑习惯' : '添加习惯'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '习惯名称 *',
                    hintText: '例如：早起、阅读、运动',
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '输入习惯描述（可选）',
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetDaysController,
                  decoration: const InputDecoration(
                    labelText: '目标天数',
                    hintText: '例如：21',
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ReminderSchedulePicker(
                  initialSchedule: reminderSchedule,
                  onChanged: (schedule) {
                    setDialogState(() {
                      reminderSchedule = schedule;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                showSnackBar(context, '请输入习惯名称', isError: true);
                return;
              }

              final targetDays = int.tryParse(targetDaysController.text) ?? 21;
              final userId = currentUserId ?? 'local_user';
              String? habitId;

              try {
                if (isEditing) {
                  habitId = habit.id;
                  final result = await ApiClient.patchByFilter(
                    'habits',
                    filters: {'id': 'eq.$habitId'},
                    body: {
                      'name': nameController.text.trim(),
                      'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                      'target_days': targetDays,
                    },
                  );
                  if (!result.isSuccess) {
                    throw Exception('HTTP ${result.statusCode}');
                  }
                } else {
                  habitId = const Uuid().v4();
                  final result = await ApiClient.post(
                    'habits',
                    {
                      'id': habitId,
                      'user_id': userId,
                      'name': nameController.text.trim(),
                      'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                      'target_days': targetDays,
                      'is_active': true,
                    },
                  );
                  if (!result.isSuccess) {
                    throw Exception('HTTP ${result.statusCode}');
                  }
                }

                // 保存提醒计划
                final schedule = reminderSchedule?.copyWith(
                  habitId: habitId,
                  userId: userId,
                );
                if (schedule != null) {
                  if (schedule.id.isNotEmpty) {
                    // 更新已有提醒计划
                    final result = await ApiClient.patchByFilter(
                      'reminder_schedules',
                      filters: {'id': 'eq.${schedule.id}'},
                      body: schedule.toJsonForUpdate(),
                    );
                    if (!result.isSuccess) {
                      if (kDebugMode) debugPrint('提醒计划更新失败: ${result.error}');
                    }
                  } else {
                    // 新建提醒计划
                    final newId = const Uuid().v4();
                    await ApiClient.post(
                      'reminder_schedules',
                      schedule.copyWith(id: newId).toJson(),
                    );
                  }
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                onSaved();
              } catch (e) {
                showSnackBar(context, '保存失败，请稍后重试', isError: true);
              }
            },
            child: Text(isEditing ? '保存' : '添加'),
          ),
        ],
      ),
    ),
  );
}
