import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';
import '../../../core/widgets/widgets.dart';

/// 农历日期选择器
Future<DateTime?> showLunarDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) async {
  try {
    final solar = Solar.fromDate(initialDate);
    final lunar = solar.getLunar();
    int selectedYear = lunar.getYear();
    int selectedMonth = lunar.getMonth();
    bool selectedIsLeapMonth = lunar.getMonth() < 0;
    int selectedDay = lunar.getDay();

    return await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          /// 获取指定年份和月份的天数
          int getDaysInMonth(int year, int month, {bool isLeap = false}) {
            try {
              final lunarYear = LunarYear.fromYear(year);
              final lunarMonth = lunarYear.getMonth(isLeap ? -month : month);
              return lunarMonth?.getDayCount() ?? 29;
            } catch (_) {
              return 29;
            }
          }

          /// 获取指定年份的闰月月份（0表示无闰月）
          int getLeapMonth(int year) {
            try {
              return LunarYear.fromYear(year).getLeapMonth();
            } catch (_) {
              return 0;
            }
          }

          String getDisplayStr() {
            try {
              final l = Lunar.fromYmd(selectedYear, selectedIsLeapMonth ? -selectedMonth : selectedMonth, selectedDay);
              final s = l.getSolar();
              final monthLabel = selectedIsLeapMonth ? '闰${l.getMonthInChinese()}月' : '${l.getMonthInChinese()}月';
              return '农历 $monthLabel${l.getDayInChinese()} '
                  '(${s.getYear()}-${s.getMonth().toString().padLeft(2, '0')}-${s.getDay().toString().padLeft(2, '0')})';
            } catch (_) {
              return '无效日期';
            }
          }

          final leapMonth = getLeapMonth(selectedYear);
          final daysInMonth = getDaysInMonth(selectedYear, selectedMonth, isLeap: selectedIsLeapMonth);

          return AlertDialog(
            title: const Text('选择农历日期'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getDisplayStr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // 年份选择（1900-2100）
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: selectedYear > 1900
                            ? () => setDialogState(() => selectedYear--)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '$selectedYear年',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: selectedYear < 2100
                            ? () => setDialogState(() => selectedYear++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 月份选择（1-12，如有闰月则额外显示）
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = month == selectedMonth && !selectedIsLeapMonth;
                        return ChoiceChip(
                          label: Text('$month月'),
                          selected: isSelected,
                          onSelected: (_) => setDialogState(() {
                            selectedMonth = month;
                            selectedIsLeapMonth = false;
                            final maxDay = getDaysInMonth(selectedYear, month);
                            if (selectedDay > maxDay) selectedDay = maxDay;
                          }),
                        );
                      }),
                      // 闰月选项
                      if (leapMonth > 0)
                        ChoiceChip(
                          label: Text('闰$leapMonth月'),
                          selected: leapMonth == selectedMonth && selectedIsLeapMonth,
                          onSelected: (_) => setDialogState(() {
                            selectedMonth = leapMonth;
                            selectedIsLeapMonth = true;
                            final maxDay = getDaysInMonth(selectedYear, leapMonth, isLeap: true);
                            if (selectedDay > maxDay) selectedDay = maxDay;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 日期选择（根据该月实际天数动态生成）
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(daysInMonth, (index) {
                      final day = index + 1;
                      final isSelected = day == selectedDay;
                      return ChoiceChip(
                        label: Text('$day'),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() => selectedDay = day),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final l = Lunar.fromYmd(selectedYear, selectedIsLeapMonth ? -selectedMonth : selectedMonth, selectedDay);
                    final s = l.getSolar();
                    final result = DateTime(s.getYear(), s.getMonth(), s.getDay());
                    Navigator.pop(context, result);
                  } catch (_) {
                    showSnackBar(context, '无效的农历日期');
                  }
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  } catch (_) {
    return null;
  }
}
