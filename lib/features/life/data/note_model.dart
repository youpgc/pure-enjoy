import 'package:hive/hive.dart';

part 'note_model.g.dart';

/// 笔记本模型
@HiveType(typeId: 4)
class NoteModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String? content;
  
  @HiveField(3)
  final String? category;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final DateTime updatedAt;
  
  @HiveField(6)
  final bool pinned; // 是否置顶
  
  @HiveField(7)
  final bool synced;
  
  NoteModel({
    required this.id,
    required this.title,
    this.content,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.synced = false,
  });
  
  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pinned,
    bool? synced,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      synced: synced ?? this.synced,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'pinned': pinned,
    'synced': synced,
  };
  
  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    category: json['category'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
    pinned: json['pinned'] ?? false,
    synced: json['synced'] ?? true,
  );
}
