/// 习惯打卡模型 - 对应 Supabase user_habits 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), name(VARCHAR), description(TEXT), frequency(VARCHAR), target_days(INTEGER), start_date(DATE), is_active(BOOLEAN)
class HabitModel {
  final String id;
  final String userId;
  final String? userNickname;
  final String name;
  final String? description;
  final String frequency;
  final int targetDays;
  final DateTime startDate;
  final bool isActive;
  final DateTime? createdAt;

  HabitModel({
    required this.id,
    required this.userId,
    this.userNickname,
    required this.name,
    this.description,
    this.frequency = 'daily',
    this.targetDays = 21,
    DateTime? startDate,
    this.isActive = true,
    this.createdAt,
  }) : startDate = startDate ?? DateTime.now();

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      frequency: json['frequency'] as String? ?? 'daily',
      targetDays: json['target_days'] as int? ?? 21,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': userNickname,
      'name': name,
      'description': description,
      'frequency': frequency,
      'target_days': targetDays,
      'start_date': startDate.toIso8601String().split('T').first,
      'is_active': isActive,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
      'description': description,
      'frequency': frequency,
      'target_days': targetDays,
      'start_date': startDate.toIso8601String().split('T').first,
      'is_active': isActive,
    };
  }

  HabitModel copyWith({
    String? id,
    String? userId,
    String? userNickname,
    String? name,
    String? description,
    String? frequency,
    int? targetDays,
    DateTime? startDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      targetDays: targetDays ?? this.targetDays,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 习惯打卡记录模型 - 对应 Supabase habit_checkins 表
class HabitCheckinModel {
  final String id;
  final String habitId;
  final String userId;
  final DateTime checkinAt;
  final String? note;
  final DateTime? createdAt;

  HabitCheckinModel({
    required this.id,
    required this.habitId,
    required this.userId,
    required this.checkinAt,
    this.note,
    this.createdAt,
  });

  factory HabitCheckinModel.fromJson(Map<String, dynamic> json) {
    return HabitCheckinModel(
      id: json['id'] as String,
      habitId: json['habit_id'] as String,
      userId: json['user_id'] as String,
      checkinAt: DateTime.parse(json['checkin_at'] as String),
      note: json['note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'checkin_at': checkinAt.toIso8601String(),
      'note': note,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
}

/// 习惯颜色选项
final habitColors = {
  'red': 0xFFEF4444,
  'orange': 0xFFF97316,
  'yellow': 0xFFEAB308,
  'green': 0xFF22C55E,
  'blue': 0xFF3B82F6,
  'purple': 0xFF8B5CF6,
  'pink': 0xFFEC4899,
};
