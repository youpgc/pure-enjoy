import 'package:flutter/material.dart';
import '../models/reminder_schedule_model.dart';
import 'app_date_picker.dart';

/// 习惯提醒计划选择器
/// 支持按周、按月、按年、自定义日期组合提醒
/// 单选/多选 + 具体时间选择
class ReminderSchedulePicker extends StatefulWidget {
  final ReminderScheduleModel? initialSchedule;
  final ValueChanged<ReminderScheduleModel> onChanged;

  const ReminderSchedulePicker({
    super.key,
    this.initialSchedule,
    required this.onChanged,
  });

  @override
  State<ReminderSchedulePicker> createState() => _ReminderSchedulePickerState();
}

class _ReminderSchedulePickerState extends State<ReminderSchedulePicker> {
  late String _scheduleType;
  late List<int> _weekDays;
  late List<int> _monthDays;
  late List<int> _months;
  late List<int> _years;
  late List<String> _dates;
  late String _time;
  late bool _isEnabled;

  final List<String> _weekDayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final List<String> _monthLabels = [
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月'
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.initialSchedule;
    _scheduleType = s?.scheduleType ?? 'weekly';
    _weekDays = List<int>.from(s?.weekDays ?? []);
    _monthDays = List<int>.from(s?.monthDays ?? []);
    _months = List<int>.from(s?.months ?? []);
    _years = List<int>.from(s?.years ?? []);
    _dates = List<String>.from(s?.dates ?? []);
    _time = s?.time ?? '08:00';
    _isEnabled = s?.isEnabled ?? true;
  }

  void _notifyChange() {
    widget.onChanged(ReminderScheduleModel(
      id: widget.initialSchedule?.id ?? '',
      habitId: widget.initialSchedule?.habitId ?? '',
      userId: widget.initialSchedule?.userId ?? '',
      scheduleType: _scheduleType,
      weekDays: _weekDays,
      monthDays: _monthDays,
      months: _months,
      years: _years,
      dates: _dates,
      time: _time,
      isEnabled: _isEnabled,
    ));
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initialTime = DateTime(
      1970, 1, 1,
      int.tryParse(parts[0]) ?? 8,
      int.tryParse(parts[1]) ?? 0,
    );
    final picked = await AppDatePicker.show(
      context,
      type: DateTimeType.time,
      initialDate: initialTime,
    );
    if (picked != null) {
      setState(() {
        _time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      _notifyChange();
    }
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final dateStr =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (!_dates.contains(dateStr)) {
        setState(() {
          _dates.add(dateStr);
          _dates.sort();
        });
        _notifyChange();
      }
    }
  }

  void _removeCustomDate(String dateStr) {
    setState(() {
      _dates.remove(dateStr);
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 启用开关
        SwitchListTile(
          title: const Text('开启提醒'),
          value: _isEnabled,
          onChanged: (value) {
            setState(() => _isEnabled = value);
            _notifyChange();
          },
          contentPadding: EdgeInsets.zero,
        ),

        if (_isEnabled) ...[
          const Divider(),

          // 提醒类型选择
          _buildSectionTitle('提醒周期'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeChip('weekly', '每周'),
              _buildTypeChip('monthly', '每月'),
              _buildTypeChip('yearly', '每年'),
              _buildTypeChip('custom', '自定义'),
            ],
          ),

          const SizedBox(height: 16),

          // 时间选择
          _buildSectionTitle('提醒时间'),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: Text(_time),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTime,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),

          const SizedBox(height: 16),

          // 根据类型渲染对应的选项组件
          _buildTypeSpecificOptions(),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _scheduleType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _scheduleType = type);
        _notifyChange();
      },
    );
  }

  Widget _buildTypeSpecificOptions() {
    switch (_scheduleType) {
      case 'weekly':
        return _buildWeekDaySelector();
      case 'monthly':
        return _buildMonthDaySelector();
      case 'yearly':
        return _buildYearSelector();
      case 'custom':
        return _buildCustomDateSelector();
      default:
        return const SizedBox.shrink();
    }
  }

  // === 每周选择器 ===
  Widget _buildWeekDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('选择星期几（可多选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = _weekDays.contains(day);
            return FilterChip(
              label: Text(_weekDayLabels[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _weekDays.add(day);
                    _weekDays.sort();
                  } else {
                    _weekDays.remove(day);
                  }
                });
                _notifyChange();
              },
            );
          }),
        ),
        if (_weekDays.isEmpty)
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
  Widget _buildMonthDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('选择每月几号（可多选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(31, (index) {
            final day = index + 1;
            final isSelected = _monthDays.contains(day);
            return FilterChip(
              label: Text('$day'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _monthDays.add(day);
                    _monthDays.sort();
                  } else {
                    _monthDays.remove(day);
                  }
                });
                _notifyChange();
              },
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            );
          }),
        ),
        if (_monthDays.isEmpty)
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
  Widget _buildYearSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('选择月份（可多选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(12, (index) {
            final month = index + 1;
            final isSelected = _months.contains(month);
            return FilterChip(
              label: Text(_monthLabels[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _months.add(month);
                    _months.sort();
                  } else {
                    _months.remove(month);
                  }
                });
                _notifyChange();
              },
            );
          }),
        ),
        if (_months.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '请至少选择一个月份',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),

        const SizedBox(height: 16),

        // 年份选择（可选）
        _buildSectionTitle('指定年份（可选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._years.map((year) => Chip(
              label: Text('$year'),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _years.remove(year));
                _notifyChange();
              },
            )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('添加年份'),
              onPressed: () async {
                final year = await _showYearPickerDialog();
                if (year != null && !_years.contains(year)) {
                  setState(() {
                    _years.add(year);
                    _years.sort();
                  });
                  _notifyChange();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // === 自定义日期选择器 ===
  Widget _buildCustomDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('自定义日期（可多选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._dates.map((date) => Chip(
              label: Text(date),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _removeCustomDate(date),
            )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('添加日期'),
              onPressed: _pickCustomDate,
            ),
          ],
        ),
        if (_dates.isEmpty)
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

  Future<int?> _showYearPickerDialog() async {
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
}
