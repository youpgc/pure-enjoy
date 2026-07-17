import 'package:flutter/material.dart';
import '../../../services/dict_service.dart';
import '../../life/models/habit_model.dart';
import '../../novel/models/novel_model.dart';
import 'dashboard_helpers.dart';

/// 由心情日记记录构建最近活动条目
Map<String, dynamic> buildDiaryActivity(Map<String, dynamic> item) {
  return {
    'icon': Icons.edit_note,
    'title': '心情日记',
    'subtitle': item['content'] ?? item['mood']?.toString() ?? '记录了一条心情',
    'time': formatDashboardDisplayDate(item['created_at'], item['entry_date']),
    'created_at_raw': item['created_at'] as String? ?? '',
  };
}

/// 由支出记录构建最近活动条目
Map<String, dynamic> buildExpenseActivity(Map<String, dynamic> item) {
  final categoryLabel = DictService.instance.getLabelOrDefault(
    'expense_category',
    item['category'] as String? ?? '',
    defaultValue: item['category'] as String? ?? '其他',
  );
  return {
    'icon': Icons.attach_money,
    'title': '支出记录',
    'subtitle': '$categoryLabel ¥${item['amount'] ?? 0}',
    'time': formatDashboardDisplayDate(item['created_at'], item['date']),
    'created_at_raw': item['created_at'] as String? ?? '',
  };
}

/// 由体重记录构建最近活动条目
Map<String, dynamic> buildWeightActivity(Map<String, dynamic> item) {
  return {
    'icon': Icons.monitor_weight,
    'title': '体重记录',
    'subtitle': '${item['weight'] ?? 0} kg',
    'time': formatDashboardDisplayDate(item['created_at'], item['date']),
    'created_at_raw': item['created_at'] as String? ?? '',
  };
}

/// 解析最近阅读小说列表并按阅读时间排序
List<Map<String, dynamic>> buildRecentNovelList(
  List<dynamic> novelsData,
  Map<String, Map<String, dynamic>> progressMap,
  List<String> novelIds,
) {
  final novels = <Map<String, dynamic>>[];
  for (final novelData in novelsData) {
    final novelId = novelData['id']?.toString() ?? '';
    final progressItem = progressMap[novelId];
    if (progressItem != null) {
      novels.add({
        'novel': NovelModel.fromJson(novelData),
        'lastChapter': progressItem['last_chapter'] as int? ?? 1,
        'progress': progressItem['progress'] as num? ?? 0.0,
      });
    }
  }

  novels.sort((a, b) {
    final idA = (a['novel'] as NovelModel).id;
    final idB = (b['novel'] as NovelModel).id;
    final idxA = novelIds.indexOf(idA);
    final idxB = novelIds.indexOf(idB);
    return idxA.compareTo(idxB);
  });

  return novels;
}

/// 解析习惯列表（用于首页快捷打卡）
List<HabitModel> parseHabits(List<dynamic> data) {
  return data.map((e) => HabitModel.fromJson(e as Map<String, dynamic>)).toList();
}

/// 由打卡记录构建习惯→打卡历史映射，并确保每个习惯都有条目
Map<String, List<HabitCheckinModel>> buildCheckinHistory(
  List<dynamic> checkinsData,
  List<HabitModel> habits,
) {
  final history = <String, List<HabitCheckinModel>>{};
  for (final checkin in checkinsData) {
    final model = HabitCheckinModel.fromJson(checkin as Map<String, dynamic>);
    final habitId = model.habitId;
    history.putIfAbsent(habitId, () => []).add(model);
  }
  for (final habit in habits) {
    history.putIfAbsent(habit.id, () => []);
  }
  return history;
}

/// 计算今日待打卡的习惯列表
List<HabitModel> computePendingHabits(
  List<HabitModel> habits,
  Map<String, List<HabitCheckinModel>> checkinHistory,
) {
  final today = DateTime.now();
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  return habits.where((habit) {
    final checkins = checkinHistory[habit.id] ?? [];
    return !checkins.any((c) {
      final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
      return dateStr == todayStr;
    });
  }).toList();
}
