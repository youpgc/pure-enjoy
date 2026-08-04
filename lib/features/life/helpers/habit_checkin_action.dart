import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/event_bus.dart';
import '../models/habit_model.dart';
import '../data/habit_repository.dart';

/// 执行打卡（网络写库 + 本地即时反馈 + 事件广播 + 成功提示）。
/// [addLocalCheckin] 由调用方注入本地插入（保持 State 一致性）；
/// [refresh] 拉取后端维护的最新 streak（不触发整列表 loading）。
/// 从 [HabitsScreen._checkIn] 抽离（治理 §1.5.5 膨胀防御）。
/// 行为与原内联实现逐字节等价（异常提示、单习惯 loading 由调用方管理）。
Future<void> performHabitCheckIn({
  required BuildContext context,
  required HabitModel habit,
  required String userId,
  required void Function(String habitId, HabitCheckinModel checkin) addLocalCheckin,
  required Future<void> Function() refresh,
}) async {
  try {
    final newCheckin = await createCheckin(userId: userId, habitId: habit.id);
    addLocalCheckin(habit.id, newCheckin);
    await refresh();
    EventBus.instance.fire(EventType.habitUpdated);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${habit.name} 打卡成功！'),
        backgroundColor: AppTheme.success,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      showSnackBar(context, '打卡失败，请稍后重试', isError: true);
    }
  }
}
