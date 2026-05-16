/// 提醒事项模型
class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime remindAt;
  final bool isCompleted;
  final String priority; // high, normal, low
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReminderModel({
    required this.id,
    this.userId = 'local_user',
    required this.title,
    this.description,
    required this.remindAt,
    this.isCompleted = false,
    this.priority = 'normal',
    required this.createdAt,
    this.updatedAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? 'local_user',
      title: json['title'] as String,
      description: json['description'] as String?,
      remindAt: DateTime.parse(json['remind_at'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'normal',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'remind_at': remindAt.toIso8601String(),
      'is_completed': isCompleted,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
    DateTime? updatedAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取优先级颜色
  String get priorityLabel {
    switch (priority) {
      case 'high':
        return '高';
      case 'low':
        return '低';
      default:
        return '普通';
    }
  }

  /// 是否已过期
  bool get isOverdue {
    return !isCompleted && remindAt.isBefore(DateTime.now());
  }
}
