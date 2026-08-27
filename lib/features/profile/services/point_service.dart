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
    // 红线：北京当日 00:00 对应的 UTC 边界（固定 UTC+8，无夏令时）。
    // 切勿用 DateTime(本地时区).toUtc()，非东八区设备会把本地 0 点误当北京 0 点，导致查询窗口错位。
    final todayStart = DateTime.utc(today.year, today.month, today.day)
        .subtract(const Duration(hours: 8))
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

  /// 获取指定月份（北京时区）已签到的日期键集合（yyyy-MM-dd）。
  ///
  /// 仅供签到日历展示使用，纯只读查询 point_records，不修改任何数据、不改奖励逻辑。
  /// [month] 任意代表目标月份的 DateTime（仅取年月）。
  Future<Set<String>> getCheckinDatesInMonth(DateTime month) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return {};

    final nextMonth = month.month == 12 ? 1 : month.month + 1;
    final nextYear = month.month == 12 ? month.year + 1 : month.year;

    // 以北京自然月为窗口：北京时间 [month-01 00:00, nextMonth-01 00:00)
    // 中国不实行夏令时，固定 UTC+8，故直接对 UTC 零点边界减 8 小时即得对应 UTC 过滤边界。
    final startUtc =
        DateTime.utc(month.year, month.month, 1).subtract(const Duration(hours: 8));
    final endUtc =
        DateTime.utc(nextYear, nextMonth, 1).subtract(const Duration(hours: 8));

    final result = await ApiClient.get(
      'point_records',
      filters: {
        'user_id': 'eq.$userId',
        'type': 'eq.checkin',
        'and':
            '(created_at.gte.${startUtc.toIso8601String()},created_at.lt.${endUtc.toIso8601String()})',
      },
      columns: 'created_at',
      limit: null,
    );

    final dates = <String>{};
    if (result.isSuccess && result.data != null) {
      for (final record in result.data!) {
        final created = record['created_at'] as String?;
        if (created != null) {
          dates.add(beijingDateKey(DateTime.parse(created)));
        }
      }
    }
    return dates;
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
    EventBus.instance.fire(EventType.pointsUpdated);

    // 重算 users 表积分统计字段
    await _recalcAndUpdateUserPoints();
  }

  /// 补签卡道具类型与兑换成本（集中常量，避免散落字面量）
  static const String _makeupCardType = 'makeup_card';
  static const int makeupCardCost = 30;

  /// 读取当前用户持有的补签卡数量（只读查询 user_items）。
  ///
  /// 无记录视为 0；任何异常安全返回 0。
  Future<int> getMakeupCardCount() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return 0;
    try {
      final result = await ApiClient.get(
        'user_items',
        filters: {
          'user_id': 'eq.$userId',
          'item_type': 'eq.$_makeupCardType',
        },
        columns: 'quantity',
        limit: 1,
      );
      if (result.isSuccess &&
          result.data != null &&
          result.data!.isNotEmpty) {
        return (result.data![0]['quantity'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) debugPrint('获取补签卡数量失败: $e');
      return 0;
    }
  }

  /// 增减补签卡库存（先查后 upsert）。
  ///
  /// [delta] +1=兑换获得，-1=补签消耗。返回 true 表示成功。
  /// 首次兑换（无记录）且 delta>0 时插入新行；已存在则按 id PATCH quantity。
  /// 安全校验：计算后 quantity<0 直接返回 false，绝不产生负库存。
  Future<bool> _upsertMakeupCard(int delta) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final result = await ApiClient.get(
        'user_items',
        filters: {
          'user_id': 'eq.$userId',
          'item_type': 'eq.$_makeupCardType',
        },
        columns: 'id,quantity',
        limit: 1,
      );
      if (result.isSuccess &&
          result.data != null &&
          result.data!.isNotEmpty) {
        final row = result.data![0];
        final id = row['id'] as String;
        final q = (row['quantity'] as num?)?.toInt() ?? 0;
        final newQ = q + delta;
        if (newQ < 0) return false;
        final upd = await ApiClient.patchByFilter(
          'user_items',
          filters: {'id': 'eq.$id'},
          body: {'quantity': newQ, 'updated_at': nowIso},
        );
        return upd.isSuccess;
      } else if (delta > 0) {
        final ins = await ApiClient.post('user_items', {
          'id': const Uuid().v4(),
          'user_id': userId,
          'item_type': _makeupCardType,
          'quantity': delta,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        return ins.isSuccess;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('更新补签卡失败: $e');
      return false;
    }
  }

  /// 每月补签次数上限（产品决策：每月最多补签 4 次，按真实操作时间所在北京自然月统计）
  static const int maxMakeupPerMonth = 4;

  /// 补签可回溯的最大自然月数（仅允许补签最近 [maxMakeupMonthsBack] 个自然月内的日期，含当前月）
  static const int maxMakeupMonthsBack = 3;

  /// 判断目标日期是否仍在可补签的时间窗口内（最近 [maxMakeupMonthsBack] 个自然月 + 必须是过去日）。
  ///
  /// 供 UI 前置禁用不可用日期的点击，以及 [makeupCheckin] 服务端兜底校验。
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

  /// 查询最早一条签到记录所在月份的首日（仅取年月），无数据返回 null。
  ///
  /// 用于约束日历向前翻月范围：早于该月的月份均无签到数据，不再允许切换。
  /// 只读 point_records，不修改任何数据。
  Future<DateTime?> getEarliestCheckinMonth() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return null;
    try {
      final result = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.checkin',
        },
        columns: 'created_at',
        order: 'created_at.asc',
        limit: 1,
      );
      if (result.isSuccess &&
          result.data != null &&
          result.data!.isNotEmpty) {
        final created = result.data![0]['created_at'] as String?;
        if (created != null) {
          final dt = DateTime.parse(created);
          return DateTime(dt.year, dt.month, 1);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('查询最早签到月份失败: $e');
      return null;
    }
  }

  /// 统计当前北京自然月内已发生的补签次数（按 makeup_checkins.created_at 真实操作时间）。
  ///
  /// 仅读 makeup_checkins，不修改任何数据。用于「每月最多 [maxMakeupPerMonth] 次」限额校验。
  /// 若用户未登录或查询异常，安全返回 0（不阻断正常补签）。
  Future<int> getMakeupCountThisMonth() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return 0;
    try {
      final now = beijingToday();
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      // 北京自然月窗口：北京时间 [月-01 00:00, 下月-01 00:00)，中国固定 UTC+8，故 UTC 边界减 8h
      final startUtc =
          DateTime.utc(now.year, now.month, 1).subtract(const Duration(hours: 8));
      final endUtc = DateTime.utc(nextYear, nextMonth, 1)
          .subtract(const Duration(hours: 8));

      final result = await ApiClient.get(
        'makeup_checkins',
        filters: {
          'user_id': 'eq.$userId',
          'and':
              '(created_at.gte.${startUtc.toIso8601String()},created_at.lt.${endUtc.toIso8601String()})',
        },
        columns: 'id',
        limit: null,
      );
      if (result.isSuccess && result.data != null) {
        return result.data!.length;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) debugPrint('统计本月补签次数失败: $e');
      return 0;
    }
  }

  /// 积分商城兑换补签卡（消耗 [makeupCardCost] 积分，获得 1 张补签卡）。
  ///
  /// 流程：校验可用积分 ≥ 成本 → 复用既有「消费」闭环（插 spend 流水 + 重算回写 users 展示列）
  ///       → +1 张补签卡；若加卡失败则回退积分消费（插 earn + 重算），保证不丢分。
  Future<Map<String, dynamic>> exchangeMakeupCard() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': '未登录'};
    }
    try {
      final available = await getAvailablePoints();
      if (available < makeupCardCost) {
        return {
          'success': false,
          'message': '积分不足，需 $makeupCardCost 积分',
        };
      }

      // 消费积分（复用 spend 闭环，自动重算回写）
      await updatePointsStats(
        delta: -makeupCardCost,
        type: 'consume',
        remark: '兑换补签卡',
      );

      final ok = await _upsertMakeupCard(1);
      if (!ok) {
        // 加卡失败 → 回退积分（插 earn 把成本加回并重算）
        await updatePointsStats(
          delta: makeupCardCost,
          type: 'earn',
          remark: '兑换补签卡回退',
        );
        return {'success': false, 'message': '兑换失败，已退回积分'};
      }

      final count = await getMakeupCardCount();
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
  ///   2. 目标日未被签到（北京自然日窗口查重，复用 point_records 唯一索引去重）。
  ///   3. 持有补签卡 ≥ 1，扣减 1 张。
  ///   4. 插入一条 checkin 流水：amount=0（不发积分），created_at 设为目标北京日正午
  ///      （BEFORE INSERT 触发器会反推北京 created_date，唯一索引 (user_id,type,created_date)
  ///       自然实现「每北京日一次签到」去重，与正常签到共用同一约束）。
  ///   5. 重算连续签到天数并回写 users 展示列（补签填补断签，可能影响当前连续天数）。
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

      // 1.5 补签时间窗口：仅允许最近 maxMakeupMonthsBack 个自然月内的日期
      if (!isMakeupDateAllowed(targetDay)) {
        return {'success': false, 'message': '只能补签最近3个月内的日期'};
      }

      // 2. 目标日是否已签到（北京自然日窗口）
      // 必须用服务端唯一索引列 created_date（北京日，触发器从 created_at 派生）直接判重，
      // 不能用 created_at + 设备本地时区换算的窗口——旧逻辑 targetDay.toUtc() 在设备时区
      // 非东八区时窗口会整体偏移，漏检已签到日，插入时触发唯一索引 409（用户看到的
      // 「数据冲突」）。放宽 amount 约束后插入真正落地，该潜在漏检才暴露。
      final exist = await ApiClient.get(
        'point_records',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.checkin',
          'created_date': 'eq.${beijingDateKey(targetDay)}',
        },
        columns: 'id',
        limit: 1,
      );
      if (exist.isSuccess && (exist.data ?? []).isNotEmpty) {
        return {'success': false, 'message': '该日期已签到'};
      }

      // 2.5 本月补签次数已达上限（每月最多 maxMakeupPerMonth 次，按真实操作时间统计）
      final usedThisMonth = await getMakeupCountThisMonth();
      if (usedThisMonth >= maxMakeupPerMonth) {
        return {
          'success': false,
          'message': '本月补签次数已用完（每月最多 $maxMakeupPerMonth 次）',
        };
      }

      // 3. 补签卡数量
      final count = await getMakeupCardCount();
      if (count < 1) {
        return {'success': false, 'message': '暂无补签卡'};
      }

      // 4. 消耗 1 张补签卡
      final dec = await _upsertMakeupCard(-1);
      if (!dec) {
        return {'success': false, 'message': '补签卡扣减失败'};
      }

      // 5. 插入 checkin 流水（北京正午 = UTC 04:00，中国无夏令时固定 +8）
      final now = DateTime.now();
      final expiresAt =
          now.add(const Duration(days: 180)).toUtc().toIso8601String();
      final createdAtUtc = DateTime.utc(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        4,
        0,
      );
      final insert = await ApiClient.post('point_records', {
        'id': const Uuid().v4(),
        'user_id': userId,
        'type': 'checkin',
        'amount': 0,
        'remark': '补签',
        'created_at': createdAtUtc.toIso8601String(),
        'expires_at': expiresAt,
        'status': 'active',
      });
      if (!insert.isSuccess) {
        // 插流水失败 → 回滚扣减（补签卡加回）
        await _upsertMakeupCard(1);
        // 唯一索引 (user_id,type,created_date) 冲突：该北京日已有签到/补签，兜底翻译为友好文案
        if (insert.statusCode == 409) {
          return {'success': false, 'message': '该日期已签到或已补签'};
        }
        return {'success': false, 'message': '补签失败：${insert.error}'};
      }

      // 5.5 记录补签操作流水（真实操作时间 created_at=now，用于月度限额统计）
      final makeupInsert = await ApiClient.post('makeup_checkins', {
        'id': const Uuid().v4(),
        'user_id': userId,
        'makeup_date': beijingDateKey(targetDay),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      // 409（同一目标日并发重复补签，理论上已被步骤2拦截）视为已记录，不回滚
      if (!makeupInsert.isSuccess && makeupInsert.statusCode != 409) {
        if (kDebugMode) debugPrint('记录补签流水失败: ${makeupInsert.error}');
        // 不回滚补签卡：checkin 流水已生效、连续天数已补全，仅限额计数漏记（宽松）
      }

      // 6. 重算连续天数（补签填补断签，可能影响当前连续天数展示）
      final streak = await calcConsecutiveStreak(userId, today);
      _fireAndForget(_updateUserStats(consecutiveCheckinDays: streak));
      EventBus.instance.fire(EventType.pointsUpdated);
      return {'success': true, 'message': '补签成功'};
    } catch (e) {
      if (kDebugMode) debugPrint('补签失败: $e');
      return {'success': false, 'message': '补签失败，请稍后重试'};
    }
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