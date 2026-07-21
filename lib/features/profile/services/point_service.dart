import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'point_service_utils.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/cache_helper.dart';
import '../models/point_record_model.dart';

/// 积分服务
///
/// 核心设计：
/// - 积分查询从 users 表统计字段读取（effective_points / available_points / expiring_points）
/// - 积分变动（签到、获得、消费）后，App 端主动重算并更新 users 表统计字段
/// - 不依赖数据库触发器（trg_maintain_user_points 已确认不存在）
/// - 连续签到天数从 users.consecutive_checkin_days / last_checkin_date 读取
class PointService {
  static PointService? _instance;

  PointService._();

  static PointService get instance {
    _instance ??= PointService._();
    return _instance!;
  }

  /// 从 users 表获取用户统计字段
  Future<Map<String, dynamic>?> _fetchUserStats() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;
    final result = await ApiClient.get(
      'users',
      filters: {
        ApiClient.userKey(userId): 'eq.$userId',
        'is_deleted': 'eq.false',
      },
      columns:
          'consecutive_checkin_days,last_checkin_date,effective_points,available_points,expiring_points,points',
      limit: 1,
    );
    if (result.isSuccess && result.data!.isNotEmpty) {
      return result.data![0];
    }
    return null;
  }

  /// 更新 users 表统计字段
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

    final body = <String, dynamic>{};
    if (consecutiveCheckinDays != null) {
      body['consecutive_checkin_days'] = consecutiveCheckinDays;
    }
    if (lastCheckinDate != null) {
      body['last_checkin_date'] =
          lastCheckinDate.toIso8601String().split('T').first;
    }
    if (effectivePoints != null) body['effective_points'] = effectivePoints;
    if (availablePoints != null) body['available_points'] = availablePoints;
    if (expiringPoints != null) body['expiring_points'] = expiringPoints;
    if (points != null) body['points'] = points;

    if (body.isEmpty) return true;

    final result = await ApiClient.patchByFilter(
      'users',
      filters: {ApiClient.userKey(userId): 'eq.$userId'},
      body: body,
    );
    if (!result.isSuccess) {
      if (kDebugMode) {
        debugPrint('更新用户统计字段失败: ${result.error}');
      }
      return false;
    }
    return result.data != null && result.data!.isNotEmpty;
  }

  /// 重算并更新 users 表的积分统计字段
  ///
  /// 基于 point_records 表全量重算（仅在积分变动后调用）：
  /// - effective_points: 所有【有效且未过期】的积分代数和（status='active' 且 expires_at>=now）
  /// - available_points: 与 effective_points 一致（已扣除过期与消费）
  /// - expiring_points: 30天内即将过期的有效积分
  /// - points: 总获得积分（仅正数，不论状态、不论是否过期）
  ///
  /// 注意：积分有效期 180 天。expires_at 已过但仍为 active 的记录，
  /// 在此统一翻转为 status='expired'，使其不再计入可用积分，并与 UI「已过期」标签一致。
  Future<void> _recalcAndUpdateUserPoints() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    try {
      // 查询该用户所有 point_records
      // 注意：必须显式传 limit: null，否则 ApiClient.get 默认 limit=10，
      // 仅聚合前 10 条记录，导致 available_points / points 被少算（BUG 根因）。
      final result = await ApiClient.get(
        'point_records',
        filters: {'user_id': 'eq.$userId'},
        columns: 'amount,status,expires_at',
        limit: null, // 全量查询（积分记录量级有限），不可省略
      );

      if (!result.isSuccess || result.data == null) return;

      final now = DateTime.now().toUtc();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      int effectivePoints = 0;
      int availablePoints = 0;
      int expiringPoints = 0;
      int totalPoints = 0;
      bool hasExpired = false;

      for (final record in result.data!) {
        final amount = (record['amount'] as num?)?.toInt() ?? 0;
        final status = record['status'] as String? ?? 'active';
        final expiresAtStr = record['expires_at'] as String?;
        final expiresAt =
            expiresAtStr != null ? DateTime.parse(expiresAtStr) : null;
        final isExpired = expiresAt != null && expiresAt.isBefore(now);

        // 总获得积分（仅正数，不论状态、不论是否过期）
        if (amount > 0) {
          totalPoints += amount;
        }

        // 仅统计【有效且未过期】的 active 记录
        if (status == 'active' && !isExpired) {
          effectivePoints += amount;
          availablePoints += amount;

          // 30天内即将过期
          if (expiresAt != null && amount > 0) {
            if (expiresAt.isBefore(thirtyDaysLater)) {
              expiringPoints += amount;
            }
          }
        } else if (status == 'active' && isExpired) {
          // 已过期但仍标记为 active，需在库中翻转为 expired
          hasExpired = true;
        }
      }

      // 将已过期但仍为 active 的记录持久化翻转为 expired，
      // 使「可用积分」扣减与 UI「已过期」标签一致（一次性批量更新）
      if (hasExpired) {
        await ApiClient.patchByFilter(
          'point_records',
          filters: {
            'user_id': 'eq.$userId',
            'status': 'eq.active',
            'expires_at': 'lt.${now.toIso8601String()}',
          },
          body: {'status': 'expired'},
        );
      }

      await _updateUserStats(
        effectivePoints: effectivePoints,
        availablePoints: availablePoints,
        expiringPoints: expiringPoints,
        points: totalPoints,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('重算用户积分失败: $e');
      }
    }
  }

  /// 打卡获得积分
  ///
  /// 核心逻辑：
  /// 1. 检查今天是否已打卡
  /// 2. 计算连续签到天数
  /// 3. 计算积分 = min(连续天数, 7)
  /// 4. 插入 point_records 流水
  /// 5. 更新 users 表签到统计字段
  /// 6. 重算 users 表积分统计字段
  Future<Map<String, dynamic>> checkin() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        return {'success': false, 'message': '未登录'};
      }

      final today = beijingToday();
      final tomorrow = beijingTomorrow();

      // 1. 查询用户今天是否已打卡
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

      // 2. 基于 point_records 签到流水推算连续签到天数
      //    （不再依赖 users 统计字段，规避写入失败与历史坏数据的影响）
      final streak = await calcConsecutiveStreak(userId, today);

      // 3. 计算积分 = min(连续天数, 7)
      final points = streak > 7 ? 7 : streak;

      // 4. 插入 point_records 记录
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
        if (kDebugMode) {
          debugPrint('插入积分记录失败: ${insertResult.error}');
        }
        return {'success': false, 'message': '签到失败: ${insertResult.error}'};
      }

      // 5. 更新 users 表打卡统计字段
      await _updateUserStats(
        consecutiveCheckinDays: streak,
        lastCheckinDate: today,
      );

      // 6. 重算 users 表积分统计字段（不依赖触发器）
      await _recalcAndUpdateUserPoints();

      // 7. 更新 AuthService 中的用户缓存
      await AuthService.instance.reloadCurrentUser();

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
    await CacheHelper.instance.saveMap(CacheHelper.keyPointStats, {
      'availablePoints': availablePoints,
      'consecutiveCheckinDays': consecutiveCheckinDays,
      'lastCheckinDate': lastCheckinDate,
    });
  }

  /// 读取本地缓存的积分统计
  ///
  /// 若未缓存则返回全 0 / null。已签到状态由 lastCheckinDate 与今日北京日期键实时比较得出，
  /// 保证隔天后缓存自动失效、首屏渲染正确。字段含义同 cachePointsStats。
  Future<Map<String, dynamic>> getCachedPointsStats() async {
    final m = await CacheHelper.instance.loadMap(CacheHelper.keyPointStats);
    if (m == null) {
      return {
        'availablePoints': 0,
        'consecutiveCheckinDays': 0,
        'lastCheckinDate': null,
      };
    }
    final String? date = m['lastCheckinDate'] as String?;
    final todayKey = beijingDateKey(DateTime.now());
    return {
      'availablePoints': (m['availablePoints'] as num?)?.toInt() ?? 0,
      'consecutiveCheckinDays':
          (m['consecutiveCheckinDays'] as num?)?.toInt() ?? 0,
      'lastCheckinDate': date,
      'hasCheckedInToday': date == todayKey,
    };
  }
}