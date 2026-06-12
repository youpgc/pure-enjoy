/// 心情日记模型 - 对应 Supabase mood_diaries 表
/// 字段: id(UUID), user_id(VARCHAR), mood(VARCHAR), mood_label(VARCHAR), content(TEXT), date(DATE), created_at, updated_at
class MoodDiaryModel {
  final String id;
  final String userId;
  final String mood;
  final int moodScore;
  final String? content;
  final DateTime entryDate;
  final String? userNickname;
  final bool? synced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MoodDiaryModel({
    required this.id,
    required this.userId,
    required this.mood,
    required this.moodScore,
    this.content,
    required this.entryDate,
    this.userNickname,
    this.synced,
    this.createdAt,
    this.updatedAt,
  });

  factory MoodDiaryModel.fromJson(Map<String, dynamic> json) {
    return MoodDiaryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mood: json['mood'] as String,
      moodScore: int.tryParse(json['mood_label']?.toString() ?? '5') ?? 5,
      content: json['content'] as String?,
      entryDate: DateTime.parse(json['date'] as String),
      userNickname: json['user_nickname'] as String?,
      synced: json['synced'] as bool?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'mood': mood,
      'mood_label': moodScore.toString(),
      'content': content,
      'date': entryDate.toIso8601String().split('T').first,
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  /// 转换为更新用的 JSON（不包含 user_id）
  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      'mood': mood,
      'mood_label': moodScore.toString(),
      'content': content,
      'date': entryDate.toIso8601String().split('T').first,
    };
  }

  MoodDiaryModel copyWith({
    String? id,
    String? userId,
    String? mood,
    int? moodScore,
    String? content,
    DateTime? entryDate,
    String? userNickname,
    bool? synced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoodDiaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      moodScore: moodScore ?? this.moodScore,
      content: content ?? this.content,
      entryDate: entryDate ?? this.entryDate,
      userNickname: userNickname ?? this.userNickname,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
