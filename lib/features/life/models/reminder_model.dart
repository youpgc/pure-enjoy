/// 提醒事项模型 - 对应 Supabase user_reminders 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), title(VARCHAR), description(TEXT), remind_at(TIMESTAMPTZ), is_completed(BOOLEAN), repeat_type(VARCHAR)
class ReminderModel {
  final String id;
  final String userId;
  final String? userNickname;
  final String title;
  final String? description;
  final DateTime remindAt;
  final bool isCompleted;
  final String? repeatType;
  final DateTime? createdAt;

  ReminderModel({
    required this.id,
    required this.userId,
    this.userNickname,
    required this.title,
    this.description,
    required this.remindAt,
    this.isCompleted = false,
    this.repeatType,
    this.createdAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      remindAt: DateTime.parse(json['remind_at'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
      repeatType: json['repeat_type'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'user_nickname': userNickname,
      'title': title,
      'description': description,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'is_completed': isCompleted,
      'repeat_type': repeatType,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'description': description,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'is_completed': isCompleted,
      'repeat_type': repeatType,
    };
  }

  ReminderModel copyWith({
    String? id,
    String? userId,
    String? userNickname,
    String? title,
    String? description,
    DateTime? remindAt,
    bool? isCompleted,
    String? repeatType,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      title: title ?? this.title,
      description: description ?? this.description,
      remindAt: remindAt ?? this.remindAt,
      isCompleted: isCompleted ?? this.isCompleted,
      repeatType: repeatType ?? this.repeatType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 是否已过期
  bool get isOverdue {
    return !isCompleted && remindAt.isBefore(DateTime.now());
  }
}
