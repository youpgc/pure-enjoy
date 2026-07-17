/// 阅读进度模型 - 对应 Supabase user_novels 表
/// 字段: id(UUID), user_id(VARCHAR), novel_id(VARCHAR), progress(DECIMAL), last_chapter(INTEGER), last_read_at(TIMESTAMPTZ), is_collected(BOOLEAN), created_at, updated_at
class ReadingProgressModel {
  final String id;
  final String userId;
  final String novelId;
  final double progress;
  final int? lastChapter;
  final int? lastCharOffset;
  final String? readingStatus;
  final bool? isCollected;
  final DateTime? lastReadAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReadingProgressModel({
    required this.id,
    required this.userId,
    required this.novelId,
    this.progress = 0.0,
    this.lastChapter,
    this.lastCharOffset,
    this.readingStatus,
    this.isCollected,
    this.lastReadAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) {
    return ReadingProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      novelId: json['novel_id'] as String,
      progress: json['progress'] != null ? (json['progress'] as num).toDouble() : 0.0,
      lastChapter: json['last_chapter'] as int?,
      lastCharOffset: json['last_char_offset'] as int?,
      readingStatus: json['reading_status'] as String?,
      isCollected: json['is_collected'] as bool?,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'progress': progress,
      'last_chapter': lastChapter,
      'last_char_offset': lastCharOffset,
      'reading_status': readingStatus,
      'is_collected': isCollected,
      'last_read_at': lastReadAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
    // 只在ID非空时添加，让数据库自动生成新记录的ID
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }
}
