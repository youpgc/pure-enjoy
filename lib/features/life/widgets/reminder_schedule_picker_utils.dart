import 'package:flutter/material.dart';

/// 年份选择对话框
///
/// 返回用户选中的年份；若取消则返回 null。
Future<int?> showYearPickerDialog(BuildContext context) {
  final currentYear = DateTime.now().year;
  int selectedYear = currentYear;

  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('选择年份'),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialogState(() => selectedYear--),
                  ),
                  Text(
                    '$selectedYear',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setDialogState(() => selectedYear++),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selectedYear),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
