part of 'point_service.dart';

/// 跨 mixin 共享的私有辅助。
///
/// 库级顶层函数：mixin 实例方法无法直接访问「将要混入的类」的实例/静态成员，
/// 故将共享逻辑提升为库级函数，使 PointServiceCheckinMixin / PointServiceStatsMixin
/// 均能非限定调用，且规避两 mixin 互调的方法解析问题。

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

/// 异步执行非关键维护逻辑（如签到后的统计回写 / 重算 / 缓存刷新），
/// 吞掉异常，确保不影响主流程与接口响应耗时。
///
/// 移除 kDebugMode 门控，确保 release 下也能落日志，便于排查积分维护失败。
void _fireAndForget(Future future) {
  future.catchError((e, st) {
    debugPrint('后台积分维护任务失败（已忽略）: $e');
  });
}

/// 签到 / 补签 / 补签卡相关实现
mixin PointServiceCheckinMixin {
  /// 打卡获得积分
  ///
  /// 关键路径（必须等待，直接决定接口返回结果，目标 <600ms）：
  ///   1. 校验登录
  ///   2. 查今天是否已打卡（北京自然日窗口，防重复）
  ///   3. 反推连续签到天数（决定本次积分与展示，逻辑只信 point_records）
  ///   4. 插入 point_records 流水（核心落库）
  ///
  /// 非关键路径（fire-and-forget，不阻塞接口响应）：
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

      EventBus.instance.fire(EventType.pointsUpdated);
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
    // 红线：北京当日 00:00 对应的 UTC 边界一律走 DateTimeUtils.beijingDayStartUtc
    // （固定 UTC+8，无夏令时）。切勿用 DateTime(本地时区).toUtc()，
    // 非东八区设备会把本地 0 点误当北京 0 点，导致查询窗口错位。
    final todayStart = DateTimeUtils.beijingDayStartUtc(
            today.year, today.month, today.day)
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
  /// [type] 变动类型：'earn' | 'consume' | 'game_earn' | 'game_spend'
  ///   - 'earn' / 'game_earn'：正积分，落库带 expires_at（+180 天）
  ///   - 'consume' / 'game_spend'：消费，delta 应为负数，落库无 expires_at
  /// [remark] 备注说明
  ///
  /// **返回是否真正写入成功**。调用方（道具购买 / 游戏发奖）必须据此判断：
  /// 流水写入失败时不得继续发放业务权益，否则出现「扣分流失败仍白送道具」
  /// 或「发分流失败却回报已发放并烧掉占坑」两类事故。
  /// 注意：本方法**不抛异常**，失败只返回 false，切勿用 try/catch 判定成败。
  Future<bool> updatePointsStats({
    required int delta,
    required String type,
    String? remark,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

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
      case 'game_earn':
        recordType = 'game_earn';
        defaultRemark = '游戏奖励';
        break;
      case 'game_spend':
        recordType = 'game_spend';
        defaultRemark = '游戏消费';
        break;
      default:
        return false;
    }

    final now = DateTime.now().toUtc();
    final expiresAt = delta > 0
        ? now.add(const Duration(days: 180)).toIso8601String()
        : null;

    final insert = await ApiClient.post('point_records', {
      'id': const Uuid().v4(),
      'user_id': userId,
      'type': recordType,
      'amount': delta,
      'remark': remark ?? defaultRemark,
      'status': 'active',
      'created_at': now.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt,
    });

    if (!insert.isSuccess) {
      // 流水未落库：直接返回 false，调用方据此中止业务发放
      if (kDebugMode) {
        debugPrint('写入积分流水失败（$recordType $delta）：${insert.error}');
      }
      return false;
    }

    EventBus.instance.fire(EventType.pointsUpdated);

    // 重算 users 表积分统计字段
    await _recalcAndUpdateUserPoints();
    return true;
  }
}
