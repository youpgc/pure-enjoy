/// 推荐反馈类型枚举
///
/// 序列化值固定为 [Enum.name]，写入 user_recommendation_feedback.feedback_type，
/// 须与后端 Postgres 枚举标签保持一致：
/// - [click]          → 'click'
/// - [dismiss]        → 'dismiss'
/// - [collect]        → 'collect'
/// - [read]           → 'read'
/// - [notInterested]  → 'notInterested'（⚠️ 跨端对齐重点：后端枚举若用 snake_case
///   应为 'not_interested'，需与后端确认；当前沿用 .name 以保持现有可用行为）
enum RecommendationFeedbackType { click, dismiss, collect, read, notInterested }

/// 用户推荐反馈模型 — 对应 user_recommendation_feedback 表
class UserRecommendationFeedback {
  final String id;
  final String userId;
  final String novelId;
  final RecommendationFeedbackType feedbackType;
  final DateTime createdAt;

  UserRecommendationFeedback({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.feedbackType,
    required this.createdAt,
  });

  factory UserRecommendationFeedback.fromJson(Map<String, dynamic> json) {
    return UserRecommendationFeedback(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      feedbackType: RecommendationFeedbackType.values.firstWhere(
        (e) => e.name == (json['feedback_type'] as String? ?? 'click'),
        orElse: () => RecommendationFeedbackType.click,
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'feedback_type': feedbackType.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }
}
