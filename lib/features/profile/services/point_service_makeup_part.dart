part of 'point_service.dart';

/// 积分补签域（补签卡数量 / 兑换 / 补签）：从 point_service_impl.dart 的
/// PointServiceCheckinMixin 拆出（2026-09-22 文件行数红线拆分，逻辑零变更）。
/// 依赖 CheckinMixin 的 updatePointsStats，故声明 on PointServiceCheckinMixin。
mixin PointServiceMakeupMixin on PointServiceCheckinMixin {
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
          'item_type': 'eq.${PointService._makeupCardType}',
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
          'item_type': 'eq.${PointService._makeupCardType}',
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
          'item_type': PointService._makeupCardType,
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

  /// 统计当前北京自然月内已发生的补签次数（按 makeup_checkins.created_at 真实操作时间）。
  ///
  /// 仅读 makeup_checkins，不修改任何数据。用于「每月最多 [maxMakeupPerMonth] 次」限额校验。
  /// 若用户未登录或查询异常，安全返回 0（不阻断正常补签）。
  Future<int> getMakeupCountThisMonth() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return 0;
    try {
      final now = beijingToday();
      // 北京自然月窗口 [month-01 00:00, nextMonth-01 00:00) 的 UTC 边界
      final (startUtc, endUtc) =
          DateTimeUtils.beijingMonthUtcRange(now.year, now.month);

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
      final stats = await _fetchUserStats();
      final available = (stats?['available_points'] as num?)?.toInt() ?? 0;
      if (available < PointService.makeupCardCost) {
        return {
          'success': false,
          'message': '积分不足，需 ${PointService.makeupCardCost} 积分',
        };
      }

      // 消费积分（复用 spend 闭环，自动重算回写）
      await updatePointsStats(
        delta: -PointService.makeupCardCost,
        type: 'consume',
        remark: '兑换补签卡',
      );

      final ok = await _upsertMakeupCard(1);
      if (!ok) {
        // 加卡失败 → 回退积分（插 earn 把成本加回并重算）
        await updatePointsStats(
          delta: PointService.makeupCardCost,
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
      if (!PointService.isMakeupDateAllowed(targetDay)) {
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
      if (usedThisMonth >= PointService.maxMakeupPerMonth) {
        return {
          'success': false,
          'message':
              '本月补签次数已用完（每月最多 ${PointService.maxMakeupPerMonth} 次）',
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
}
