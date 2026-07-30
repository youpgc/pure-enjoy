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
import '../utils/date_time_utils.dart';

part 'notification_service_schedulers.dart';

/// 北京时区 Location。调度一律用它构造时刻，不依赖 tz.local：
/// tz.local 需 initialize() 里 setLocalLocation 才生效，热重载不重跑
/// initialize（单例 _initialized 保留），会退回默认 UTC 导致晚 8 小时。
tz.Location get _bj => tz.getLocation('Asia/Shanghai');

/// 本地通知服务（插件封装核心：初始化/权限/渠道/点击路由/统一调度与取消）。
/// 习惯/待办/纪念日的业务调度见 part 文件 notification_service_schedulers.dart。
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 进行中的初始化 Future（并发锁）：main 中多个入口并行调用 initialize()
  /// 时共享同一次初始化，避免 init 体重复执行。
  Future<void>? _initializing;

  // 通知渠道配置
  // v2 说明：Android 渠道 importance 在首次创建后不可提升，旧渠道若曾以较低
  // 重要级创建会导致横幅（heads-up）不弹。启用新 ID 并显式以 max 创建，确保横幅。
  static const String _channelId = 'pure_enjoy_channel_v2';
  static const String _channelName = '纯享通知';
  static const String _channelDescription = '纯享应用的通知渠道';

  /// 初始化通知服务（并发安全：并行调用共享同一次初始化）
  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _doInitialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _doInitialize() async {
    // 初始化时区数据
    tz_data.initializeTimeZones();
    // 项目铁律：时间口径固定北京。timezone 包不感知设备时区，tz.local 默认为 UTC，
    // 不显式设置会导致按墙钟构造的调度（习惯打卡/每日通知）真机+模拟器均固定晚 8 小时。
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

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

    // 显式创建高优通知渠道（importance 只认首次创建值，必须显式 max 才能保证横幅弹出）
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
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
      // 主动申请精确闹钟权限（Android 12+ 默认不授予；无精确权限时调度会
      // 降级为不精确模式，系统合批延迟可达 10~15 分钟，短提前量提醒会错过）
      final exactGranted = await androidPlugin.requestExactAlarmsPermission();
      if (kDebugMode) {
        debugPrint('⏰ 精确闹钟权限: ${exactGranted == true ? "已授权" : "未授权"}');
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
    var mode = 'exact';
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
      mode = 'inexact';
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
    // 诊断日志：调度模式 + 目标北京时间 + 当前待触发通知总数（📝 排查横幅不弹时看此行）
    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        '🔔 已调度[$mode] id=$id @ '
        '${DateTimeUtils.formatStandard(scheduledDate.toUtc())}（北京）'
        '，pending=${pending.length}',
      );
    }
  }
}
