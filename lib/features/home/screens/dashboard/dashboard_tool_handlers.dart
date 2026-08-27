import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../../services/api_client.dart';
import '../../../../services/notification_service.dart';
import '../../../../core/utils/event_bus.dart';
import './dashboard_helpers.dart';
import '../sheets/sheets.dart';
import '../sheets/tool_config_sheet.dart';

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
          onSuccess: () {
            reloadActivities();
            // 写日记完成同步首页最近活动（dashboard 监听 moodDiaryUpdated 以 force 重拉）
            EventBus.instance.fire(EventType.moodDiaryUpdated);
          },
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
          onSuccess: () {
            reloadReminders();
            // 挂接本地横幅提醒
            unawaited(NotificationService.instance.scheduleReminderNotification(reminder));
          },
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
              // 保存提醒计划（补齐 id/user_id，空串会触发 PostgREST 22P02 uuid 解析失败）
              if (reminderSchedule != null) {
                final saved = reminderSchedule.copyWith(
                  id: reminderSchedule.id.isEmpty
                      ? const Uuid().v4()
                      : reminderSchedule.id,
                  habitId: habit.id,
                  userId: reminderSchedule.userId.isEmpty
                      ? habit.userId
                      : reminderSchedule.userId,
                );
                await ApiClient.post(
                  'reminder_schedules',
                  saved.toJson(),
                  returnRepresentation: false,
                );
                // 设置本地提醒横幅
                await NotificationService.instance.scheduleHabitReminder(
                  schedule: saved,
                  habitName: habit.name,
                );
              }
              // 新增习惯成功 → 广播事件，首页「今日打卡」区块经监听 invalidate 缓存并刷新
              EventBus.instance.fire(EventType.habitUpdated);
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
