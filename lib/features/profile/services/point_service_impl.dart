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
  /// 打卡获得积分（change-server：签到闭环整体移交后端）
  ///
  /// 关键路径（单次请求）：
  ///   POST /users/points/checkin —— 查重、算连续天数、发分、回写统计均由后端同事务完成。
  ///
  /// 非关键路径（fire-and-forget）：刷新 AuthService 用户缓存。
  /// 返回格式与旧版保持一致（success/message/points/streak），调用点零改动。
  Future<Map<String, dynamic>> checkin() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': '未登录'};
    }

    try {
      final result = await BackendApi.post('/users/points/checkin');
      if (!result.success) {
        return {'success': false, 'message': result.error ?? '签到失败，请稍后重试'};
      }
      final data = result.data is Map<String, dynamic>
          ? result.data as Map<String, dynamic>
          : <String, dynamic>{};

      // 幂等命中：今日已签到
      if (data['already_checked_in'] == true) {
        return {'success': false, 'message': '今天已签到'};
      }

      final points = (data['amount'] as num?)?.toInt() ?? 0;
      final streak = (data['streak'] as num?)?.toInt() ?? 1;

      EventBus.instance.fire(EventType.pointsUpdated);
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

  /// 检查今天是否已打卡（change-server：以概览端点为唯一权威）
  Future<bool> hasCheckedInToday() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;

    final stats = await _fetchUserStats();
    if (stats == null) return false;

    // 权威判定：后端概览 checked_in_today
    if (stats['checked_in_today'] == true) return true;

    // 兜底：last_checkin_date 与今日北京日期比对（概览缺失时仍可用）
    final lastDateStr = stats['last_checkin_date'];
    if (lastDateStr is String && lastDateStr.isNotEmpty) {
      final today = beijingToday();
      final lastDate = DateTime.parse(lastDateStr);
      return lastDate.year == today.year &&
          lastDate.month == today.month &&
          lastDate.day == today.day;
    }
    return false;
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
