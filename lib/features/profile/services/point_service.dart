import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import './point_service_utils.dart';
import './point_user_stats.dart';
import './point_recalc.dart';
import './point_cache.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../services/backend_api.dart';
import '../models/point_record_model.dart';
import '../../../core/utils/event_bus.dart';

part 'point_service_impl.dart';
part 'point_service_stats_part.dart';
part 'point_service_makeup_part.dart';

/// 积分服务
///
/// 核心设计（change-server）：
/// - 签到 / 补签 / 补签卡兑换 / 统计查询全部走后端 /users/points/* 端点，
///   users 统计列由后端在积分事务内统一维护，App 侧只读不再回写
/// - updatePointsStats（games 域流水写入）暂保留 Supabase 实现，随 B5 游戏域切换另行迁移
/// - calcConsecutiveStreak（point_service_utils.dart）仅剩 games 域调用，同批废弃
///
/// 膨胀防御（治理 §1.5.5）：实例方法已拆入三个 mixin（point_service_impl.dart 签到域、
/// point_service_stats_part.dart 统计/缓存域、point_service_makeup_part.dart 补签域），
/// 本文件仅保留单例工厂、跨 mixin 共享的私有/静态成员，确保单文件 < 500 行。
class PointService
    with PointServiceCheckinMixin, PointServiceStatsMixin, PointServiceMakeupMixin {
  static PointService? _instance;

  PointService._();

  static PointService get instance {
    _instance ??= PointService._();
    return _instance!;
  }

  /// 补签卡兑换成本（积分）
  static const int makeupCardCost = 30;

  /// 每月补签次数上限（产品决策：每月最多补签 4 次）
  static const int maxMakeupPerMonth = 4;

  /// 补签可回溯的最大自然月数（仅允许补签最近 [maxMakeupMonthsBack] 个自然月内的日期，含当前月）
  static const int maxMakeupMonthsBack = 3;

  /// 判断目标日期是否仍在可补签的时间窗口内（最近 [maxMakeupMonthsBack] 个自然月 + 必须是过去日）。
  ///
  /// 供 UI 前置禁用不可用日期的点击，以及 [PointServiceMakeupMixin.makeupCheckin] 服务端兜底校验。
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
