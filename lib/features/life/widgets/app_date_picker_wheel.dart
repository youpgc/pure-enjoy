import 'package:flutter/cupertino.dart';

/// 年月滚轮选择器
class YearMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime> onChanged;

  const YearMonthPicker({
    super.key,
    required this.initialDate,
    this.minDate,
    this.maxDate,
    required this.onChanged,
  });

  @override
  State<YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<YearMonthPicker> {
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

/// 年份滚轮选择器
class AppYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime> onChanged;

  const AppYearPicker({
    super.key,
    required this.initialDate,
    this.minDate,
    this.maxDate,
    required this.onChanged,
  });

  @override
  State<AppYearPicker> createState() => _AppYearPickerState();
}

class _AppYearPickerState extends State<AppYearPicker> {
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
