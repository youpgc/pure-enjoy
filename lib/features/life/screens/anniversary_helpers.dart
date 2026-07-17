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

/// 格式化日期显示（支持农历）
String formatAnniversaryDate(AnniversaryModel item) {
  if (item.isLunar && item.lunarDateStr.isNotEmpty) {
    return '农历${item.lunarDateStr} (${DateTimeUtils.formatDate(item.date)})';
  }
  return DateTimeUtils.formatDate(item.date);
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
