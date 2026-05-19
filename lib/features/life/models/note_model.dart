/// 笔记模型 - 对应 Supabase notes 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), title(VARCHAR), content(TEXT), is_pinned(BOOLEAN)
class NoteModel {
  final String id;
  final String userId;
  final String? userNickname;
  final String title;
  final String? content;
  final List<String>? tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.userId,
    this.userNickname,
    required this.title,
    this.content,
    this.tags,
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      title: json['title'] as String,
      content: json['content'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': userNickname,
      'title': title,
      'content': content,
      'tags': tags,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'content': content,
      'tags': tags,
      'is_pinned': isPinned,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? userNickname,
    String? title,
    String? content,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
