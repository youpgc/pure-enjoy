import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 日期时间选择类型
enum DateTimeType {
  /// 年月日
  date,

  /// 年月
  yearMonth,

  /// 年
  year,

  /// 时分
  time,
}

/// 区间选择结果
class DateTimeRangeResult {
  final DateTime start;
  final DateTime end;

  const DateTimeRangeResult({
    required this.start,
    required this.end,
  });
}

/// 统一的时间选择器组件
///
/// 参考国内移动端组件风格（Ant Design Mobile、Vant），
/// 基于底部弹窗 + Cupertino 滚轮选择器实现，提供更友好的 API。
///
/// 使用示例：
/// ```dart
/// // 单个日期选择
/// final date = await AppDatePicker.show(
///   context,
///   type: DateTimeType.date,
///   initialDate: DateTime.now(),
///   minDate: DateTime(2020),
///   maxDate: DateTime.now(),
/// );
///
/// // 区间选择
/// final range = await AppDatePicker.showRange(
///   context,
///   type: DateTimeType.yearMonth,
///   startDate: _startMonth,
///   endDate: _endMonth,
/// );
/// ```
class AppDatePicker {
  AppDatePicker._();

  /// 显示单个日期/时间选择器
  ///
  /// [type] 选择类型
  /// [initialDate] 初始选中值，默认为当前时间
  /// [minDate] 最小可选时间
  /// [maxDate] 最大可选时间
  /// [title] 弹窗标题，不传则使用默认标题
  /// [confirmText] 确认按钮文字，默认"确定"
  /// [cancelText] 取消按钮文字，默认"取消"
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTimeType type,
    DateTime? initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    String? title,
    String? confirmText,
    String? cancelText,
  }) async {
    final now = DateTime.now();
    final effectiveInitial = _normalize(initialDate ?? now, type);
    final effectiveMin = minDate != null ? _normalize(minDate, type) : null;
    final effectiveMax = maxDate != null ? _normalize(maxDate, type) : null;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PickerSheet(
        type: type,
        initialDate: effectiveInitial,
        minDate: effectiveMin,
        maxDate: effectiveMax,
        title: title ?? _defaultTitle(type),
        confirmText: confirmText ?? '确定',
        cancelText: cancelText ?? '取消',
      ),
    );
  }

  /// 显示区间选择器（连续选择 start -> end）
  ///
  /// 先弹出 start 选择器，确认后再弹出 end 选择器。
  /// 若中途取消则返回 null。
  static Future<DateTimeRangeResult?> showRange(
    BuildContext context, {
    required DateTimeType type,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? minDate,
    DateTime? maxDate,
    String startLabel = '开始时间',
    String endLabel = '结束时间',
  }) async {
    final now = DateTime.now();

    // 选择 start
    final start = await show(
      context,
      type: type,
      initialDate: startDate ?? now,
      minDate: minDate,
      maxDate: maxDate ?? endDate,
      title: startLabel,
    );
    if (start == null) return null;
    if (!context.mounted) return null;

    // 选择 end，minDate 至少为 start
    final effectiveMin = _compare(type, start, minDate) > 0 ? start : minDate;

    final end = await show(
      context,
      type: type,
      initialDate: endDate ?? start,
      minDate: effectiveMin,
      maxDate: maxDate,
      title: endLabel,
    );
    if (end == null) return null;

    return DateTimeRangeResult(start: start, end: end);
  }

  static DateTime _normalize(DateTime date, DateTimeType type) {
    switch (type) {
      case DateTimeType.date:
        return DateTime(date.year, date.month, date.day);
      case DateTimeType.yearMonth:
        return DateTime(date.year, date.month);
      case DateTimeType.year:
        return DateTime(date.year);
      case DateTimeType.time:
        return DateTime(1970, 1, 1, date.hour, date.minute);
    }
  }

  static String _defaultTitle(DateTimeType type) {
    switch (type) {
      case DateTimeType.date:
        return '选择日期';
      case DateTimeType.yearMonth:
        return '选择年月';
      case DateTimeType.year:
        return '选择年份';
      case DateTimeType.time:
        return '选择时间';
    }
  }

  /// 比较两个日期（按当前类型精度）
  static int _compare(DateTimeType type, DateTime a, DateTime? b) {
    if (b == null) return 1;
    switch (type) {
      case DateTimeType.date:
        return DateTime(a.year, a.month, a.day)
            .compareTo(DateTime(b.year, b.month, b.day));
      case DateTimeType.yearMonth:
        return DateTime(a.year, a.month)
            .compareTo(DateTime(b.year, b.month));
      case DateTimeType.year:
        return a.year.compareTo(b.year);
      case DateTimeType.time:
        final ta = a.hour * 60 + a.minute;
        final tb = b.hour * 60 + b.minute;
        return ta.compareTo(tb);
    }
  }
}

class _PickerSheet extends StatefulWidget {
  final DateTimeType type;
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String title;
  final String confirmText;
  final String cancelText;

  const _PickerSheet({
    required this.type,
    required this.initialDate,
    this.minDate,
    this.maxDate,
    required this.title,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部操作栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    widget.cancelText,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    widget.confirmText,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 选择器区域
          SizedBox(
            height: 240,
            child: _buildPicker(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    switch (widget.type) {
      case DateTimeType.date:
        return _buildDatePicker();
      case DateTimeType.yearMonth:
        return _buildYearMonthPicker();
      case DateTimeType.year:
        return _buildYearPicker();
      case DateTimeType.time:
        return _buildTimePicker();
    }
  }

  Widget _buildDatePicker() {
    return CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: widget.initialDate,
      minimumDate: widget.minDate,
      maximumDate: widget.maxDate,
      onDateTimeChanged: (value) {
        setState(() {
          _selected = DateTime(value.year, value.month, value.day);
        });
      },
    );
  }

  Widget _buildTimePicker() {
    return CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      initialDateTime: widget.initialDate,
      onDateTimeChanged: (value) {
        setState(() {
          _selected = DateTime(1970, 1, 1, value.hour, value.minute);
        });
      },
    );
  }

  Widget _buildYearMonthPicker() {
    return _YearMonthPicker(
      initialDate: widget.initialDate,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      onChanged: (value) {
        setState(() {
          _selected = value;
        });
      },
    );
  }

  Widget _buildYearPicker() {
    return _YearPicker(
      initialDate: widget.initialDate,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      onChanged: (value) {
        setState(() {
          _selected = value;
        });
      },
    );
  }
}

class _YearMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime> onChanged;

  const _YearMonthPicker({
    required this.initialDate,
    this.minDate,
    this.maxDate,
    required this.onChanged,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  late final List<int> _years;
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final minYear = widget.minDate?.year ?? 1900;
    final maxYear = widget.maxDate?.year ?? 2100;
    _years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  List<int> get _availableMonths {
    final minMonth =
        (_selectedYear == widget.minDate?.year) ? widget.minDate!.month : 1;
    final maxMonth =
        (_selectedYear == widget.maxDate?.year) ? widget.maxDate!.month : 12;
    return List.generate(maxMonth - minMonth + 1, (i) => minMonth + i);
  }

  @override
  Widget build(BuildContext context) {
    final months = _availableMonths;
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(DateTime(_selectedYear, _selectedMonth));
      });
    }

    return Row(
      children: [
        Expanded(
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem:
                  _years.indexOf(_selectedYear).clamp(0, _years.length - 1),
            ),
            itemExtent: 40,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedYear = _years[index];
                final newMonths = _availableMonths;
                if (!newMonths.contains(_selectedMonth)) {
                  _selectedMonth = newMonths.first;
                }
                widget.onChanged(DateTime(_selectedYear, _selectedMonth));
              });
            },
            children: _years
                .map((y) => Center(
                    child: Text('$y年',
                        style: const TextStyle(fontSize: 18))))
                .toList(),
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            key: ValueKey(_selectedYear),
            scrollController: FixedExtentScrollController(
              initialItem:
                  months.indexOf(_selectedMonth).clamp(0, months.length - 1),
            ),
            itemExtent: 40,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedMonth = months[index];
                widget.onChanged(DateTime(_selectedYear, _selectedMonth));
              });
            },
            children: months
                .map((m) => Center(
                    child: Text('$m月',
                        style: const TextStyle(fontSize: 18))))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _YearPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime> onChanged;

  const _YearPicker({
    required this.initialDate,
    this.minDate,
    this.maxDate,
    required this.onChanged,
  });

  @override
  State<_YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  late final List<int> _years;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final minYear = widget.minDate?.year ?? 1900;
    final maxYear = widget.maxDate?.year ?? 2100;
    _years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    _selectedYear = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(
        initialItem:
            _years.indexOf(_selectedYear).clamp(0, _years.length - 1),
      ),
      itemExtent: 40,
      onSelectedItemChanged: (index) {
        setState(() {
          _selectedYear = _years[index];
          widget.onChanged(DateTime(_selectedYear));
        });
      },
      children: _years
          .map((y) => Center(
              child: Text('$y年',
                  style: const TextStyle(fontSize: 18))))
          .toList(),
    );
  }
}
