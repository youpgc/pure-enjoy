import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import './point_service_utils.dart';
import './point_user_stats.dart';
import './point_recalc.dart';
import './point_cache.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../models/point_record_model.dart';

/// 积分服务
///
/// 核心设计：
/// - 积分查询从 users 表统计字段读取（effective_points / available_points / expiring_points）
/// - 积分变动（签到、获得、消费）后，App 端主动重算并更新 users 表统计字段
/// - 不依赖数据库触发器（trg_maintain_user_points 已确认不存在）
/// - 连续签到天数由 calcConsecutiveStreak 从 point_records 反推（users.consecutive_checkin_days 仅作展示缓存，不参与计算，详见 §4.5）
class PointService {
  static PointService? _instance;

  PointService._();

  static PointService get instance {
    _instance ??= PointService._();
    return _instance!;
  }

  /// 从 users 表获取用户统计字段（实现见 point_user_stats.dart）
  Future<Map<String, dynamic>?> _fetchUserStats() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;
    return fetchUserStats(userId);
  }

  /// 更新 users 表统计字段（实现见 point_user_stats.dart）
  /// 返回 true 表示更新成功，false 表示更新失败
  Future<bool> _updateUserStats({
    int? consecutiveCheckinDays,
    DateTime? lastCheckinDate,
    int? effectivePoints,
    int? availablePoints,
    int? expiringPoints,
    int? points,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;
    return updateUserStats(
      userId,
      consecutiveCheckinDays: consecutiveCheckinDays,
      lastCheckinDate: lastCheckinDate,
      effectivePoints: effectivePoints,
      availablePoints: availablePoints,
      expiringPoints: expiringPoints,
      points: points,
    );
  }

  /// 重算并更新 users 表的积分统计字段（实现见 point_recalc.dart）
  Future<void> _recalcAndUpdateUserPoints() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    return recalcAndUpdateUserPoints(userId);
  }

  /// 打卡获得积分
  ///
  /// 关键路径（必须等待，直接决定接口返回结果，目标 <600ms）：
  ///   1. 校验登录
  ///   2. 查今天是否已打卡（北京自然日窗口，防重复）
  ///   3. 反推连续签到天数（决定本次积分与展示，逻辑只信 point_records）
  ///   4. 插入 point_records 流水（核心落库）
  ///
  /// 非关键路径（fire-and-forget，不阻塞接口响应，详见 [_fireAndForget]）：
  ///   - 回写 users 展示字段（连续天数 / 最近签到日期）
  ///   - 全量重算 users 积分展示列
  ///   - 刷新 AuthService 用户缓存
  ///   这些维护逻辑与本次签到结果无依赖，推迟到响应之后由事件循环异步执行，
  ///   使接口耗时仅含「查重 + 算连续 + 插流水」三步。
  Future<Map<String, dynamic>> checkin() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': '未登录'};
    }

    try {
      final today = beijingToday();
      final tomorrow = beijingTomorrow();

      // 1. 查今天是否已打卡（北京自然日窗口）
      final todayResult = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.checkin',
          'and':
              '(created_at.gte.${today.toUtc().toIso8601String()},created_at.lt.${tomorrow.toUtc().toIso8601String()})',
        },
        columns: 'id',
      );

      if (todayResult.isSuccess) {
        final records = todayResult.data!;
        if (records.isNotEmpty) {
          return {'success': false, 'message': '今天已签到'};
        }
      }

      // 2. 反推连续签到天数（逻辑计算只信 point_records，规避 users 展示列写入失败）
      final streak = await calcConsecutiveStreak(userId, today);

      // 3. 计算积分 = min(连续天数, 7)
      final points = streak > 7 ? 7 : streak;

      // 4. 插入 point_records 流水（核心落库）
      final now = DateTime.now();
      final nowIso = now.toUtc().toIso8601String();
      final expiresAt =
          now.add(const Duration(days: 180)).toUtc().toIso8601String();
      final insertResult = await ApiClient.post(
        'point_records',
        {
          'id': const Uuid().v4(),
          'user_id': userId,
          'type': 'checkin',
          'amount': points,
          'remark': '连续签到$streak天',
          'created_at': nowIso,
          'expires_at': expiresAt,
          'status': 'active',
        },
      );

      if (!insertResult.isSuccess) {
        // 唯一索引冲突：理论上已被步骤1拦截，此处兜底视为「今日已签到」，
        // 避免用户看到硬失败（北京时区唯一索引修复后，冲突即代表真实重复）。
        if (insertResult.statusCode == 409) {
          return {'success': false, 'message': '今天已签到'};
        }
        if (kDebugMode) {
          debugPrint('插入积分记录失败: ${insertResult.error}');
        }
        return {'success': false, 'message': '签到失败: ${insertResult.error}'};
      }

      // 5-7（非关键）：回写展示字段 + 重算积分 + 刷新缓存，全部异步，不阻塞返回
      _fireAndForget(_updateUserStats(
        consecutiveCheckinDays: streak,
        lastCheckinDate: today,
      ));
      _fireAndForget(_recalcAndUpdateUserPoints());
      _fireAndForget(AuthService.instance.reloadCurrentUser());

      return {
        'success': true,
        'message': '签到成功，获得$points积分',
        'points': points,
        'streak': streak,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('签到失败: $e');
      }
      return {'success': false, 'message': '签到失败，请稍后重试'};
    }
  }

  /// 异步执行非关键维护逻辑（如签到后的统计回写 / 重算 / 缓存刷新），
  /// 吞掉异常，确保不影响主流程与接口响应耗时。
  void _fireAndForget(Future future) {
    future.catchError((e, st) {
      if (kDebugMode) {
        debugPrint('后台积分维护任务失败（已忽略）: $e');
      }
    });
  }

  /// 分页获取积分记录
  ///
  /// [statusFilter] 状态过滤，null 表示不过滤（显示所有记录）
  Future<List<PointRecord>> getRecords({
    int page = 1,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) return [];

      final offset = (page - 1) * pageSize;
      final filters = <String, String>{'user_id': 'eq.$userId'};
      if (statusFilter != null) {
        filters['status'] = 'eq.$statusFilter';
      }

      final result = await ApiClient.get(
        'point_records',
        filters: filters,
        order: 'created_at.desc',
        limit: pageSize,
        offset: offset,
      );

      if (result.isSuccess) {
        final records = result.data!;
        return records.map((json) => PointRecord.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取积分记录失败');
      }
      return [];
    }
  }

  /// 获取用户可用积分（有效且未过期的积分）
  Future<int> getAvailablePoints() async {
    final stats = await _fetchUserStats();
    return (stats?['available_points'] as num?)?.toInt() ?? 0;
  }

  /// 获取连续签到天数
  Future<int> getConsecutiveCheckinDays() async {
    final stats = await _fetchUserStats();
    return (stats?['consecutive_checkin_days'] as num?)?.toInt() ?? 0;
  }

  /// 从 AuthService 获取用户总积分（兼容旧代码）
  int getTotalPoints() {
    return AuthService.instance.currentPoints ?? 0;
  }

  /// 查询30天内即将过期的积分总数
  Future<int> getExpiringSoonPoints() async {
    final stats = await _fetchUserStats();
    return (stats?['expiring_points'] as num?)?.toInt() ?? 0;
  }

  /// 检查今天是否已打卡
  /// 双重验证：先检查 users.last_checkin_date，再查询 point_records 确认
  Future<bool> hasCheckedInToday() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

    final today = beijingToday();

    // 方法1：检查 users 表的 last_checkin_date
    final stats = await _fetchUserStats();
    if (stats != null && stats['last_checkin_date'] != null) {
      final lastDateStr = stats['last_checkin_date'] as String;
      final lastDate = DateTime.parse(lastDateStr);
      if (lastDate.year == today.year &&
          lastDate.month == today.month &&
          lastDate.day == today.day) {
        return true;
      }
    }

    // 方法2：直接查询 point_records 表作为验证
    final todayStart = DateTime(today.year, today.month, today.day)
        .toUtc()
        .toIso8601String();
    final result = await ApiClient.get(
      'point_records',
      filters: {
        'user_id': 'eq.$userId',
        'type': 'eq.checkin',
        'created_at': 'gte.$todayStart',
      },
      limit: 1,
    );
    return result.isSuccess && (result.data ?? []).isNotEmpty;
  }

  /// 积分变动时插入 point_records 流水记录（供其他模块调用）
  ///
  /// 插入后自动重算 users 表积分统计字段。
  ///
  /// [delta] 变动值（正数增加，负数减少）
  /// [type] 变动类型：'earn' | 'consume'
  /// [remark] 备注说明
  Future<void> updatePointsStats({
    required int delta,
    required String type,
    String? remark,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    String recordType;
    String defaultRemark;
    switch (type) {
      case 'earn':
        recordType = 'earn';
        defaultRemark = '获得积分';
        break;
      case 'consume':
        recordType = 'spend';
        defaultRemark = '消费积分';
        break;
      default:
        return;
    }

    final now = DateTime.now().toUtc();
    final expiresAt = delta > 0
        ? now.add(const Duration(days: 180)).toIso8601String()
        : null;

    await ApiClient.post('point_records', {
      'id': const Uuid().v4(),
      'user_id': userId,
      'type': recordType,
      'amount': delta,
      'remark': remark ?? defaultRemark,
      'status': 'active',
      'created_at': now.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt,
    });

    // 重算 users 表积分统计字段
    await _recalcAndUpdateUserPoints();
  }

  /// 手动触发积分重算（用于数据修复或初始化场景）
  Future<void> recalcPoints() async {
    await _recalcAndUpdateUserPoints();
  }

  /// 缓存积分统计到本地，供积分页进入时立即展示（避免闪现 0）
  ///
  /// [lastCheckinDate] 最近一次签到的北京日期键（yyyy-MM-dd），为 null 表示未签到。
  /// 由 App 端在签到成功或拉取后端数据后维护，仅用于首屏秒渲染，不替代后端权威数据。
  /// 隔天后缓存日期键与今日不匹配，hasCheckedInToday 自动归 false，无需手动清理。
  Future<void> cachePointsStats({
    required int availablePoints,
    required int consecutiveCheckinDays,
    String? lastCheckinDate,
  }) async {
    await savePointStatsCache(
      availablePoints: availablePoints,
      consecutiveCheckinDays: consecutiveCheckinDays,
      lastCheckinDate: lastCheckinDate,
    );
  }

  /// 读取本地缓存的积分统计
  ///
  /// 若未缓存则返回全 0 / null。已签到状态由 lastCheckinDate 与今日北京日期键实时比较得出，
  /// 保证隔天后缓存自动失效、首屏渲染正确。字段含义同 cachePointsStats。
  Future<Map<String, dynamic>> getCachedPointsStats() async {
    return loadPointStatsCache();
  }
}