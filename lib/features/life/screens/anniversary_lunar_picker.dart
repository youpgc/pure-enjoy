import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lunar/lunar.dart';
import '../../../core/widgets/widgets.dart';

/// 农历日期选择器（底部滚轮弹窗，交互与 [AppDatePicker] 统一）。
///
/// - 三列滚轮：农历年 / 农历月 / 农历日。月与日均为中文（正月、初一、闰五月…）；
///   农历年使用干支（丙午年…），全中文，与公历表示严格区分，避免「中阿混排」。
/// - 选中预览与最终回填均为「农历 丙午年正月初一」样式（不再混入公历括号）。
/// - 返回换算后的公历 [DateTime]（仅日期，时分归零），与公历选择器返回结构一致。
Future<DateTime?> showLunarDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) async {
  try {
    return await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LunarPickerBody(initialDate: initialDate),
    );
  } catch (_) {
    return null;
  }
}

class _LunarPickerBody extends StatefulWidget {
  final DateTime initialDate;
  const _LunarPickerBody({required this.initialDate});

  @override
  State<_LunarPickerBody> createState() => _LunarPickerBodyState();
}

class _LunarPickerBodyState extends State<_LunarPickerBody> {
  static const int minYear = 1900;
  static const int maxYear = 2100;

  late int _year;
  late int _monthSigned; // 正数为平月，负数为闰月
  late int _day;
  late final FixedExtentScrollController _yearCtl;
  late final FixedExtentScrollController _monthCtl;
  late final FixedExtentScrollController _dayCtl;

  @override
  void initState() {
    super.initState();
    final lunar = Solar.fromDate(widget.initialDate).getLunar();
    _year = lunar.getYear();
    _monthSigned = lunar.getMonth();
    _day = lunar.getDay();
    _yearCtl = FixedExtentScrollController(initialItem: (_year - minYear).clamp(0, maxYear - minYear));
    _monthCtl = FixedExtentScrollController(initialItem: _clampMonthIdx());
    _dayCtl = FixedExtentScrollController(initialItem: (_day - 1).clamp(0, 29));
  }

  int _clampMonthIdx() {
    final idx = _monthEntries(_year).indexWhere((e) => e.$1 == _monthSigned);
    return idx < 0 ? 0 : idx;
  }

  /// 某年农历月条目（含闰月）：返回 (monthSigned, 中文标签)
  List<(int, String)> _monthEntries(int year) {
    final leap = LunarYear.fromYear(year).getLeapMonth();
    final entries = <(int, String)>[];
    for (var m = 1; m <= 12; m++) {
      final label = '${Lunar.fromYmd(year, m, 1).getMonthInChinese()}月';
      entries.add((m, label));
      if (m == leap) {
        final leapLabel = '闰${Lunar.fromYmd(year, m, 1).getMonthInChinese()}月';
        entries.add((-m, leapLabel));
      }
    }
    return entries;
  }

  int _daysInMonth(int year, int monthSigned) {
    try {
      final lm = LunarYear.fromYear(year).getMonth(monthSigned);
      return lm?.getDayCount() ?? 29;
    } catch (_) {
      return 29;
    }
  }

  String _yearLabel(int y) => '${Lunar.fromYmd(y, 1, 1).getYearInGanZhi()}年';

  String _dayLabel(int d) =>
      Lunar.fromYmd(_year, _monthSigned, d).getDayInChinese();

  String get _preview {
    try {
      final l = Lunar.fromYmd(_year, _monthSigned, _day);
      final m = l.getMonthInChinese();
      final monthStr = _monthSigned < 0 ? '闰$m月' : '$m月';
      return '农历 ${l.getYearInGanZhi()}年$monthStr${l.getDayInChinese()}';
    } catch (_) {
      return '农历';
    }
  }

  void _onYear(int i) {
    _year = minYear + i;
    final months = _monthEntries(_year);
    if (months.indexWhere((e) => e.$1 == _monthSigned) < 0) {
      _monthSigned = months.first.$1;
    }
    _monthCtl.jumpToItem(
      months.indexWhere((e) => e.$1 == _monthSigned).clamp(0, months.length - 1),
    );
    final dc = _daysInMonth(_year, _monthSigned);
    if (_day > dc) _day = dc;
    _dayCtl.jumpToItem((_day - 1).clamp(0, dc - 1));
    setState(() {});
  }

  void _onMonth(int i) {
    final months = _monthEntries(_year);
    _monthSigned = months[i].$1;
    final dc = _daysInMonth(_year, _monthSigned);
    if (_day > dc) _day = dc;
    _dayCtl.jumpToItem((_day - 1).clamp(0, dc - 1));
    setState(() {});
  }

  void _onDay(int i) {
    _day = i + 1;
    setState(() {});
  }

  @override
  void dispose() {
    _yearCtl.dispose();
    _monthCtl.dispose();
    _dayCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final months = _monthEntries(_year);
    final dayCount = _daysInMonth(_year, _monthSigned);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部操作栏（与 AppDatePicker 一致）
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
                    '取消',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  '选择农历日期',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    try {
                      final l = Lunar.fromYmd(_year, _monthSigned, _day);
                      final s = l.getSolar();
                      Navigator.pop(
                        context,
                        DateTime(s.getYear(), s.getMonth(), s.getDay()),
                      );
                    } catch (_) {
                      showSnackBar(context, '无效的农历日期');
                    }
                  },
                  child: Text(
                    '确定',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 选中预览（全中文）
          Text(
            _preview,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 三列滚轮：年 / 月 / 日
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: _yearCtl,
                    onSelectedItemChanged: _onYear,
                    children: [
                      for (var y = minYear; y <= maxYear; y++)
                        Center(child: Text(_yearLabel(y))),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: _monthCtl,
                    onSelectedItemChanged: _onMonth,
                    children: months
                        .map((e) => Center(child: Text(e.$2)))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: _dayCtl,
                    onSelectedItemChanged: _onDay,
                    children: [
                      for (var d = 1; d <= dayCount; d++)
                        Center(child: Text(_dayLabel(d))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
