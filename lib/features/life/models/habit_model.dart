/// 习惯打卡模型 - 对应 Supabase habits + habit_records 表
///
/// habits 字段: id(UUID), user_id(VARCHAR50), name(VARCHAR), description(TEXT),
///              target_days(INTEGER), current_streak(INTEGER), longest_streak(INTEGER), is_active(BOOLEAN)
/// habit_records 字段: id(UUID), habit_id(UUID), user_id(VARCHAR50), check_in_date(DATE), note(TEXT)

class HabitModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int targetDays;
  final int currentStreak;
  final int longestStreak;
  final bool isActive;

  HabitModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.targetDays = 21,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.isActive = true,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'description': description,
      'target_days': targetDays,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'is_active': isActive,
    };
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
    );
  }

  /// 获取进度百分比
  double get progress {
    if (targetDays <= 0) return 0;
    return (currentStreak / targetDays).clamp(0.0, 1.0);
  }

  /// 打卡成功后的新模型
  HabitModel checkIn() {
    final newStreak = currentStreak + 1;
    return copyWith(
      currentStreak: newStreak,
      longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
    );
  }
}

/// 习惯打卡记录模型 - 对应 Supabase habit_records 表
class HabitCheckinModel {
  final String id;
  final String habitId;
  final String userId;
  final DateTime checkInDate;
  final String? note;

  HabitCheckinModel({
    required this.id,
    required this.habitId,
    required this.userId,
    required this.checkInDate,
    this.note,
  });

  factory HabitCheckinModel.fromJson(Map<String, dynamic> json) {
    return HabitCheckinModel(
      id: json['id'] as String,
      habitId: json['habit_id'] as String,
      userId: json['user_id'] as String,
      checkInDate: DateTime.parse(json['check_in_date'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'check_in_date': checkInDate.toIso8601String().split('T').first,
      'note': note,
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
