import 'package:lunar/lunar.dart';
import '../../../utils/date_time_utils.dart';
import '../models/anniversary_model.dart';

/// 格式化农历日期显示
String getLunarDateStr(DateTime date) {
  try {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    final monthStr = lunar.getMonthInChinese();
    final dayStr = lunar.getDayInChinese();
    return '$monthStr月$dayStr';
  } catch (_) {
    return DateTimeUtils.formatDate(date);
  }
}

/// 农历年（干支）显示，如「丙午年」
String getLunarYearStr(DateTime date) {
  try {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    return '${lunar.getYearInGanZhi()}年';
  } catch (_) {
    return '';
  }
}

/// 公历日期中文展示：阿拉伯数字 + 年月日单位（如「2026年08月30日」）
String formatDateCN(DateTime date) {
  final y = date.year;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y年$m月$d日';
}

/// 格式化日期显示（支持农历）
///
/// 文案对齐规则（见需求）：
/// - 农历：全中文（干支年 + 中文月日），不再混入公历括号，避免中阿混排；
/// - 公历：阿拉伯数字 + 年月日单位。
String formatAnniversaryDate(AnniversaryModel item) {
  if (item.isLunar) {
    return '农历${item.lunarYearStr}${item.lunarDateStr}';
  }
  return formatDateCN(item.date);
}

/// 获取距离天数的描述文本
String getAnniversaryDaysText(AnniversaryModel item) {
  final days = item.daysUntilNext;
  if (days == 0) {
    return '就是今天！';
  } else if (days == 1) {
    return '明天';
  } else if (days < 0) {
    return '已过${-days}天';
  } else {
    return '还有$days天';
  }
}
