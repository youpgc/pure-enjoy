/// 提醒计划模型 - 对应 Supabase reminder_schedules 表
/// 支持按周、按月、按年、自定义日期组合提醒
///
/// 数据库字段:
/// id(UUID), habit_id(UUID), user_id(VARCHAR)
/// schedule_type(VARCHAR): weekly/monthly/yearly/custom
/// week_days(JSONB): [1,3,5] 周一三五
/// month_days(JSONB): [1,15] 每月1号和15号
/// month(JSONB): [3,6,9,12] 每年3/6/9/12月
/// years(JSONB): [2026,2027] 指定年份
/// dates(JSONB): ["2026-06-15","2026-06-20"] 自定义具体日期
/// time(TIME): "08:00" 提醒时间
/// is_enabled(BOOLEAN): 是否启用
/// created_at, updated_at
class ReminderScheduleModel {
  final String id;
  final String habitId;
  final String userId;

  /// 提醒类型: weekly/monthly/yearly/custom/daily
  final String scheduleType;

  /// 每周提醒: 1=周一, 7=周日
  final List<int> weekDays;

  /// 每月提醒: 1-31
  final List<int> monthDays;

  /// 每年提醒: 1-12
  final List<int> months;

  /// 指定年份
  final List<int> years;

  /// 自定义日期列表: ["2026-06-15", "2026-06-20"]
  final List<String> dates;

  /// 提醒时间: "08:00"
  final String time;

  /// 是否启用
  final bool isEnabled;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReminderScheduleModel({
    required this.id,
    required this.habitId,
    required this.userId,
    this.scheduleType = 'weekly',
    this.weekDays = const [],
    this.monthDays = const [],
    this.months = const [],
    this.years = const [],
    this.dates = const [],
    this.time = '08:00',
    this.isEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ReminderScheduleModel.fromJson(Map<String, dynamic> json) {
    return ReminderScheduleModel(
      id: json['id'] as String,
      habitId: json['habit_id'] as String,
      userId: json['user_id'] as String,
      scheduleType: json['schedule_type'] as String? ?? 'weekly',
      weekDays: _parseIntList(json['week_days']),
      monthDays: _parseIntList(json['month_days']),
      months: _parseIntList(json['months']),
      years: _parseIntList(json['years']),
      dates: _parseStringList(json['dates']),
      time: json['time'] as String? ?? '08:00',
      isEnabled: json['is_enabled'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'schedule_type': scheduleType,
      'week_days': weekDays.isEmpty ? null : weekDays,
      'month_days': monthDays.isEmpty ? null : monthDays,
      'months': months.isEmpty ? null : months,
      'years': years.isEmpty ? null : years,
      'dates': dates.isEmpty ? null : dates,
      'time': time,
      'is_enabled': isEnabled,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'schedule_type': scheduleType,
      'week_days': weekDays.isEmpty ? null : weekDays,
      'month_days': monthDays.isEmpty ? null : monthDays,
      'months': months.isEmpty ? null : months,
      'years': years.isEmpty ? null : years,
      'dates': dates.isEmpty ? null : dates,
      'time': time,
      'is_enabled': isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ReminderScheduleModel copyWith({
    String? id,
    String? habitId,
    String? userId,
    String? scheduleType,
    List<int>? weekDays,
    List<int>? monthDays,
    List<int>? months,
    List<int>? years,
    List<String>? dates,
    String? time,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderScheduleModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      userId: userId ?? this.userId,
      scheduleType: scheduleType ?? this.scheduleType,
      weekDays: weekDays ?? this.weekDays,
      monthDays: monthDays ?? this.monthDays,
      months: months ?? this.months,
      years: years ?? this.years,
      dates: dates ?? this.dates,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 检查今天是否需要提醒
  bool shouldRemindToday(DateTime date) {
    if (!isEnabled) return false;

    switch (scheduleType) {
      case 'daily':
        return true;

      case 'weekly':
        if (weekDays.isEmpty) return false;
        // Dart DateTime.weekday: 1=周一, 7=周日
        return weekDays.contains(date.weekday);

      case 'monthly':
        if (monthDays.isEmpty) return false;
        return monthDays.contains(date.day);

      case 'yearly':
        if (months.isEmpty) return false;
        if (!months.contains(date.month)) return false;
        if (monthDays.isNotEmpty) {
          return monthDays.contains(date.day);
        }
        return true;

      case 'custom':
        if (dates.isEmpty) return false;
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        return dates.contains(dateStr);

      default:
        return false;
    }
  }

  /// 获取下次提醒日期
  DateTime? getNextReminderDate() {
    if (!isEnabled) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (scheduleType) {
      case 'daily':
        return today;

      case 'weekly':
        if (weekDays.isEmpty) return null;
        // 找到下一个匹配的星期几
        for (int i = 0; i < 7; i++) {
          final checkDate = today.add(Duration(days: i));
          if (weekDays.contains(checkDate.weekday)) {
            return checkDate;
          }
        }
        return null;

      case 'monthly':
        if (monthDays.isEmpty) return null;
        // 找本月或下月匹配的日期
        for (int monthOffset = 0; monthOffset < 12; monthOffset++) {
          final checkMonth = DateTime(now.year, now.month + monthOffset);
          final daysInMonth = DateTime(checkMonth.year, checkMonth.month + 1, 0).day;
          for (final day in monthDays) {
            if (day <= daysInMonth) {
              final checkDate = DateTime(checkMonth.year, checkMonth.month, day);
              if (!checkDate.isBefore(today)) {
                return checkDate;
              }
            }
          }
        }
        return null;

      case 'yearly':
        if (months.isEmpty) return null;
        // 找今年或明年匹配的月份和日期
        for (int yearOffset = 0; yearOffset < 2; yearOffset++) {
          final checkYear = now.year + yearOffset;
          for (final month in months) {
            if (monthDays.isNotEmpty) {
              for (final day in monthDays) {
                final checkDate = DateTime(checkYear, month, day);
                if (!checkDate.isBefore(today)) {
                  return checkDate;
                }
              }
            } else {
              final checkDate = DateTime(checkYear, month, 1);
              if (!checkDate.isBefore(today)) {
                return checkDate;
              }
            }
          }
        }
        return null;

      case 'custom':
        if (dates.isEmpty) return null;
        for (final dateStr in dates) {
          try {
            final parts = dateStr.split('-');
            final checkDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            if (!checkDate.isBefore(today)) {
              return checkDate;
            }
          } catch (_) {
            continue;
          }
        }
        return null;

      default:
        return null;
    }
  }

  /// 获取提醒计划的文字描述
  String getScheduleDescription() {
    if (!isEnabled) return '未启用';

    final timeStr = time;

    switch (scheduleType) {
      case 'daily':
        return '每日 $timeStr';

      case 'weekly':
        if (weekDays.isEmpty) return '每周 $timeStr';
        final dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final days = weekDays.map((d) => dayNames[d]).join('、');
        return '每周 $days $timeStr';

      case 'monthly':
        if (monthDays.isEmpty) return '每月 $timeStr';
        final days = monthDays.map((d) => '$d日').join('、');
        return '每月 $days $timeStr';

      case 'yearly':
        if (months.isEmpty) return '每年 $timeStr';
        if (monthDays.isNotEmpty) {
          final monthNames = ['', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
          final descs = <String>[];
          for (final month in months) {
            for (final day in monthDays) {
              descs.add('${monthNames[month]}${day}日');
            }
          }
          return '每年 ${descs.join('、')} $timeStr';
        }
        final monthNames = ['', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
        final ms = months.map((m) => monthNames[m]).join('、');
        return '每年 $ms $timeStr';

      case 'custom':
        if (dates.isEmpty) return '自定义 $timeStr';
        return '共 ${dates.length} 个自定义日期 $timeStr';

      default:
        return '提醒 $timeStr';
    }
  }

  // === 辅助方法 ===

  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    }
    return [];
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
