import 'package:hive/hive.dart';

part 'mood_diary_model.g.dart';

/// 心情日记模型
@HiveType(typeId: 2)
class MoodDiaryModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String mood; // 表情emoji
  
  @HiveField(2)
  final String? moodLabel; // 心情标签
  
  @HiveField(3)
  final String? content; // 日记内容
  
  @HiveField(4)
  final DateTime date;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final bool synced;
  
  MoodDiaryModel({
    required this.id,
    required this.mood,
    this.moodLabel,
    this.content,
    required this.date,
    required this.createdAt,
    this.synced = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'mood': mood,
    'mood_label': moodLabel,
    'content': content,
    'date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'synced': synced,
  };
  
  factory MoodDiaryModel.fromJson(Map<String, dynamic> json) => MoodDiaryModel(
    id: json['id'],
    mood: json['mood'],
    moodLabel: json['mood_label'],
    content: json['content'],
    date: DateTime.parse(json['date']),
    createdAt: DateTime.parse(json['created_at']),
    synced: json['synced'] ?? true,
  );
}
