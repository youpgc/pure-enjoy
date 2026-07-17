/// 书签类型枚举
///
/// 序列化值固定为 [Enum.name]（小写），写入 novel_bookmarks.bookmark_type，
/// 须与后端 Postgres 枚举标签保持一致：
/// - [auto]   → 'auto'
/// - [manual] → 'manual'
enum BookmarkType { auto, manual }

/// 小说书签模型 — 对应 novel_bookmarks 表
class NovelBookmark {
  final String id;
  final String userId;
  final String novelId;
  final String chapterId;
  final int chapterOrder;
  final int charOffset;
  final String? note;
  final BookmarkType type;
  final DateTime createdAt;

  NovelBookmark({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.chapterId,
    required this.chapterOrder,
    this.charOffset = 0,
    this.note,
    this.type = BookmarkType.manual,
    required this.createdAt,
  });

  factory NovelBookmark.fromJson(Map<String, dynamic> json) {
    return NovelBookmark(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      chapterId: json['chapter_id'] as String? ?? '',
      chapterOrder: json['chapter_order'] as int? ?? 0,
      charOffset: json['char_offset'] as int? ?? 0,
      note: json['note'] as String?,
      type: BookmarkType.values.firstWhere(
        (e) => e.name == (json['bookmark_type'] as String? ?? 'manual'),
        orElse: () => BookmarkType.manual,
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'chapter_id': chapterId,
      'chapter_order': chapterOrder,
      'char_offset': charOffset,
      'note': note,
      'bookmark_type': type.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }

  NovelBookmark copyWith({
    String? id,
    String? userId,
    String? novelId,
    String? chapterId,
    int? chapterOrder,
    int? charOffset,
    String? note,
    BookmarkType? type,
    DateTime? createdAt,
  }) {
    return NovelBookmark(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      novelId: novelId ?? this.novelId,
      chapterId: chapterId ?? this.chapterId,
      chapterOrder: chapterOrder ?? this.chapterOrder,
      charOffset: charOffset ?? this.charOffset,
      note: note ?? this.note,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
