import 'package:flutter/material.dart';
import '../../../life/models/habit_model.dart';
import './dashboard_helpers.dart';

/// 由心情日记记录构建最近活动条目
///
/// 展示用户选择的「心情」（mood_label / mood），不展示日记正文内容。
Map<String, dynamic> buildDiaryActivity(Map<String, dynamic> item) {
  final mood = item['mood']?.toString();
  final moodLabel = item['mood_label']?.toString();
  final moodText = '${mood != null && mood.isNotEmpty ? '$mood ' : ''}${moodLabel ?? ''}'
      .trim();
  return {
    'icon': Icons.edit_note,
    'title': '心情日记',
    'subtitle': moodText.isNotEmpty ? moodText : '记录了一条心情',
    'time': formatDashboardDisplayDate(item['created_at'], item['date']),
    'created_at_raw': item['created_at'] as String? ?? '',
  };
}

/// 由消费记录构建最近活动条目
Map<String, dynamic> buildExpenseActivity(Map<String, dynamic> item) {
  final amount = (item['amount'] as num?)?.toDouble() ?? 0;
  final category = item['category']?.toString();
  final subtitle =
      '支出 ¥${amount.toStringAsFixed(2)}${category != null && category.isNotEmpty ? ' · $category' : ''}';
  return {
    'icon': Icons.payment,
    'title': '消费记录',
    'subtitle': subtitle,
    'time': formatDashboardDisplayDate(item['created_at'], item['date']),
    'created_at_raw': item['created_at'] as String? ?? '',
  };
}

/// 由体重记录构建最近活动条目
Map<String, dynamic> buildWeightActivity(Map<String, dynamic> item) {
  final weight = (item['weight'] as num?)?.toDouble();
  final subtitle = weight != null ? '体重 ${weight.toStringAsFixed(1)} kg' : '记录了一条体重';
  return {
    'icon': Icons.monitor_weight,
    'title': '体重记录',
    'subtitle': subtitle,
    'time': formatDashboardDisplayDate(item['created_at'], item['date']),
    'created_at_raw': item['created_at'] as String? ?? '',
  };
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
    // 闭环：已达成目标天数的习惯不再出现在首页待打卡
    if (isHabitCompleted(checkins.length, habit.targetDays)) return false;
    return !checkins.any((c) {
      final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
      return dateStr == todayStr;
    });
  }).toList();
}
