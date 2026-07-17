/// 批注高亮颜色枚举
///
/// 序列化值固定为 [Enum.name]（小写），写入 novel_annotations.color，
/// 须与后端 Postgres 枚举标签保持一致：yellow / green / blue / red / pink / purple。
enum AnnotationColor { yellow, green, blue, red, pink, purple }

/// 小说批注/笔记模型 — 对应 novel_annotations 表
class NovelAnnotation {
  final String id;
  final String userId;
  final String novelId;
  final String chapterId;
  final int chapterOrder;
  final int startOffset;
  final int endOffset;
  final String highlightedText;
  final String? note;
  final AnnotationColor color;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  NovelAnnotation({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.chapterId,
    required this.chapterOrder,
    required this.startOffset,
    required this.endOffset,
    required this.highlightedText,
    this.note,
    this.color = AnnotationColor.yellow,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory NovelAnnotation.fromJson(Map<String, dynamic> json) {
    return NovelAnnotation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      chapterId: json['chapter_id'] as String? ?? '',
      chapterOrder: json['chapter_order'] as int? ?? 0,
      startOffset: json['start_offset'] as int? ?? 0,
      endOffset: json['end_offset'] as int? ?? 0,
      highlightedText: json['highlighted_text'] as String? ?? '',
      note: json['note'] as String?,
      color: AnnotationColor.values.firstWhere(
        (e) => e.name == (json['color'] as String? ?? 'yellow'),
        orElse: () => AnnotationColor.yellow,
      ),
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'chapter_id': chapterId,
      'chapter_order': chapterOrder,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'highlighted_text': highlightedText,
      'note': note,
      'color': color.name,
      'is_deleted': isDeleted,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    if (deletedAt != null) json['deleted_at'] = deletedAt!.toUtc().toIso8601String();
    return json;
  }

  NovelAnnotation copyWith({
    String? id,
    String? userId,
    String? novelId,
    String? chapterId,
    int? chapterOrder,
    int? startOffset,
    int? endOffset,
    String? highlightedText,
    String? note,
    AnnotationColor? color,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NovelAnnotation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      novelId: novelId ?? this.novelId,
      chapterId: chapterId ?? this.chapterId,
      chapterOrder: chapterOrder ?? this.chapterOrder,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      highlightedText: highlightedText ?? this.highlightedText,
      note: note ?? this.note,
      color: color ?? this.color,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
