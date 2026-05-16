/// 收藏夹模型
class FavoriteModel {
  final String id;
  final String userId;
  final String title;
  final String? url;
  final String? category;
  final List<String>? tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FavoriteModel({
    required this.id,
    this.userId = 'local_user',
    required this.title,
    this.url,
    this.category,
    this.tags,
    this.isPinned = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? 'local_user',
      title: json['title'] as String,
      url: json['url'] as String?,
      category: json['category'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'url': url,
      'category': category,
      'tags': tags,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  FavoriteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? url,
    String? category,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      url: url ?? this.url,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 收藏分类
enum FavoriteCategory {
  article('文章'),
  video('视频'),
  tool('工具'),
  website('网站'),
  other('其他');

  final String label;

  const FavoriteCategory(this.label);
}
