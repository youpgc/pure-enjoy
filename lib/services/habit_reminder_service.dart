import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// 习惯提醒设置
class HabitReminder {
  final String habitId;
  final String habitName;
  final TimeOfDay time;
  final bool enabled;

  HabitReminder({
    required this.habitId,
    required this.habitName,
    required this.time,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'habitId': habitId,
        'habitName': habitName,
        'hour': time.hour,
        'minute': time.minute,
        'enabled': enabled,
      };

  factory HabitReminder.fromJson(Map<String, dynamic> json) => HabitReminder(
        habitId: json['habitId'],
        habitName: json['habitName'],
        time: TimeOfDay(hour: json['hour'], minute: json['minute']),
        enabled: json['enabled'] ?? true,
      );
}

/// 习惯提醒服务
class HabitReminderService {
  static const String _storageKey = 'habit_reminders';

  /// 获取所有提醒设置
  static Future<Map<String, HabitReminder>> getAllReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return {};

    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      return data.map((key, value) =>
          MapEntry(key, HabitReminder.fromJson(value as Map<String, dynamic>)));
    } catch (e) {
      return {};
    }
  }

  /// 获取单个习惯提醒
  static Future<HabitReminder?> getReminder(String habitId) async {
    final reminders = await getAllReminders();
    return reminders[habitId];
  }

  /// 保存提醒设置
  static Future<void> saveReminder(HabitReminder reminder) async {
    final reminders = await getAllReminders();
    reminders[reminder.habitId] = reminder;
    await _saveAllReminders(reminders);

    // 调度或取消通知
    if (reminder.enabled) {
      await _scheduleReminder(reminder);
    } else {
      await NotificationService().cancelNotification(_getNotificationId(reminder.habitId));
    }
  }

  /// 删除提醒设置
  static Future<void> deleteReminder(String habitId) async {
    final reminders = await getAllReminders();
    reminders.remove(habitId);
    await _saveAllReminders(reminders);
    await NotificationService().cancelNotification(_getNotificationId(habitId));
  }

  /// 切换提醒开关
  static Future<void> toggleReminder(String habitId, bool enabled) async {
    final reminder = await getReminder(habitId);
    if (reminder != null) {
      final updated = HabitReminder(
        habitId: reminder.habitId,
        habitName: reminder.habitName,
        time: reminder.time,
        enabled: enabled,
      );
      await saveReminder(updated);
    }
  }

  /// 保存所有提醒
  static Future<void> _saveAllReminders(Map<String, HabitReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final data = reminders.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  /// 调度提醒通知
  static Future<void> _scheduleReminder(HabitReminder reminder) async {
    final notificationId = _getNotificationId(reminder.habitId);
    await NotificationService().scheduleDailyReminder(
      id: notificationId,
      title: '习惯打卡提醒',
      body: '该打卡「${reminder.habitName}」了，坚持就是胜利！',
      time: reminder.time,
      payload: 'habit:${reminder.habitId}',
    );
  }

  /// 获取通知ID（将 habitId 转为 int）
  static int _getNotificationId(String habitId) {
    // 使用 habitId 的 hashCode 作为通知ID
    return habitId.hashCode.abs() % 100000;
  }

  /// 初始化所有启用的提醒（App启动时调用）
  static Future<void> initializeAllReminders() async {
    final reminders = await getAllReminders();
    for (final reminder in reminders.values) {
      if (reminder.enabled) {
        await _scheduleReminder(reminder);
      }
    }
  }
}
