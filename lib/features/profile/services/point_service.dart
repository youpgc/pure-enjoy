import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class PointService {
  static final PointService _instance = PointService._internal();
  factory PointService() => _instance;
  PointService._internal();

  Future<int> getUserPoints() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return 0;

    try {
      final result = await ApiClient.get(
        'users',
        filters: {'id': 'eq.$userId'},
        select: 'points',
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          return (data.first['points'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> addPoints(int points, {String? reason}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

    try {
      final currentPoints = await getUserPoints();
      final result = await ApiClient.patch(
        'users',
        filters: {'id': 'eq.$userId'},
        body: {'points': currentPoints + points},
      );

      if (result.isSuccess) {
        // 记录积分变动
        await ApiClient.post(
          'point_records',
          body: {
            'user_id': userId,
            'points': points,
            'reason': reason ?? '积分变动',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deductPoints(int points, {String? reason}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

    try {
      final currentPoints = await getUserPoints();
      if (currentPoints < points) return false;

      final result = await ApiClient.patch(
        'users',
        filters: {'id': 'eq.$userId'},
        body: {'points': currentPoints - points},
      );

      if (result.isSuccess) {
        // 记录积分变动
        await ApiClient.post(
          'point_records',
          body: {
            'user_id': userId,
            'points': -points,
            'reason': reason ?? '积分消费',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
