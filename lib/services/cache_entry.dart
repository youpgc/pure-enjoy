/// 缓存条目
class CacheEntry {
  final String chapterId;
  final String novelId;
  final String title;
  final int chapterOrder;
  final int contentLength;
  final DateTime cachedAt;

  CacheEntry({
    required this.chapterId,
    required this.novelId,
    required this.title,
    required this.chapterOrder,
    required this.contentLength,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
        'chapter_id': chapterId,
        'novel_id': novelId,
        'title': title,
        'chapter_order': chapterOrder,
        'content_length': contentLength,
        'cached_at': cachedAt.toIso8601String(),
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        chapterId: json['chapter_id']?.toString() ?? '',
        novelId: json['novel_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        chapterOrder: json['chapter_order'] is int ? json['chapter_order'] as int : int.tryParse(json['chapter_order']?.toString() ?? '0') ?? 0,
        contentLength: json['content_length'] is int ? json['content_length'] as int : int.tryParse(json['content_length']?.toString() ?? '0') ?? 0,
        cachedAt: DateTime.tryParse(json['cached_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
