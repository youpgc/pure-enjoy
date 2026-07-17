export 'novel_chapter_model.dart';
export 'novel_reading_progress_model.dart';
export 'novel_bookmark_model.dart';
export 'novel_annotation_model.dart';
export 'novel_history_model.dart';
export 'novel_recommendation_model.dart';
export 'novel_tts_model.dart';
export 'novel_ranking_model.dart';

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
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString(),
      cover: json['cover_url']?.toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      source: json['source']?.toString(),
      sourceUrl: json['source_url']?.toString(),
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      chapterCount: json['chapter_count'] as int? ?? 0,
      wordCount: json['word_count'] as int?,
      status: json['status']?.toString(),
      isFree: json['is_free'] as bool?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      readCount: json['read_count'] as int?,
      collectCount: json['collect_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
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

  Map<String, dynamic> toJsonForUpdate() {
    return {
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
    };
  }

  NovelModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? author,
    String? cover,
    String? description,
    String? category,
    String? source,
    String? sourceUrl,
    List<String>? tags,
    int? chapterCount,
    int? wordCount,
    String? status,
    bool? isFree,
    double? price,
    double? rating,
    int? readCount,
    int? collectCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NovelModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      description: description ?? this.description,
      category: category ?? this.category,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      tags: tags ?? this.tags,
      chapterCount: chapterCount ?? this.chapterCount,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
      isFree: isFree ?? this.isFree,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      readCount: readCount ?? this.readCount,
      collectCount: collectCount ?? this.collectCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
