import '../../../services/supabase_service.dart';

/// 收藏夹模型 - 对应 Supabase user_favorites 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), title(VARCHAR), url(TEXT), description(TEXT), category(VARCHAR), is_pinned(BOOLEAN)
class FavoriteModel {
  final String id;
  final String userId;
  final String title;
  final String? url;
  final String? description;
  final String? category;
  final bool isPinned;
  final DateTime? createdAt;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.title,
    this.url,
    this.description,
    this.category,
    this.isPinned = false,
    this.createdAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      url: json['url'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': AuthService.instance.currentUserName,
      'title': title,
      'url': url,
      'description': description,
      'category': category,
      'is_pinned': isPinned,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  FavoriteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? url,
    String? description,
    String? category,
    bool? isPinned,
    DateTime? createdAt,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      url: url ?? this.url,
      description: description ?? this.description,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
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
