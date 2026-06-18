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
    DateTime parseDate(dynamic value, String fieldName) {
      if (value == null) {
        throw FormatException('字段 $fieldName 不能为 null');
      }
      try {
        return DateTime.parse(value as String);
      } catch (e) {
        throw FormatException('字段 $fieldName 日期格式错误: $value');
      }
    }

    return MoodDiaryModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      mood: json['mood']?.toString() ?? '',
      moodScore: int.tryParse(json['mood_label']?.toString() ?? '5') ?? 5,
      content: json['content']?.toString(),
      entryDate: parseDate(json['date'], 'date'),
      userNickname: json['user_nickname']?.toString(),
      synced: json['synced'] as bool?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'user_nickname': userNickname,
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
