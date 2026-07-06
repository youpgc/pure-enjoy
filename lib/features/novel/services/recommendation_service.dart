import '../../../services/api_client.dart';
import '../../../services/session_manager.dart';
import '../models/novel_model.dart';

/// 推荐服务
/// 提供"猜你喜欢"推荐列表和反馈记录
class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  String? get _userId => SessionManager.instance.currentUserId;

  /// 获取推荐列表
  ///
  /// 调用 Supabase RPC 函数 fn_get_recommendations
  Future<List<NovelModel>> getRecommendations({int limit = 10}) async {
    final userId = _userId;
    if (userId == null) return [];

    final result = await ApiClient.rpc(
      'fn_get_recommendations',
      params: {
        'p_user_id': userId,
        'p_limit': limit,
      },
    );

    if (result.isSuccess && result.data != null) {
      return result.data!.map((json) {
        // RPC 返回的字段需要映射为 NovelModel 的字段
        final mapped = <String, dynamic>{
          'id': json['novel_id'],
          'title': json['title'],
          'author': json['author'],
          'cover_url': json['cover_url'],
          'recommendation_score': json['recommendation_score'],
          'recommendation_reason': json['reason'],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        return NovelModel.fromJson(mapped);
      }).toList();
    }
    return [];
  }

  /// 记录推荐反馈
  Future<bool> recordFeedback({
    required String novelId,
    required RecommendationFeedbackType feedbackType,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    final feedback = UserRecommendationFeedback(
      id: '',
      userId: userId,
      novelId: novelId,
      feedbackType: feedbackType,
      createdAt: DateTime.now(),
    );

    final result = await ApiClient.post(
      'user_recommendation_feedback',
      feedback.toJson(),
    );
    return result.isSuccess;
  }

  /// 标记"不感兴趣"
  Future<bool> markNotInterested(String novelId) async {
    return recordFeedback(
      novelId: novelId,
      feedbackType: RecommendationFeedbackType.notInterested,
    );
  }

  /// 标记"点击"
  Future<bool> markClicked(String novelId) async {
    return recordFeedback(
      novelId: novelId,
      feedbackType: RecommendationFeedbackType.click,
    );
  }

  /// 标记"收藏"
  Future<bool> markCollected(String novelId) async {
    return recordFeedback(
      novelId: novelId,
      feedbackType: RecommendationFeedbackType.collect,
    );
  }

  /// 标记"阅读"
  Future<bool> markRead(String novelId) async {
    return recordFeedback(
      novelId: novelId,
      feedbackType: RecommendationFeedbackType.read,
    );
  }
}
