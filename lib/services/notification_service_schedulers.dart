part of 'notification_service.dart';

/// 业务提醒调度（习惯打卡 / 待办事项 / 纪念日生日）。
/// 与 NotificationService 同库（part），可直接访问其私有成员；
/// 拆分仅为控制单文件规模，行为与拆分前完全一致。
extension NotificationSchedulers on NotificationService {
  // ========== 通知 ID 分配 ==========

  /// 习惯通知 ID 基址：基址 + hash%10000 → 独占 100000..109999，
  /// 不与待办/纪念日块区间（200000+/300000+）碰撞。
  /// 旧方案 2000+hash.abs() 的 hash 未取模，ID 散布全空间会撞其他模块的块。
  static const int _habitNotificationBaseId = 100000;

  /// 多偏移提醒的 ID 分配：模块块基址 + (hash % 9000) * 步长(10) + 偏移序号(0..7)，
  /// 保证同模块每事项唯一且 < 2^31；「全部取消」只覆盖本块内 ID（0..步长-1），
  /// 严禁越过步长（会误取消相邻 hash 块事项的通知）。
  /// 模块区间规划（每模块跨度 9000*10=90000，互不重叠）：
  ///   习惯      100000..109999（单 ID）
  ///   纪念日    200000..289999
  ///   待办      300000..389999
  static const int _reminderBlockBase = 300000;
  static const int _anniversaryBlockBase = 200000;
  static const int _offsetStride = 10;
  static const int _maxOffsets = 8;

  int _habitNotificationId(String habitId) =>
      _habitNotificationBaseId + (habitId.hashCode.abs() % 10000);

  int _reminderBlock(String itemId, int moduleBase) =>
      moduleBase + (itemId.hashCode.abs() % 9000) * _offsetStride;

  int _reminderOffsetId(String itemId, int moduleBase, int index) =>
      _reminderBlock(itemId, moduleBase) + index;

  /// 取消某事项的整段提醒（覆盖其所有偏移 ID），用于开关关闭/删除/重设
  Future<void> _cancelReminderBlock(String itemId, int moduleBase) async {
    final base = _reminderBlock(itemId, moduleBase);
    for (int i = 0; i < _offsetStride; i++) {
      await cancelNotification(base + i);
    }
  }

  // ========== 习惯打卡提醒 ==========

  /// 根据提醒计划设置习惯打卡的本地横幅提醒。
  /// [schedule] 提醒计划（含 daily/weekly/monthly/yearly/custom 与 time/is_enabled）；
  /// [habitName] 习惯名称，用于通知文案。
  /// 未启用或无法算出下次时间时自动取消已设定的提醒。
  Future<void> scheduleHabitReminder({
    required ReminderScheduleModel schedule,
    required String habitName,
  }) async {
    if (!_initialized) await initialize();
    final id = _habitNotificationId(schedule.habitId);

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
    final now = tz.TZDateTime.now(_bj);
    for (int i = 0; i < 400; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      if (!schedule.shouldRemindToday(day)) continue;
      final dt = tz.TZDateTime(_bj, day.year, day.month, day.day, hour, minute);
      if (!dt.isBefore(now)) return dt;
    }
    return null;
  }

  /// 取消习惯打卡提醒
  Future<void> cancelHabitReminder(String habitId) async {
    await cancelNotification(_habitNotificationId(habitId));
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

    // 重挂前先取消整段旧调度，避免编辑后减少偏移档时旧通知残留
    await _cancelReminderBlock(reminder.id, _reminderBlockBase);

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
        scheduledDate: tz.TZDateTime.from(target, _bj),
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

    // 重挂前先取消整段旧调度，避免编辑后减少偏移档时旧通知残留
    await _cancelReminderBlock(a.id, _anniversaryBlockBase);

    // 解析当天触发时刻（HH:mm），与下一个纪念日(公历月/日)组合为基准时刻
    var hour = 9;
    var minute = 0;
    final parts = a.remindTime.split(':');
    if (parts.length == 2) {
      hour = int.tryParse(parts[0]) ?? 9;
      minute = int.tryParse(parts[1]) ?? 0;
    }
    final next = a.nextDate;
    // 基准时刻按北京墙钟构造（_bj 固定 Asia/Shanghai，不依赖 tz.local）。
    // 若用 DateTime() 设备墙钟构造，UTC 模拟器上会晚 8 小时触发。
    final DateTime base =
        tz.TZDateTime(_bj, next.year, next.month, next.day, hour, minute);

    var scheduled = 0;
    for (var i = 0; i < a.remindOffsets.length && i < _maxOffsets; i++) {
      final offset = a.remindOffsets[i];
      // 推算出的时刻若已过去（如今年已过的提前档），顺延到下一年对应月/日
      var target = offset.resolve(base);
      if (target.isBefore(DateTime.now())) {
        // 顺延同样用北京墙钟构造（target 为 TZDateTime，字段即北京墙钟值）
        target = tz.TZDateTime(
          _bj,
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
        scheduledDate: tz.TZDateTime.from(target, _bj),
        payload: 'anniversary:${a.id}',
        // 年复用 dateAndTime（匹配 月+日+时刻，每年一次）。
        // 注意 dayOfMonthAndTime 是「每月」同日重复，误用会导致每月都弹。
        matchDateTimeComponents:
            a.repeatYearly ? DateTimeComponents.dateAndTime : null,
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
