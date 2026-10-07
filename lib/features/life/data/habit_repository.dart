import 'package:uuid/uuid.dart';
import '../../../services/api_client.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';

/// 习惯页数据层：纯网络请求，不含任何 State/UI 逻辑。
/// 从 [HabitsScreen] 抽离，降低单体文件体积（治理 §1.5.5 膨胀防御）。
/// 行为与原内联实现逐字节等价。

/// 一页习惯数据的聚合结果（列表 + 原始 JSON 缓存 + 并行加载的打卡/提醒）。
class HabitPageBundle {
  final List<HabitModel> habits;
  final List<Map<String, dynamic>> rawHabits;
  final Map<String, List<HabitCheckinModel>> checkinHistory;
  final Map<String, ReminderScheduleModel> reminderSchedules;

  HabitPageBundle({
    required this.habits,
    required this.rawHabits,
    required this.checkinHistory,
    required this.reminderSchedules,
  });
}

/// 分页拉取习惯列表 + 并行加载每个习惯的打卡记录与提醒计划。
Future<HabitPageBundle> fetchHabitPage({
  required String userId,
  bool? filterStatus,
  required int offset,
  required int limit,
}) async {
  final filters = <String, String>{
    'user_id': 'eq.$userId',
  };
  if (filterStatus != null) {
    filters['is_active'] = 'eq.$filterStatus';
  }

  final habitsResult = await ApiClient.get(
    'habits',
    filters: filters,
    order: 'is_active.desc',
    limit: limit,
    offset: offset,
  );

  if (!habitsResult.isSuccess) {
    throw Exception('HTTP ${habitsResult.statusCode}');
  }

  final habitsData = habitsResult.data!;
  final items = habitsData.map((e) => HabitModel.fromJson(e)).toList();
  final rawHabits = habitsData.cast<Map<String, dynamic>>();

  final history = <String, List<HabitCheckinModel>>{};
  final schedules = <String, ReminderScheduleModel>{};

  if (items.isNotEmpty) {
    final habitIds = items.map((h) => h.id).join(',');
    final results = await Future.wait([
      ApiClient.get(
        'habit_checkins',
        filters: {'habit_id': 'in.($habitIds)'},
        order: 'checkin_at.desc',
        // ★ 子查询禁止复用列表的 offset：此前 offset 随页码平移会跳过最近的
        //   打卡记录，导致 isCheckedInToday/完成态基于截断数据误判（可重复打卡）。
        //   limit 给显式大值（默认 defaultLimit=10 远不够）；叠加 DB 端
        //   uq_habit_checkins_habit_bjday 每日唯一后，1000 条 ≈ 单习惯 1000 天。
        limit: 1000,
      ),
      ApiClient.get(
        'reminder_schedules',
        filters: {'habit_id': 'in.($habitIds)'},
        // 计划数 ≈ 习惯数，量级小，全量拉取
        limit: null,
      ),
    ]);

    final checkinsResult = results[0];
    final scheduleResult = results[1];

    if (checkinsResult.isSuccess) {
      for (final checkin in checkinsResult.data!) {
        final model = HabitCheckinModel.fromJson(checkin);
        history.putIfAbsent(model.habitId, () => []).add(model);
      }
    }
    // 确保每个 habit 都有条目
    for (final habit in items) {
      history.putIfAbsent(habit.id, () => []);
    }

    if (scheduleResult.isSuccess) {
      for (final s in scheduleResult.data!) {
        final model = ReminderScheduleModel.fromJson(s);
        schedules[model.habitId] = model;
      }
    }
  }

  return HabitPageBundle(
    habits: items,
    rawHabits: rawHabits,
    checkinHistory: history,
    reminderSchedules: schedules,
  );
}

/// 写入一条打卡记录，返回新建的打卡模型（本地时间，用于即时 UI 反馈）。
Future<HabitCheckinModel> createCheckin({
  required String userId,
  required String habitId,
}) async {
  final checkinId = const Uuid().v4();
  final result = await ApiClient.post(
    'habit_checkins',
    {
      'id': checkinId,
      'habit_id': habitId,
      'user_id': userId,
      'checkin_at': DateTime.now().toUtc().toIso8601String(),
    },
  );
  if (!result.isSuccess) {
    throw Exception('添加打卡记录失败: HTTP ${result.statusCode}');
  }
  return HabitCheckinModel(
    id: checkinId,
    habitId: habitId,
    checkinAt: DateTime.now(),
  );
}

/// 删除习惯（连带其关联由调用方负责取消本地提醒）。
Future<void> deleteHabit(String id) async {
  final result = await ApiClient.batchDeleteByFilter(
    'habits',
    filters: {'id': 'eq.$id'},
  );
  if (!result.isSuccess) {
    throw Exception('HTTP ${result.statusCode}');
  }
}

/// 切换习惯启停状态。
Future<void> setHabitActive(String id, bool isActive) async {
  final result = await ApiClient.patchByFilter(
    'habits',
    filters: {'id': 'eq.$id'},
    body: {'is_active': isActive},
  );
  if (!result.isSuccess) {
    throw Exception('HTTP ${result.statusCode}');
  }
}
