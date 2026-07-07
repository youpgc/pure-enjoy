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

// ============================================================
// 6.1 基础体验 — 新增数据模型
// ============================================================

/// 书签类型枚举
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

/// 批注高亮颜色枚举
enum AnnotationColor { yellow, green, blue, red }

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

/// 推荐反馈类型枚举
enum RecommendationFeedbackType { click, dismiss, collect, read, notInterested }

/// 用户推荐反馈模型 — 对应 user_recommendation_feedback 表
class UserRecommendationFeedback {
  final String id;
  final String userId;
  final String novelId;
  final RecommendationFeedbackType feedbackType;
  final DateTime createdAt;

  UserRecommendationFeedback({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.feedbackType,
    required this.createdAt,
  });

  factory UserRecommendationFeedback.fromJson(Map<String, dynamic> json) {
    return UserRecommendationFeedback(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      feedbackType: RecommendationFeedbackType.values.firstWhere(
        (e) => e.name == (json['feedback_type'] as String? ?? 'click'),
        orElse: () => RecommendationFeedbackType.click,
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'feedback_type': feedbackType.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }
}

/// TTS播放模式枚举
enum TtsPlaybackMode { sentence, paragraph, chapter }

/// TTS播放日志模型 — 对应 tts_playback_logs 表
class TtsPlaybackLog {
  final String id;
  final String userId;
  final String novelId;
  final String chapterId;
  final int startSentenceIndex;
  final int? endSentenceIndex;
  final int? durationSeconds;
  final double speechRate;
  final TtsPlaybackMode playbackMode;
  final DateTime createdAt;

  TtsPlaybackLog({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.chapterId,
    this.startSentenceIndex = 0,
    this.endSentenceIndex,
    this.durationSeconds,
    this.speechRate = 1.0,
    this.playbackMode = TtsPlaybackMode.sentence,
    required this.createdAt,
  });

  factory TtsPlaybackLog.fromJson(Map<String, dynamic> json) {
    return TtsPlaybackLog(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      chapterId: json['chapter_id'] as String? ?? '',
      startSentenceIndex: json['start_sentence_index'] as int? ?? 0,
      endSentenceIndex: json['end_sentence_index'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      speechRate: json['speech_rate'] != null ? (json['speech_rate'] as num).toDouble() : 1.0,
      playbackMode: TtsPlaybackMode.values.firstWhere(
        (e) => e.name == (json['playback_mode'] as String? ?? 'sentence'),
        orElse: () => TtsPlaybackMode.sentence,
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'chapter_id': chapterId,
      'start_sentence_index': startSentenceIndex,
      'end_sentence_index': endSentenceIndex,
      'duration_seconds': durationSeconds,
      'speech_rate': speechRate,
      'playback_mode': playbackMode.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }
}

/// 排行榜类型枚举
enum RankingType { read, collect, rating, newBook, completed }

/// 排行榜时间维度枚举
enum RankingTimeRange { daily, weekly, monthly, allTime }

/// 排行榜项模型
class RankingItem {
  final String novelId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? category;
  final String? status;
  final int totalReads;
  final int totalCollects;
  final double avgRating;
  final int ratingCount;
  final int periodReads;
  final int periodCollects;
  final DateTime? createdAt;

  RankingItem({
    required this.novelId,
    required this.title,
    this.author,
    this.coverUrl,
    this.category,
    this.status,
    this.totalReads = 0,
    this.totalCollects = 0,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.periodReads = 0,
    this.periodCollects = 0,
    this.createdAt,
  });

  factory RankingItem.fromJson(Map<String, dynamic> json) {
    return RankingItem(
      novelId: json['novel_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
      category: json['category'] as String?,
      status: json['status'] as String?,
      totalReads: json['total_reads'] as int? ?? 0,
      totalCollects: json['total_collects'] as int? ?? 0,
      avgRating: json['avg_rating'] != null ? (json['avg_rating'] as num).toDouble() : 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      periodReads: json['period_reads'] as int? ?? json['daily_reads'] as int? ?? json['weekly_reads'] as int? ?? json['monthly_reads'] as int? ?? 0,
      periodCollects: json['period_collects'] as int? ?? json['daily_collects'] as int? ?? json['weekly_collects'] as int? ?? json['monthly_collects'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
