/// 问题反馈模型 - 对应 Supabase user_feedback 表
/// 字段: id(UUID), user_id(VARCHAR), title(VARCHAR), description(TEXT), category(VARCHAR), status(VARCHAR), admin_reply(TEXT), is_deleted, created_at
class FeedbackModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String category; // bug / feature / improvement / other
  final String status; // pending / confirmed / in_progress / resolved
  final String? adminReply;
  final String? userNickname;
  final bool isDeleted;
  final DateTime? createdAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.category,
    required this.status,
    this.adminReply,
    this.userNickname,
    this.isDeleted = false,
    this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      status: json['status'] as String,
      adminReply: json['admin_reply'] as String?,
      userNickname: json['user_nickname'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'admin_reply': adminReply,
    };
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'admin_reply': adminReply,
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? category,
    String? status,
    String? adminReply,
    String? userNickname,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      adminReply: adminReply ?? this.adminReply,
      userNickname: userNickname ?? this.userNickname,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
