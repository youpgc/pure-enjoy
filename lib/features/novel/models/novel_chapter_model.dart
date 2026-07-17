/// 小说章节模型
class NovelChapterModel {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int chapterOrder;
  final int? wordCount;
  final bool? isFree;
  final DateTime createdAt;

  NovelChapterModel({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.chapterOrder,
    this.wordCount,
    this.isFree,
    required this.createdAt,
  });

  factory NovelChapterModel.fromJson(Map<String, dynamic> json) {
    return NovelChapterModel(
      id: json['id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      title: json['title'] as String? ?? '无标题',
      content: json['content'] as String? ?? '',
      chapterOrder: json['chapter_num'] as int? ?? 0,
      wordCount: json['word_count'] as int?,
      isFree: json['is_free'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'novel_id': novelId,
      'title': title,
      'content': content,
      'chapter_num': chapterOrder,
      'word_count': wordCount,
      'is_free': isFree,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    // 只在ID非空时添加，让数据库自动生成新记录的ID
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'content': content,
      'chapter_num': chapterOrder,
      'word_count': wordCount,
      'is_free': isFree,
    };
  }

  NovelChapterModel copyWith({
    String? id,
    String? novelId,
    String? title,
    String? content,
    int? chapterOrder,
    int? wordCount,
    bool? isFree,
    DateTime? createdAt,
  }) {
    return NovelChapterModel(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      title: title ?? this.title,
      content: content ?? this.content,
      chapterOrder: chapterOrder ?? this.chapterOrder,
      wordCount: wordCount ?? this.wordCount,
      isFree: isFree ?? this.isFree,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
