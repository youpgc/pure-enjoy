import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../utils/date_time_utils.dart';
import '../models/habit_model.dart';

/// 习惯打卡记录查看 Dialog（纯展示）。
/// 从 [HabitsScreen._showHistoryDialog] 抽离（治理 §1.5.5 膨胀防御）。
Future<void> showHabitHistoryDialog(
  BuildContext context,
  String habitName,
  List<HabitCheckinModel> checkins,
) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$habitName 打卡记录'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: checkins.isEmpty
            ? const Center(child: Text('暂无打卡记录'))
            : ListView.builder(
                itemCount: checkins.length,
                itemBuilder: (context, index) {
                  final checkin = checkins[index];
                  return ListTile(
                    leading: const Icon(Icons.check_circle, color: AppTheme.success),
                    title: Text(DateTimeUtils.formatStandard(checkin.checkinAt)),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
