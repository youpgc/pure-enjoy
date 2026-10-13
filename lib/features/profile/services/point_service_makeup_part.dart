part of 'point_service.dart';

/// 积分补签域（补签卡数量 / 兑换 / 补签）：从 point_service_impl.dart 的
/// PointServiceCheckinMixin 拆出（2026-09-22 文件行数红线拆分）。
/// change-server：补签闭环整体移交后端（/users/points/makeup 系列端点），
/// 本 mixin 仅做轻量映射，返回格式与旧版保持一致，调用点零改动。
/// 依赖 CheckinMixin 的 updatePointsStats，故声明 on PointServiceCheckinMixin。
mixin PointServiceMakeupMixin on PointServiceCheckinMixin {
  /// 读取补签域概览（card_count / used_this_month / max_per_month / card_cost / months_back）。
  ///
  /// 后端一端点同时供给卡数量与月度限额口径，异常安全返回 null。
  Future<Map<String, dynamic>?> _fetchMakeupInfo() async {
    try {
      final result = await BackendApi.get('/users/points/makeup/info');
      if (result.success && result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('获取补签概览失败: $e');
      return null;
    }
  }

  /// 读取当前用户持有的补签卡数量。
  ///
  /// 概览缺失时安全返回 0。
  Future<int> getMakeupCardCount() async {
    final info = await _fetchMakeupInfo();
    return (info?['card_count'] as num?)?.toInt() ?? 0;
  }

  /// 统计当前北京自然月内已发生的补签次数（后端口径：按 point_makeup_checkins 操作时间）。
  ///
  /// 概览缺失时安全返回 0（不阻断正常补签）。
  Future<int> getMakeupCountThisMonth() async {
    final info = await _fetchMakeupInfo();
    return (info?['used_this_month'] as num?)?.toInt() ?? 0;
  }

  /// 积分商城兑换补签卡（后端同事务完成扣分 + 加卡，失败整体回滚）。
  Future<Map<String, dynamic>> exchangeMakeupCard() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': '未登录'};
    }
    try {
      final result = await BackendApi.post('/users/points/makeup/exchange');
      if (!result.success) {
        return {'success': false, 'message': result.error ?? '兑换失败，请稍后重试'};
      }
      final data = result.data is Map<String, dynamic>
          ? result.data as Map<String, dynamic>
          : <String, dynamic>{};
      final count = (data['card_count'] as num?)?.toInt() ?? 0;
      EventBus.instance.fire(EventType.pointsUpdated);
      return {
        'success': true,
        'message': '兑换成功，获得 1 张补签卡',
        'count': count,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('兑换补签卡失败: $e');
      return {'success': false, 'message': '兑换失败，请稍后重试'};
    }
  }

  /// 补签：消耗 1 张补签卡，回填一个过去的漏签日。
  ///
  /// 规则（产品决策：补签不发积分，仅补连续天数）：
  ///   1. 目标日必须是过去日（不含今天/未来）。
  ///   2. 仅允许最近 maxMakeupMonthsBack 个自然月内的日期。
  ///   3. 查重 / 月度限额 / 扣卡 / 插 checkin 流水（amount=0）/ 重算连续天数，
  ///      全部由后端 POST /users/points/makeup?date=yyyy-MM-dd 同事务完成。
  Future<Map<String, dynamic>> makeupCheckin(DateTime targetDate) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': '未登录'};
    }
    try {
      final today = beijingToday();
      final targetDay =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      // 只允许补签过去的日期（不含今天）
      if (!targetDay.isBefore(todayDay)) {
        return {'success': false, 'message': '只能补签过去的日期'};
      }

      // 补签时间窗口：仅允许最近 maxMakeupMonthsBack 个自然月内的日期
      if (!PointService.isMakeupDateAllowed(targetDay)) {
        return {'success': false, 'message': '只能补签最近3个月内的日期'};
      }

      final result = await BackendApi.post(
        '/users/points/makeup',
        body: {'date': beijingDateKey(targetDay)},
      );
      if (!result.success) {
        return {'success': false, 'message': result.error ?? '补签失败，请稍后重试'};
      }
      EventBus.instance.fire(EventType.pointsUpdated);
      return {'success': true, 'message': '补签成功'};
    } catch (e) {
      if (kDebugMode) debugPrint('补签失败: $e');
      return {'success': false, 'message': '补签失败，请稍后重试'};
    }
  }
}
