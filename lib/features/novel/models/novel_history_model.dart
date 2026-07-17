/// 阅读历史明细模型 — 对应 reading_history 表
class ReadingHistoryRecord {
  final String id;
  final String userId;
  final String novelId;
  final String? chapterId;
  final int? chapterOrder;
  final int readDurationSeconds;
  final double progress;
  final DateTime createdAt;

  ReadingHistoryRecord({
    required this.id,
    required this.userId,
    required this.novelId,
    this.chapterId,
    this.chapterOrder,
    this.readDurationSeconds = 0,
    this.progress = 0.0,
    required this.createdAt,
  });

  factory ReadingHistoryRecord.fromJson(Map<String, dynamic> json) {
    return ReadingHistoryRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      chapterId: json['chapter_id'] as String?,
      chapterOrder: json['chapter_order'] as int?,
      readDurationSeconds: json['read_duration_seconds'] as int? ?? 0,
      progress: json['progress'] != null ? (json['progress'] as num).toDouble() : 0.0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'chapter_id': chapterId,
      'chapter_order': chapterOrder,
      'read_duration_seconds': readDurationSeconds,
      'progress': progress,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }
}
