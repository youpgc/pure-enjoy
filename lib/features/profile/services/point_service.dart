import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import './point_service_utils.dart';
import './point_user_stats.dart';
import './point_recalc.dart';
import './point_cache.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../models/point_record_model.dart';
import '../../../core/utils/event_bus.dart';

part 'point_service_impl.dart';
part 'point_service_stats_part.dart';

/// 积分服务
///
/// 核心设计：
/// - 积分查询从 users 表统计字段读取（effective_points / available_points / expiring_points）
/// - 积分变动（签到、获得、消费）后，App 端主动重算并更新 users 表统计字段
/// - 不依赖数据库触发器（trg_maintain_user_points 已确认不存在）
/// - 连续签到天数由 calcConsecutiveStreak 从 point_records 反推（users.consecutive_checkin_days 仅作展示缓存，不参与计算，详见 §4.5）
///
/// 膨胀防御（治理 §1.5.5）：实例方法已拆入 point_service_impl.dart 的两个 mixin，
/// 本文件仅保留单例工厂、跨 mixin 共享的私有/静态成员，确保单文件 < 500 行。
class PointService
    with PointServiceCheckinMixin, PointServiceStatsMixin {
  static PointService? _instance;

  PointService._();

  static PointService get instance {
    _instance ??= PointService._();
    return _instance!;
  }

  /// 补签卡道具类型（集中常量，避免散落字面量）
  static const String _makeupCardType = 'makeup_card';

  /// 补签卡兑换成本（积分）
  static const int makeupCardCost = 30;

  /// 每月补签次数上限（产品决策：每月最多补签 4 次）
  static const int maxMakeupPerMonth = 4;

  /// 补签可回溯的最大自然月数（仅允许补签最近 [maxMakeupMonthsBack] 个自然月内的日期，含当前月）
  static const int maxMakeupMonthsBack = 3;

  /// 判断目标日期是否仍在可补签的时间窗口内（最近 [maxMakeupMonthsBack] 个自然月 + 必须是过去日）。
  ///
  /// 供 UI 前置禁用不可用日期的点击，以及 [PointServiceCheckinMixin.makeupCheckin] 服务端兜底校验。
  static bool isMakeupDateAllowed(DateTime date) {
    final today = beijingToday();
    final todayDay = DateTime(today.year, today.month, today.day);
    if (!date.isBefore(todayDay)) return false; // 必须是过去的日期
    // 窗口起点：当前月往前推 (maxMakeupMonthsBack - 1) 个月的首日
    var y = today.year;
    var m = today.month - (maxMakeupMonthsBack - 1);
    while (m <= 0) {
      m += 12;
      y -= 1;
    }
    final windowStart = DateTime(y, m, 1);
    return !date.isBefore(windowStart);
  }
}
