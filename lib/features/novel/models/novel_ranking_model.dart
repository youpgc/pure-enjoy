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
