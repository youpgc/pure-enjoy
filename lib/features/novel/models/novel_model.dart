/// 小说模型
class NovelModel {
  final String id;
  final String title;
  final String? author;
  final String? cover;
  final String? description;
  final String? category;
  final int chapterCount;
  final String? status; // ongoing, completed
  final DateTime createdAt;
  final DateTime? updatedAt;

  NovelModel({
    required this.id,
    required this.title,
    this.author,
    this.cover,
    this.description,
    this.category,
    this.chapterCount = 0,
    this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory NovelModel.fromJson(Map<String, dynamic> json) {
    return NovelModel(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      cover: json['cover_url'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      chapterCount: json['chapter_count'] as int? ?? 0,
      status: json['status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_url': cover,
      'description': description,
      'category': category,
      'chapter_count': chapterCount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// 小说章节模型
class NovelChapterModel {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int chapterOrder;
  final int? wordCount;
  final bool? isFree;
  final double? price;
  final DateTime createdAt;

  NovelChapterModel({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.chapterOrder,
    this.wordCount,
    this.isFree,
    this.price,
    required this.createdAt,
  });

  factory NovelChapterModel.fromJson(Map<String, dynamic> json) {
    return NovelChapterModel(
      id: json['id'] as String,
      novelId: json['novel_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      chapterOrder: json['chapter_num'] as int? ?? 0,
      wordCount: json['word_count'] as int?,
      isFree: json['is_free'] as bool?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'novel_id': novelId,
      'title': title,
      'content': content,
      'chapter_num': chapterOrder,
      'word_count': wordCount,
      'is_free': isFree,
      'price': price,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 阅读进度模型
class ReadingProgressModel {
  final String id;
  final String userId;
  final String novelId;
  final String? currentChapterId;
  final int currentPosition;
  final DateTime lastReadAt;

  ReadingProgressModel({
    required this.id,
    required this.userId,
    required this.novelId,
    this.currentChapterId,
    this.currentPosition = 0,
    required this.lastReadAt,
  });

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) {
    return ReadingProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      novelId: json['novel_id'] as String,
      currentChapterId: json['current_chapter_id'] as String?,
      currentPosition: json['current_position'] as int? ?? 0,
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'novel_id': novelId,
      'current_chapter_id': currentChapterId,
      'current_position': currentPosition,
      'last_read_at': lastReadAt.toIso8601String(),
    };
  }
}
