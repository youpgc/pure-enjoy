import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import './api_client.dart';
import './supabase_service.dart';
import '../features/life/models/reminder_schedule_model.dart';
import '../features/life/models/reminder_model.dart';
import '../main.dart' show navigatorKey;

/// 本地通知服务
/// 支持即时通知、定时通知、每日重复通知
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // 通知渠道配置
  static const String _channelId = 'pure_enjoy_channel';
  static const String _channelName = '纯享通知';
  static const String _channelDescription = '纯享应用的通知渠道';

  // 通知 ID 生成器
  int _notificationId = 1000;
  int get _generateId => _notificationId++;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化时区数据
    tz_data.initializeTimeZones();

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 请求通知权限
    await _requestPermission();

    _initialized = true;
    if (kDebugMode) {
      debugPrint('✅ 通知服务初始化完成');
    }
  }

  /// 请求通知权限
  Future<bool> _requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      if (kDebugMode) {
        debugPrint('📱 通知权限: ${granted == true ? "已授权" : "未授权"}');
      }
      return granted == true;
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('📱 通知权限: ${granted == true ? "已授权" : "未授权"}');
      }
      return granted == true;
    }

    return true;
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('🔔 通知被点击');
    }
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // 根据 payload 跳转到对应页面
    // payload 格式: "type:id" 例如 "novel:xxx" "expense:xxx" "reminder:xxx"
    final parts = payload.split(':');
    final type = parts.first;
    final id = parts.length > 1 ? parts.sublist(1).join(':') : '';

    // 使用全局 NavigatorKey 进行页面跳转
    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'novel':
        // 跳转到小说详情
        if (kDebugMode) {
          debugPrint('跳转到小说详情: $id');
        }
        break;
      case 'expense':
        // 跳转到消费记录
        if (kDebugMode) {
          debugPrint('跳转到消费记录: $id');
        }
        break;
      case 'reminder':
        // 跳转到提醒事项
        if (kDebugMode) {
          debugPrint('跳转到提醒事项: $id');
        }
        break;
      case 'notification':
        // 跳转到通知中心
        Navigator.pushNamed(context, '/notifications');
        break;
      default:
        if (kDebugMode) {
          debugPrint('未知通知类型: $type, id: $id');
        }
    }
  }

  // ========== 即时通知 ==========

  /// 发送即时通知
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id ?? _generateId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ========== 定时通知 ==========

  /// 发送定时通知（单次）
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    int? id,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      id ?? _generateId,
      title,
      body,
      tzDateTime,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    if (kDebugMode) {
      debugPrint('⏰ 定时通知已设置: $title @ $scheduledTime');
    }
  }

  /// 发送每日重复通知
  /// [hour] 小时 (0-23), [minute] 分钟 (0-59)
  /// [id] 固定ID，用于取消
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // 如果设定时间已过，推迟到明天
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重复
    );

    if (kDebugMode) {
      debugPrint('🔄 每日通知已设置: $title @ ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    }
  }

  // ========== 取消通知 ==========

  /// 取消指定通知
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    if (kDebugMode) {
      debugPrint('❌ 通知已取消: id=$id');
    }
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    if (kDebugMode) {
      debugPrint('❌ 所有通知已取消');
    }
  }

  // ========== 习惯打卡提醒 ==========

  /// 通知 ID 前缀（与习惯 ID 哈希组合，保证每习惯唯一）
  static const int _habitNotificationBaseId = 2000;

  /// 根据提醒计划设置习惯打卡的本地横幅提醒。
  /// [schedule] 提醒计划（含 daily/weekly/monthly/yearly/custom 与 time/is_enabled）；
  /// [habitName] 习惯名称，用于通知文案。
  /// 未启用或无法算出下次时间时自动取消已设定的提醒。
  Future<void> scheduleHabitReminder({
    required ReminderScheduleModel schedule,
    required String habitName,
  }) async {
    if (!_initialized) await initialize();
    final id = _habitNotificationBaseId + schedule.habitId.hashCode.abs();

    // 未启用或无法计算下次提醒时间 → 取消已设定的提醒
    if (!schedule.isEnabled) {
      await cancelNotification(id);
      return;
    }

    final next = _nextReminderDateTime(schedule);
    if (next == null) {
      await cancelNotification(id);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // 每日提醒用「每日重复」模式；其余类型一次性调度，由 App 启动/加载时重挂下一周期
    final isDaily = schedule.scheduleType == 'daily';
    await _plugin.zonedSchedule(
      id,
      '习惯打卡提醒',
      '该完成「$habitName」了，坚持就是胜利！',
      next,
      details,
      payload: 'habit:${schedule.habitId}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: isDaily ? DateTimeComponents.time : null,
    );

    if (kDebugMode) {
      debugPrint('🔔 习惯提醒已设置: $habitName @ $next');
    }
  }

  /// 计算下次有效提醒时间：按 shouldRemindToday 逐日判定，兼容星期/月/年/自定义。
  tz.TZDateTime? _nextReminderDateTime(ReminderScheduleModel schedule) {
    final parts = schedule.time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final now = tz.TZDateTime.now(tz.local);
    for (int i = 0; i < 400; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      if (!schedule.shouldRemindToday(day)) continue;
      final dt = tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute);
      if (!dt.isBefore(now)) return dt;
    }
    return null;
  }

  /// 取消习惯打卡提醒
  Future<void> cancelHabitReminder(String habitId) async {
    final id = _habitNotificationBaseId + habitId.hashCode.abs();
    await cancelNotification(id);
  }

  /// 启动后从云端拉取当前用户已启用的提醒并重新挂接，保证跨重启/更新持续生效。
  Future<void> armHabitRemindersFromRemote() async {
    if (!_initialized) await initialize();
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    try {
      final result = await ApiClient.get(
        'reminder_schedules',
        filters: {'user_id': 'eq.$userId', 'is_enabled': 'eq.true'},
      );
      if (!result.isSuccess || result.data == null) return;

      final habitsResult = await ApiClient.get(
        'habits',
        filters: {'user_id': 'eq.$userId', 'is_active': 'eq.true'},
      );
      final nameById = <String, String>{};
      if (habitsResult.isSuccess && habitsResult.data != null) {
        for (final h in habitsResult.data!) {
          nameById[h['id'] as String] = (h['name'] as String?) ?? '习惯';
        }
      }

      for (final s in result.data!) {
        final model = ReminderScheduleModel.fromJson(s);
        final name = nameById[model.habitId] ?? '习惯';
        await scheduleHabitReminder(schedule: model, habitName: name);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('重挂习惯提醒失败: $e');
    }
  }

  // ========== 待办事项提醒 ==========

  /// 通知 ID 前缀（与待办 ID 哈希组合，保证每待办唯一）
  static const int _reminderNotificationBaseId = 4000;

  /// 根据提醒事项设置本地横幅通知。
  /// [reminder] 待办事项（含 id / remindAt / isCompleted / title）；
  /// 已完成或时间已过则取消已设定的提醒。
  Future<void> scheduleReminderNotification(ReminderModel reminder) async {
    if (!_initialized) await initialize();
    final id = _reminderNotificationBaseId + reminder.id.hashCode.abs();

    // 已完成或时间已过 → 取消已设定的提醒
    if (reminder.isCompleted || !reminder.remindAt.isAfter(DateTime.now())) {
      await cancelNotification(id);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzTime = tz.TZDateTime.from(reminder.remindAt, tz.local);
    await _plugin.zonedSchedule(
      id,
      '提醒事项',
      reminder.title,
      tzTime,
      details,
      payload: 'reminder:${reminder.id}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    if (kDebugMode) {
      debugPrint('🔔 待办提醒已设置: ${reminder.title} @ $tzTime');
    }
  }

  /// 取消待办事项提醒
  Future<void> cancelReminderNotification(String id) async {
    final nid = _reminderNotificationBaseId + id.hashCode.abs();
    await cancelNotification(nid);
  }

  /// 启动后从云端拉取未完成的未来待办并重新挂接，保证跨重启持续生效。
  Future<void> armRemindersFromRemote() async {
    if (!_initialized) await initialize();
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    try {
      final result = await ApiClient.get(
        'reminders',
        filters: {'user_id': 'eq.$userId', 'is_completed': 'eq.false'},
      );
      if (!result.isSuccess || result.data == null) return;
      final now = DateTime.now();
      for (final r in result.data!) {
        final model = ReminderModel.fromJson(r);
        if (model.remindAt.isAfter(now)) {
          await scheduleReminderNotification(model);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('重挂待办提醒失败: $e');
    }
  }

  // ========== 纪念日提醒 ==========

  /// 通知 ID 前缀
  static const int _anniversaryNotificationBaseId = 3000;

  /// 设置纪念日提醒（每年重复）
  /// [anniversaryId] 纪念日ID，[title] 提醒标题，[date] 日期（月/日）
  Future<void> setAnniversaryReminder({
    required String anniversaryId,
    required String title,
    required DateTime date,
    String? note,
  }) async {
    final id = _anniversaryNotificationBaseId + anniversaryId.hashCode.abs();

    await scheduleDailyNotification(
      id: id,
      title: '🎉 $title',
      body: note ?? '今天是特别的日子，记得庆祝一下！',
      hour: 9, // 早上9点提醒
      minute: 0,
      payload: 'anniversary:$anniversaryId',
    );
  }

  /// 取消纪念日提醒
  Future<void> cancelAnniversaryReminder(String anniversaryId) async {
    final id = _anniversaryNotificationBaseId + anniversaryId.hashCode.abs();
    await cancelNotification(id);
  }
}
