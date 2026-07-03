import 'package:lunar/lunar.dart';
import '../../../utils/date_time_utils.dart';

/// 纪念日模型 - 对应 Supabase user_anniversaries 表
/// 字段: id(TEXT), user_id(TEXT), user_nickname(TEXT?), title(TEXT), date(DateTime),
///       type(String: birthday/anniversary), description(String?), repeat_yearly(bool),
///       remind_enabled(bool), remind_days_before(int?), is_lunar(bool),
///       created_at(DateTime?)
class AnniversaryModel {
  final String id;
  final String userId;
  final String? userNickname;
  final String title;
  final DateTime date;
  final String type; // 'birthday' 或 'anniversary'
  final String? description;
  final bool repeatYearly;
  final bool remindEnabled;
  final int? remindDaysBefore;
  final bool isLunar;
  final DateTime? createdAt;

  AnniversaryModel({
    required this.id,
    required this.userId,
    this.userNickname,
    required this.title,
    required this.date,
    required this.type,
    this.description,
    this.repeatYearly = true,
    this.remindEnabled = false,
    this.remindDaysBefore,
    this.isLunar = false,
    this.createdAt,
  });

  factory AnniversaryModel.fromJson(Map<String, dynamic> json) {
    return AnniversaryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      title: json['title'] as String,
      date: DateTimeUtils.parseDate(json['date'] as String?) ?? DateTime.now(),
      type: json['type'] as String? ?? 'anniversary',
      description: json['description'] as String?,
      repeatYearly: json['repeat_yearly'] as bool? ?? true,
      remindEnabled: json['remind_enabled'] as bool? ?? false,
      remindDaysBefore: json['remind_days_before'] as int?,
      isLunar: json['is_lunar'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'user_nickname': userNickname,
      'title': title,
      'date': DateTimeUtils.toDateString(date),
      'type': type,
      'description': description,
      'repeat_yearly': repeatYearly,
      'remind_enabled': remindEnabled,
      'remind_days_before': remindDaysBefore,
      'is_lunar': isLunar,
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'user_nickname': userNickname,
      'title': title,
      'date': DateTimeUtils.toDateString(date),
      'type': type,
      'description': description,
      'repeat_yearly': repeatYearly,
      'remind_enabled': remindEnabled,
      'remind_days_before': remindDaysBefore,
      'is_lunar': isLunar,
    };
  }

  AnniversaryModel copyWith({
    String? id,
    String? userId,
    String? userNickname,
    String? title,
    DateTime? date,
    String? type,
    String? description,
    bool? repeatYearly,
    bool? remindEnabled,
    int? remindDaysBefore,
    bool? isLunar,
    DateTime? createdAt,
  }) {
    return AnniversaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      title: title ?? this.title,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      repeatYearly: repeatYearly ?? this.repeatYearly,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      isLunar: isLunar ?? this.isLunar,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 获取农历信息（仅 isLunar 为 true 时有效）
  String get lunarDateStr {
    if (!isLunar) return '';
    try {
      final solar = Solar.fromDate(date);
      final lunar = solar.getLunar();
      final monthStr = lunar.getMonthInChinese();
      final dayStr = lunar.getDayInChinese();
      return '$monthStr月$dayStr';
    } catch (_) {
      return '';
    }
  }

  /// 获取农历年份信息（如"甲辰年"）
  String get lunarYearStr {
    if (!isLunar) return '';
    try {
      final solar = Solar.fromDate(date);
      final lunar = solar.getLunar();
      return '${lunar.getYearInGanZhi()}年';
    } catch (_) {
      return '';
    }
  }

  /// 下一个纪念日的 DateTime（支持农历）
  DateTime get nextDate {
    if (isLunar) {
      return _nextLunarDate();
    }
    return _nextSolarDate();
  }

  /// 公历下一个纪念日
  DateTime _nextSolarDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (type == 'birthday' || repeatYearly) {
      var next = DateTime(now.year, date.month, date.day);
      if (next.isBefore(today) || next.isAtSameMomentAs(today)) {
        next = DateTime(now.year + 1, date.month, date.day);
      }
      return next;
    } else {
      final original = DateTime(date.year, date.month, date.day);
      if (original.isBefore(today) || original.isAtSameMomentAs(today)) {
        return original;
      }
      return original;
    }
  }

  /// 农历下一个纪念日
  DateTime _nextLunarDate() {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (!repeatYearly) {
        // 非重复农历纪念日，返回原日期
        return DateTime(date.year, date.month, date.day);
      }

      // 从存储的公历日期反推农历月日
      final solar = Solar.fromDate(date);
      final lunar = solar.getLunar();
      final lunarMonth = lunar.getMonth();
      final lunarDay = lunar.getDay();

      // 计算今年的农历对应公历日期
      var thisYearLunar = Lunar.fromYmd(now.year, lunarMonth, lunarDay);
      var thisYearSolar = thisYearLunar.getSolar();

      // 如果今年还没到，就用今年的
      var nextSolar = DateTime(thisYearSolar.getYear(), thisYearSolar.getMonth(), thisYearSolar.getDay());
      if (nextSolar.isBefore(today) || nextSolar.isAtSameMomentAs(today)) {
        // 今年的已过，算明年的
        var nextYearLunar = Lunar.fromYmd(now.year + 1, lunarMonth, lunarDay);
        var nextYearSolar = nextYearLunar.getSolar();
        nextSolar = DateTime(nextYearSolar.getYear(), nextYearSolar.getMonth(), nextYearSolar.getDay());
      }

      return nextSolar;
    } catch (_) {
      // 农历计算异常时回退到公历计算
      return _nextSolarDate();
    }
  }

  /// 距离下一个纪念日的天数
  int get daysUntilNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = nextDate;
    final nextDay = DateTime(next.year, next.month, next.day);
    return nextDay.difference(today).inDays;
  }

  /// 如果 type 是 birthday，根据 date 计算当前年龄
  int? get age {
    if (type != 'birthday') return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (isLunar) {
      // 农历生日：根据农历计算年龄
      var age = now.year - date.year;
      // 检查今年的农历生日是否已过
      final solar = Solar.fromDate(date);
      final lunar = solar.getLunar();
      var thisYearLunar = Lunar.fromYmd(now.year, lunar.getMonth(), lunar.getDay());
      var thisYearSolar = thisYearLunar.getSolar();
      var thisYearBirthday = DateTime(thisYearSolar.getYear(), thisYearSolar.getMonth(), thisYearSolar.getDay());

      if (thisYearBirthday.isAfter(today)) {
        age--;
      }
      return age >= 0 ? age : 0;
    }

    // 公历生日
    var age = now.year - date.year;
    final thisYearBirthday = DateTime(now.year, date.month, date.day);

    if (thisYearBirthday.isAfter(today)) {
      age--;
    }

    return age >= 0 ? age : 0;
  }
}
