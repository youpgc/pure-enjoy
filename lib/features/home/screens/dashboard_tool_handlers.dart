import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../../../services/api_client.dart';
import 'dashboard_helpers.dart';
import 'sheets/sheets.dart';
import 'sheets/tool_config_sheet.dart';

/// 首页「快捷工具」点击分发 + 通用保存记录逻辑
/// 从 dashboard_page.dart 抽出，保持原行为不变（State.mounted 改为 context.mounted）。

/// 通用保存记录并刷新（原 DashboardPage._postRecord）
Future<void> dashboardPostRecord(
  BuildContext context,
  String table,
  Map<String, dynamic> data,
  String successMessage, {
  VoidCallback? onSuccess,
}) async {
  try {
    final result = await ApiClient.post(
      table,
      data,
      returnRepresentation: false,
    );
    if (result.isSuccess) {
      if (context.mounted) {
        // 先显示提示再关闭弹窗，避免 SnackBar 被弹窗遮挡
        showSnackBar(context, successMessage);
        Navigator.pop(context);
        onSuccess?.call();
      }
    } else {
      throw Exception(result.errorMessage ?? '请求失败');
    }
  } catch (e) {
    if (context.mounted) {
      showSnackBar(context, '添加失败，请稍后重试', isError: true);
    }
  }
}

/// 工具点击分发（原 DashboardPage._onToolTap）
void dashboardHandleToolTap(
  BuildContext context,
  ToolItem tool, {
  required VoidCallback reloadActivities,
  required VoidCallback reloadReminders,
  required VoidCallback fireExpense,
  required VoidCallback fireWeight,
}) {
  switch (tool.id) {
    case 'diary':
      showAddMoodSheet(
        context,
        onSave: (diary) => dashboardPostRecord(
          context,
          'mood_diaries',
          diary.toJson(),
          '日记添加成功',
          onSuccess: reloadActivities,
        ),
      );
      break;
    case 'expense':
      showAddExpenseSheet(
        context,
        onSave: (expense) => dashboardPostRecord(
          context,
          'expenses',
          expense.toJson(),
          '支出添加成功',
          onSuccess: () {
            reloadActivities();
            fireExpense();
          },
        ),
      );
      break;
    case 'weight':
      showAddWeightSheet(
        context,
        onSave: (record) => dashboardPostRecord(
          context,
          'weight_records',
          record.toJson(),
          '体重记录添加成功',
          onSuccess: () {
            reloadActivities();
            fireWeight();
          },
        ),
      );
      break;
    case 'note':
      showAddNoteSheet(
        context,
        onSave: (note) => dashboardPostRecord(
          context,
          'notes',
          note.toJson(),
          '笔记添加成功',
          onSuccess: reloadActivities,
        ),
      );
      break;
    case 'reminder':
      showAddReminderSheet(
        context,
        onSave: (reminder) => dashboardPostRecord(
          context,
          'reminders',
          reminder.toJson(),
          '提醒添加成功',
          onSuccess: reloadReminders,
        ),
      );
      break;
    case 'habit':
      showAddHabitSheet(
        context,
        onSave: (habit, reminderSchedule) async {
          try {
            final result = await ApiClient.post(
              'habits',
              habit.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              // 保存提醒计划
              if (reminderSchedule != null) {
                await ApiClient.post(
                  'reminder_schedules',
                  reminderSchedule.copyWith(habitId: habit.id).toJson(),
                  returnRepresentation: false,
                );
              }
              if (context.mounted) {
                Navigator.pop(context);
                showSnackBar(context, '习惯添加成功');
              }
            } else {
              throw Exception(result.errorMessage ?? '请求失败');
            }
          } catch (e) {
            if (context.mounted) {
              showSnackBar(context, '添加失败，请稍后重试', isError: true);
            }
          }
        },
      );
      break;
  }
}
