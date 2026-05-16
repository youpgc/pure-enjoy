/// 习惯打卡模型
class HabitModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String frequency; // daily, weekly
  final int targetDays;
  final int currentStreak;
  final int maxStreak;
  final int totalCheckins;
  final String color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HabitModel({
    required this.id,
    this.userId = 'local_user',
    required this.name,
    this.description,
    this.frequency = 'daily',
    this.targetDays = 21,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.totalCheckins = 0,
    this.color = 'blue',
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? 'local_user',
      name: json['name'] as String,
      description: json['description'] as String?,
      frequency: json['frequency'] as String? ?? 'daily',
      targetDays: json['target_days'] as int? ?? 21,
      currentStreak: json['current_streak'] as int? ?? 0,
      maxStreak: json['max_streak'] as int? ?? 0,
      totalCheckins: json['total_checkins'] as int? ?? 0,
      color: json['color'] as String? ?? 'blue',
      isActive: json['is_active'] as bool? ?? true,
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
      'name': name,
      'description': description,
      'frequency': frequency,
      'target_days': targetDays,
      'current_streak': currentStreak,
      'max_streak': maxStreak,
      'total_checkins': totalCheckins,
      'color': color,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  HabitModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? frequency,
    int? targetDays,
    int? currentStreak,
    int? maxStreak,
    int? totalCheckins,
    String? color,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      targetDays: targetDays ?? this.targetDays,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      totalCheckins: totalCheckins ?? this.totalCheckins,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取频率标签
  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      default:
        return '每天';
    }
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
      maxStreak: newStreak > maxStreak ? newStreak : maxStreak,
      totalCheckins: totalCheckins + 1,
      updatedAt: DateTime.now(),
    );
  }
}

/// 习惯打卡记录模型
class HabitCheckinModel {
  final String id;
  final String habitId;
  final String userId;
  final DateTime checkinAt;
  final String? note;
  final DateTime createdAt;

  HabitCheckinModel({
    required this.id,
    required this.habitId,
    this.userId = 'local_user',
    required this.checkinAt,
    this.note,
    required this.createdAt,
  });

  factory HabitCheckinModel.fromJson(Map<String, dynamic> json) {
    return HabitCheckinModel(
      id: json['id'] as String,
      habitId: json['habit_id'] as String,
      userId: json['user_id'] as String? ?? 'local_user',
      checkinAt: DateTime.parse(json['checkin_at'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'checkin_at': checkinAt.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
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
