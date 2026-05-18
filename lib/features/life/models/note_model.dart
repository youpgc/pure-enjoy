/// 笔记模型 - 对应 Supabase notes 表
/// 字段: id(UUID), user_id(VARCHAR50), title(VARCHAR), content(TEXT), tags(TEXT[]), is_pinned(BOOLEAN)
class NoteModel {
  final String id;
  final String userId;
  final String title;
  final String? content;
  final List<String>? tags;
  final bool isPinned;

  NoteModel({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.tags,
    this.isPinned = false,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'content': content,
      'tags': tags,
      'is_pinned': isPinned,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'content': content,
      'tags': tags,
      'is_pinned': isPinned,
    };
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    List<String>? tags,
    bool? isPinned,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
