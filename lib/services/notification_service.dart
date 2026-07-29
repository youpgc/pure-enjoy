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
import '../features/life/models/anniversary_model.dart';
import '../features/life/models/remind_offset.dart';
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
      case 'habit':
        // 跳转到习惯打卡
        unawaited(Navigator.pushNamed(context, '/habits'));
        break;
      case 'reminder':
        // 跳转到提醒事项
        unawaited(Navigator.pushNamed(context, '/reminders'));
        break;
      case 'anniversary':
        // 跳转到纪念日/生日
        unawaited(Navigator.pushNamed(context, '/anniversaries'));
        break;
      case 'notification':
        // 跳转到通知中心
        unawaited(Navigator.pushNamed(context, '/notifications'));
        break;
      case 'novel':
      case 'expense':
      default:
        if (kDebugMode) {
          debugPrint('未处理通知类型: $type, id: $id');
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

  /// 统一调度定时通知：优先精确闹钟（exactAllowWhileIdle），若系统未授权精确闹钟
  /// 抛异常则自动降级为 inexactAllowWhileIdle，避免 Android 13+ 上崩溃。
  Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (_) {
      if (kDebugMode) debugPrint('⚠️ 精确闹钟不可用，降级为不精确模式');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
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

    // 每日提醒用「每日重复」模式；其余类型一次性调度，由 App 启动/加载时重挂下一周期
    final isDaily = schedule.scheduleType == 'daily';
    await _scheduleZoned(
      id: id,
      title: '习惯打卡提醒',
      body: '该完成「$habitName」了，坚持就是胜利！',
      scheduledDate: next,
      payload: 'habit:${schedule.habitId}',
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

  /// 多偏移提醒的 ID 分配：模块块基址 + (hash % 9000) * 步长(10) + 偏移序号(0..7)，
  /// 保证同模块每事项唯一且 < 2^31；整段含 (步长+2) 个 ID 用于「全部取消」。
  static const int _reminderBlockBase = 40000;
  static const int _anniversaryBlockBase = 30000;
  static const int _offsetStride = 10;
  static const int _maxOffsets = 8;

  int _reminderBlock(String itemId, int moduleBase) =>
      moduleBase + (itemId.hashCode.abs() % 9000) * _offsetStride;

  int _reminderOffsetId(String itemId, int moduleBase, int index) =>
      _reminderBlock(itemId, moduleBase) + index;

  /// 取消某事项的整段提醒（覆盖其所有偏移 ID），用于开关关闭/删除/重设
  Future<void> _cancelReminderBlock(String itemId, int moduleBase) async {
    final base = _reminderBlock(itemId, moduleBase);
    for (int i = 0; i <= _offsetStride + 1; i++) {
      await cancelNotification(base + i);
    }
  }

  /// 根据提醒事项设置本地横幅通知（支持多个提前偏移）。
  /// [reminder] 待办事项（含 id / remindAt / remindEnabled / remindOffsets / isCompleted / title）；
  /// 关闭提醒 / 已完成 / 时间已过 → 取消整段已设定的提醒。
  Future<void> scheduleReminderNotification(ReminderModel reminder) async {
    if (!_initialized) await initialize();

    if (!reminder.remindEnabled ||
        reminder.isCompleted ||
        !reminder.remindAt.isAfter(DateTime.now())) {
      await _cancelReminderBlock(reminder.id, _reminderBlockBase);
      return;
    }

    final now = DateTime.now();
    var scheduled = 0;
    for (var i = 0;
        i < reminder.remindOffsets.length && i < _maxOffsets;
        i++) {
      final offset = reminder.remindOffsets[i];
      final target = offset.resolve(reminder.remindAt);
      if (!target.isAfter(now)) continue; // 已过时刻不调度
      final id = _reminderOffsetId(reminder.id, _reminderBlockBase, i);
      await _scheduleZoned(
        id: id,
        title: '提醒事项',
        body: reminder.title,
        scheduledDate: tz.TZDateTime.from(target, tz.local),
        payload: 'reminder:${reminder.id}',
      );
      scheduled++;
    }

    if (kDebugMode && scheduled > 0) {
      debugPrint('🔔 待办提醒已设置 $scheduled 个: ${reminder.title}');
    }
  }

  /// 取消待办事项提醒（整段偏移）
  Future<void> cancelReminderNotification(String id) async {
    await _cancelReminderBlock(id, _reminderBlockBase);
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
        if (model.remindEnabled && model.remindAt.isAfter(now)) {
          await scheduleReminderNotification(model);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('重挂待办提醒失败: $e');
    }
  }

  // ========== 纪念日 / 生日提醒 ==========

  /// 设置纪念日/生日提醒（支持多提前偏移，yearly 时每年重复）。
  /// [a] 纪念日模型（含 date / remind_enabled / remind_offsets / remind_time / repeat_yearly / type）。
  /// 未开启提醒时自动取消整段已设定的提醒。
  Future<void> scheduleAnniversaryReminder(AnniversaryModel a) async {
    if (!_initialized) await initialize();

    if (!a.remindEnabled) {
      await _cancelReminderBlock(a.id, _anniversaryBlockBase);
      return;
    }

    // 解析当天触发时刻（HH:mm），与下一个纪念日(公历月/日)组合为基准时刻
    var hour = 9;
    var minute = 0;
    final parts = a.remindTime.split(':');
    if (parts.length == 2) {
      hour = int.tryParse(parts[0]) ?? 9;
      minute = int.tryParse(parts[1]) ?? 0;
    }
    final next = a.nextDate;
    final base = DateTime(next.year, next.month, next.day, hour, minute);

    var scheduled = 0;
    for (var i = 0; i < a.remindOffsets.length && i < _maxOffsets; i++) {
      final offset = a.remindOffsets[i];
      // 推算出的时刻若已过去（如今年已过的提前档），顺延到下一年对应月/日
      var target = offset.resolve(base);
      if (target.isBefore(DateTime.now())) {
        target = DateTime(
          target.year + 1,
          target.month,
          target.day,
          target.hour,
          target.minute,
        );
      }
      final id = _reminderOffsetId(a.id, _anniversaryBlockBase, i);
      final isBirthday = a.type == 'birthday';
      await _scheduleZoned(
        id: id,
        title: isBirthday ? '🎂 ${a.title}的生日' : '🎉 ${a.title}',
        body: _anniversaryBody(a, offset, isBirthday),
        scheduledDate: tz.TZDateTime.from(target, tz.local),
        payload: 'anniversary:${a.id}',
        matchDateTimeComponents:
            a.repeatYearly ? DateTimeComponents.dayOfMonthAndTime : null,
      );
      scheduled++;
    }

    if (kDebugMode && scheduled > 0) {
      debugPrint('🔔 纪念日提醒已设置 $scheduled 个: ${a.title}');
    }
  }

  String _anniversaryBody(
      AnniversaryModel a, RemindOffset offset, bool isBirthday) {
    switch (offset.unit) {
      case 'minute':
        return '还有 ${offset.value} 分钟就是「${a.title}」啦，提前准备一下～';
      case 'day':
        return '还有 ${offset.value} 天就是「${a.title}」，提前准备一下～';
      case 'same':
      default:
        return isBirthday
            ? '今天是${a.title}的生日，记得送上祝福！'
            : '今天是「${a.title}」，记得庆祝一下！';
    }
  }

  /// 取消纪念日/生日提醒（整段偏移）
  Future<void> cancelAnniversaryReminder(String anniversaryId) async {
    await _cancelReminderBlock(anniversaryId, _anniversaryBlockBase);
  }

  /// 启动后从云端拉取已开启提醒的纪念日并重新挂接，保证跨重启持续生效。
  Future<void> armAnniversariesFromRemote() async {
    if (!_initialized) await initialize();
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    try {
      final result = await ApiClient.get(
        'user_anniversaries',
        filters: {'user_id': 'eq.$userId', 'remind_enabled': 'eq.true'},
      );
      if (!result.isSuccess || result.data == null) return;
      for (final a in result.data!) {
        await scheduleAnniversaryReminder(AnniversaryModel.fromJson(a));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('重挂纪念日提醒失败: $e');
    }
  }
}
