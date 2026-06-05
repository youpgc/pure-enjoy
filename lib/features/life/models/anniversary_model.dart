/// 纪念日模型 - 对应 Supabase user_anniversaries 表
/// 字段: id(TEXT), user_id(TEXT), user_nickname(TEXT?), title(TEXT), date(DateTime),
///       type(String: birthday/anniversary), description(String?), repeat_yearly(bool),
///       remind_enabled(bool), remind_days_before(int?), created_at(DateTime?)
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
    this.createdAt,
  });

  factory AnniversaryModel.fromJson(Map<String, dynamic> json) {
    return AnniversaryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
      type: json['type'] as String? ?? 'anniversary',
      description: json['description'] as String?,
      repeatYearly: json['repeat_yearly'] as bool? ?? true,
      remindEnabled: json['remind_enabled'] as bool? ?? false,
      remindDaysBefore: json['remind_days_before'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': userNickname,
      'title': title,
      'date': date.toUtc().toIso8601String(),
      'type': type,
      'description': description,
      'repeat_yearly': repeatYearly,
      'remind_enabled': remindEnabled,
      'remind_days_before': remindDaysBefore,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'user_nickname': userNickname,
      'title': title,
      'date': date.toUtc().toIso8601String(),
      'type': type,
      'description': description,
      'repeat_yearly': repeatYearly,
      'remind_enabled': remindEnabled,
      'remind_days_before': remindDaysBefore,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 下一个纪念日的 DateTime
  DateTime get nextDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (type == 'birthday' || repeatYearly) {
      // 计算今年的纪念日/生日
      var next = DateTime(now.year, date.month, date.day);
      if (next.isBefore(today) || next.isAtSameMomentAs(today)) {
        // 如果今天已经过了，算明年的
        next = DateTime(now.year + 1, date.month, date.day);
      }
      return next;
    } else {
      // 非重复纪念日，如果已过则返回原日期
      final original = DateTime(date.year, date.month, date.day);
      if (original.isBefore(today) || original.isAtSameMomentAs(today)) {
        return original;
      }
      return original;
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
    final birthDate = DateTime(date.year, date.month, date.day);

    // 如果今年的生日还没到，年龄 = 当前年份 - 出生年份 - 1
    // 如果今年的生日已过，年龄 = 当前年份 - 出生年份
    var age = now.year - date.year;
    final thisYearBirthday = DateTime(now.year, date.month, date.day);

    if (thisYearBirthday.isAfter(today)) {
      age--;
    }

    return age >= 0 ? age : 0;
  }
}
