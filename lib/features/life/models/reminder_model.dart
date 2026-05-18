/// 提醒事项模型 - 对应 Supabase reminders 表
/// 字段: id(UUID), user_id(VARCHAR50), title(VARCHAR), description(TEXT), remind_at(TIMESTAMPTZ), is_completed(BOOLEAN)
class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime remindAt;
  final bool isCompleted;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.remindAt,
    this.isCompleted = false,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      remindAt: DateTime.parse(json['remind_at'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'is_completed': isCompleted,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'description': description,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'is_completed': isCompleted,
    };
  }

  ReminderModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? remindAt,
    bool? isCompleted,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      remindAt: remindAt ?? this.remindAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// 是否已过期
  bool get isOverdue {
    return !isCompleted && remindAt.isBefore(DateTime.now());
  }
}
