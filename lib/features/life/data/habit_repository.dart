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
        limit: limit,
        offset: offset,
      ),
      ApiClient.get(
        'reminder_schedules',
        filters: {'habit_id': 'in.($habitIds)'},
        limit: limit,
        offset: offset,
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
