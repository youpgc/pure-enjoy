/// 小说模型
class NovelModel {
  final String id;
  final String? userId;
  final String title;
  final String? author;
  final String? cover;
  final String? description;
  final String? category;
  final String? source;
  final String? sourceUrl;
  final List<String>? tags;
  final int chapterCount;
  final int? wordCount;
  final String? status; // ongoing, completed
  final bool? isFree;
  final double? price;
  final double? rating;
  final int? readCount;
  final int? collectCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  NovelModel({
    required this.id,
    this.userId,
    required this.title,
    this.author,
    this.cover,
    this.description,
    this.category,
    this.source,
    this.sourceUrl,
    this.tags,
    this.chapterCount = 0,
    this.wordCount,
    this.status,
    this.isFree,
    this.price,
    this.rating,
    this.readCount,
    this.collectCount,
    required this.createdAt,
    this.updatedAt,
  });

  factory NovelModel.fromJson(Map<String, dynamic> json) {
    return NovelModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String,
      author: json['author'] as String?,
      cover: json['cover_url'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      source: json['source'] as String?,
      sourceUrl: json['source_url'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      chapterCount: json['chapter_count'] as int? ?? 0,
      wordCount: json['word_count'] as int?,
      status: json['status'] as String?,
      isFree: json['is_free'] as bool?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      readCount: json['read_count'] as int?,
      collectCount: json['collect_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'author': author,
      'cover_url': cover,
      'description': description,
      'category': category,
      'source': source,
      'source_url': sourceUrl,
      'tags': tags,
      'chapter_count': chapterCount,
      'word_count': wordCount,
      'status': status,
      'is_free': isFree,
      'price': price,
      'rating': rating,
      'read_count': readCount,
      'collect_count': collectCount,
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

/// 小说章节模型
class NovelChapterModel {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int chapterOrder;
  final int? chapterNumber;
  final int? wordCount;
  final bool? isFree;
  final DateTime createdAt;

  NovelChapterModel({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.chapterOrder,
    this.chapterNumber,
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
      chapterNumber: json['chapter_num'] as int?,
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
      'chapter_num': chapterNumber ?? chapterOrder,
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

  NovelChapterModel copyWith({
    String? id,
    String? novelId,
    String? title,
    String? content,
    int? chapterOrder,
    int? chapterNumber,
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
      chapterNumber: chapterNumber ?? this.chapterNumber,
      wordCount: wordCount ?? this.wordCount,
      isFree: isFree ?? this.isFree,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 阅读进度模型 - 对应 Supabase user_novels 表
/// 字段: id(UUID), user_id(VARCHAR), novel_id(VARCHAR), progress(DECIMAL), last_chapter(INTEGER), last_read_at(TIMESTAMPTZ), is_collected(BOOLEAN), created_at, updated_at
class ReadingProgressModel {
  final String id;
  final String userId;
  final String novelId;
  final double progress;
  final int? lastChapter;
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
