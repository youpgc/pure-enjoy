/// 小说评论模型 - 对应 Supabase novel_comments 表
class NovelCommentModel {
  final String id;
  final String novelId;
  final String userId;
  final String? userNickname;
  final String? userAvatar;
  final String content;
  final int? rating; // 1-5 星评分，可选
  final String? parentId; // 回复的根评论 ID
  final String? replyToUserId; // 回复目标用户 ID
  final String? replyToNickname; // 回复目标用户昵称
  final int likeCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  NovelCommentModel({
    required this.id,
    required this.novelId,
    required this.userId,
    this.userNickname,
    this.userAvatar,
    required this.content,
    this.rating,
    this.parentId,
    this.replyToUserId,
    this.replyToNickname,
    this.likeCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory NovelCommentModel.fromJson(Map<String, dynamic> json) {
    return NovelCommentModel(
      id: json['id']?.toString() ?? '',
      novelId: json['novel_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userNickname: json['user_nickname']?.toString() ??
          json['user_metadata']?['nickname']?.toString(),
      userAvatar: json['user_avatar']?.toString() ??
          json['user_metadata']?['avatar_url']?.toString(),
      content: json['content']?.toString() ?? '',
      rating: json['rating'] is int ? json['rating'] as int : null,
      parentId: json['parent_id']?.toString(),
      replyToUserId: json['reply_to_user_id']?.toString(),
      replyToNickname: json['reply_to_nickname']?.toString(),
      likeCount: (json['like_count'] is int ? json['like_count'] as int : 0),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'novel_id': novelId,
      'user_id': userId,
      'content': content,
      if (rating != null) 'rating': rating,
      if (parentId != null) 'parent_id': parentId,
      if (replyToUserId != null) 'reply_to_user_id': replyToUserId,
      if (replyToNickname != null) 'reply_to_nickname': replyToNickname,
      'like_count': likeCount,
    };
  }

  /// 是否为回复（不是根评论）
  bool get isReply => parentId != null;

  /// 显示名称
  String get displayName => userNickname ?? '匿名用户';
}
