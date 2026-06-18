/// 习惯模型 - 对应 Supabase habits 表
/// 字段: id(UUID), user_id(VARCHAR), name(VARCHAR), description(TEXT), target_days(INTEGER), current_streak(INTEGER), longest_streak(INTEGER), is_active(BOOLEAN), created_at, updated_at
class HabitModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int targetDays;
  final int currentStreak;
  final int longestStreak;
  final bool isActive;
  final DateTime? createdAt;

  HabitModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.targetDays = 21,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetDays: json['target_days'] as int? ?? 21,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'description': description,
      'target_days': targetDays,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'is_active': isActive,
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
      'description': description,
      'target_days': targetDays,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'is_active': isActive,
    };
  }

  HabitModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    int? targetDays,
    int? currentStreak,
    int? longestStreak,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      targetDays: targetDays ?? this.targetDays,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 习惯打卡记录模型 - 对应 Supabase habit_checkins 表
/// 字段: id(UUID), habit_id(UUID), checkin_at(TIMESTAMPTZ), note(TEXT), created_at
class HabitCheckinModel {
  final String id;
  final String habitId;
  final DateTime checkinAt;
  final String? note;
  final DateTime? createdAt;

  HabitCheckinModel({
    required this.id,
    required this.habitId,
    required this.checkinAt,
    this.note,
    this.createdAt,
  });

  factory HabitCheckinModel.fromJson(Map<String, dynamic> json) {
    return HabitCheckinModel(
      id: json['id'] as String,
      habitId: json['habit_id'] as String,
      checkinAt: DateTime.parse(json['checkin_at'] as String).toLocal(),
      note: json['note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'habit_id': habitId,
      'checkin_at': checkinAt.toUtc().toIso8601String(),
      'note': note,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
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
