/// 笔记模型 - 对应 Supabase notes 表
/// 字段: id(UUID), user_id(VARCHAR), title(VARCHAR), content(TEXT), category(VARCHAR), tags(TEXT[]), is_pinned(BOOLEAN), created_at, updated_at
class NoteModel {
  final String id;
  final String userId;
  final String title;
  final String? content;
  final String? category;
  final List<String>? tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.category,
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
      title: json['title'] as String,
      content: json['content'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'is_pinned': isPinned,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? category,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
