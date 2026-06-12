/// 心情日记模型 - 对应 Supabase mood_diaries 表
/// 字段: id(UUID), user_id(VARCHAR), mood(VARCHAR), mood_label(VARCHAR), content(TEXT), date(DATE), created_at, updated_at
class MoodDiaryModel {
  final String id;
  final String userId;
  final String mood;
  final int moodScore;
  final String? content;
  final List<String>? tags;
  final DateTime entryDate;
  final DateTime? createdAt;

  MoodDiaryModel({
    required this.id,
    required this.userId,
    required this.mood,
    required this.moodScore,
    this.content,
    this.tags,
    required this.entryDate,
    this.createdAt,
  });

  factory MoodDiaryModel.fromJson(Map<String, dynamic> json) {
    return MoodDiaryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mood: json['mood'] as String,
      moodScore: int.tryParse(json['mood_label']?.toString() ?? '5') ?? 5,
      content: json['content'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      entryDate: DateTime.parse(json['date'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'mood': mood,
      'mood_label': moodScore.toString(),
      'content': content,
      'tags': tags,
      'date': entryDate.toIso8601String().split('T').first,
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  MoodDiaryModel copyWith({
    String? id,
    String? userId,
    String? mood,
    int? moodScore,
    String? content,
    List<String>? tags,
    DateTime? entryDate,
    DateTime? createdAt,
  }) {
    return MoodDiaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      moodScore: moodScore ?? this.moodScore,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


