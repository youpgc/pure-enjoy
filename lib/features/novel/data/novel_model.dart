import 'package:hive/hive.dart';

part 'novel_model.g.dart';

/// 小说模型
@HiveType(typeId: 5)
class NovelModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String author;
  
  @HiveField(3)
  final String? coverUrl;
  
  @HiveField(4)
  final String? description;
  
  @HiveField(5)
  final String source; // 来源网站
  
  @HiveField(6)
  final String sourceId; // 在源网站中的ID
  
  @HiveField(7)
  final DateTime addedAt;
  
  @HiveField(8)
  final DateTime? lastReadAt;
  
  @HiveField(9)
  final int lastChapterIndex;
  
  @HiveField(10)
  final double progress; // 阅读进度 0-1
  
  @HiveField(11)
  final bool synced;
  
  NovelModel({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    required this.source,
    required this.sourceId,
    required this.addedAt,
    this.lastReadAt,
    this.lastChapterIndex = 0,
    this.progress = 0.0,
    this.synced = false,
  });
  
  NovelModel copyWith({
    String? id,
    String? title,
    String? author,
    String? coverUrl,
    String? description,
    String? source,
    String? sourceId,
    DateTime? addedAt,
    DateTime? lastReadAt,
    int? lastChapterIndex,
    double? progress,
    bool? synced,
  }) {
    return NovelModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      progress: progress ?? this.progress,
      synced: synced ?? this.synced,
    );
  }
}

/// 小说章节模型（非持久化）
class NovelChapter {
  final int index;
  final String title;
  final String url;
  
  NovelChapter({
    required this.index,
    required this.title,
    required this.url,
  });
}

/// 阅读记录模型（非持久化）
class ReadingRecord {
  final String novelId;
  final int chapterIndex;
  final double position; // 在章节中的阅读位置 0-1
  final DateTime readAt;
  
  ReadingRecord({
    required this.novelId,
    required this.chapterIndex,
    required this.position,
    required this.readAt,
  });
}
