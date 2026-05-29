/// 提醒事项模型 - 对应 Supabase user_reminders 表
/// 字段: id(UUID), user_id(VARCHAR), title(VARCHAR), description(TEXT), remind_at(TIMESTAMPTZ), is_completed(BOOLEAN), priority(VARCHAR), created_at, updated_at
class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime remindAt;
  final bool isCompleted;
  final String? priority;
  final DateTime? createdAt;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.remindAt,
    this.isCompleted = false,
    this.priority,
    this.createdAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      remindAt: DateTime.parse(json['remind_at'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
      priority: json['priority'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'is_completed': isCompleted,
      'priority': priority,
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
      'priority': priority,
    };
  }

  ReminderModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? remindAt,
    bool? isCompleted,
    String? priority,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      remindAt: remindAt ?? this.remindAt,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 是否已过期
  bool get isOverdue {
    return !isCompleted && remindAt.isBefore(DateTime.now());
  }
}
