part of './reminder_schedule_picker.dart';

Widget _buildSectionTitle(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

Widget _buildTypeChip(
  BuildContext context, {
  required String type,
  required String label,
  required bool isSelected,
  required VoidCallback onSelected,
}) {
  return ChoiceChip(
    label: Text(label),
    selected: isSelected,
    onSelected: (_) {
      onSelected();
    },
  );
}

// === 每周选择器 ===
Widget _buildWeekDaySelector(
  BuildContext context, {
  required List<int> weekDays,
  required List<String> weekDayLabels,
  required void Function(int day, bool selected) onToggleDay,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle(context, '选择星期几（可多选）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(7, (index) {
          final day = index + 1;
          final isSelected = weekDays.contains(day);
          return FilterChip(
            label: Text(weekDayLabels[index]),
            selected: isSelected,
            onSelected: (selected) => onToggleDay(day, selected),
          );
        }),
      ),
      if (weekDays.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '请至少选择一天',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );
}

// === 每月选择器 ===
Widget _buildMonthDaySelector(
  BuildContext context, {
  required List<int> monthDays,
  required void Function(int day, bool selected) onToggleMonthDay,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle(context, '选择每月几号（可多选）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(31, (index) {
          final day = index + 1;
          final isSelected = monthDays.contains(day);
          return FilterChip(
            label: Text('$day'),
            selected: isSelected,
            onSelected: (selected) => onToggleMonthDay(day, selected),
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          );
        }),
      ),
      if (monthDays.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '请至少选择一天',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );
}

// === 每年选择器 ===
Widget _buildYearSelector(
  BuildContext context, {
  required List<int> months,
  required List<int> monthDays,
  required List<int> years,
  required void Function(int, int) onRemoveYearDatePair,
  required Future<void> Function() onPickYearDate,
  required void Function(int) onRemoveYear,
  required Future<void> Function() onAddYear,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle(context, '选择每年提醒日期（可多选）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...List.generate(months.length, (i) {
            if (monthDays.length <= i) return const SizedBox.shrink();
            final month = months[i];
            final day = monthDays[i];
            return Chip(
              label: Text('$month月$day日'),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => onRemoveYearDatePair(month, day),
            );
          }),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('添加日期'),
            onPressed: onPickYearDate,
          ),
        ],
      ),
      if (months.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '请至少添加一个日期',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      const SizedBox(height: 16),
      _buildSectionTitle(context, '指定年份（可选）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...years.map((year) => Chip(
            label: Text('$year'),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => onRemoveYear(year),
          )),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('添加年份'),
            onPressed: onAddYear,
          ),
        ],
      ),
    ],
  );
}

// === 自定义日期选择器 ===
Widget _buildCustomDateSelector(
  BuildContext context, {
  required List<String> dates,
  required void Function(String) onRemoveCustomDate,
  required Future<void> Function() onAddCustomDate,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle(context, '自定义日期（可多选）'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...dates.map((date) => Chip(
            label: Text(date),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => onRemoveCustomDate(date),
          )),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('添加日期'),
            onPressed: onAddCustomDate,
          ),
        ],
      ),
      if (dates.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '请至少添加一个日期',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );
}
