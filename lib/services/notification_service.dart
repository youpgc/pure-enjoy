import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
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
    final _id = parts.length > 1 ? parts.sublist(1).join(':') : '';

    // 使用全局 NavigatorKey 进行页面跳转
    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'novel':
        // 跳转到小说详情
        if (kDebugMode) {
          debugPrint('跳转到小说详情');
        }
        break;
      case 'expense':
        // 跳转到消费记录
        if (kDebugMode) {
          debugPrint('跳转到消费记录');
        }
        break;
      case 'reminder':
        // 跳转到提醒事项
        if (kDebugMode) {
          debugPrint('跳转到提醒事项');
        }
        break;
      case 'notification':
        // 跳转到通知中心
        Navigator.pushNamed(context, '/notifications');
        break;
      default:
        if (kDebugMode) {
          debugPrint('未知通知类型: $type');
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

  /// 通知 ID 前缀
  static const int _habitNotificationBaseId = 2000;

  /// 设置习惯打卡提醒
  /// [habitId] 习惯ID，[habitName] 习惯名称，[hour] 小时，[minute] 分钟
  Future<void> setHabitReminder({
    required String habitId,
    required String habitName,
    required int hour,
    required int minute,
  }) async {
    final id = _habitNotificationBaseId + habitId.hashCode.abs();

    await scheduleDailyNotification(
      id: id,
      title: '习惯打卡提醒',
      body: '该完成「$habitName」了，坚持就是胜利！',
      hour: hour,
      minute: minute,
      payload: 'habit:$habitId',
    );
  }

  /// 取消习惯打卡提醒
  Future<void> cancelHabitReminder(String habitId) async {
    final id = _habitNotificationBaseId + habitId.hashCode.abs();
    await cancelNotification(id);
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
