/// 收藏夹模型 - 对应 Supabase favorites 表
/// 字段: id(UUID), user_id(VARCHAR50), title(VARCHAR), url(TEXT), description(TEXT), category(VARCHAR)
class FavoriteModel {
  final String id;
  final String userId;
  final String title;
  final String? url;
  final String? description;
  final String? category;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.title,
    this.url,
    this.description,
    this.category,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      url: json['url'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'url': url,
      'description': description,
      'category': category,
    };
  }

  FavoriteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? url,
    String? description,
    String? category,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      url: url ?? this.url,
      description: description ?? this.description,
      category: category ?? this.category,
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
