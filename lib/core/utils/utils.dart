import 'package:intl/intl.dart';

/// 日期时间工具类
class DateTimeUtils {
  /// 格式化日期
  static String formatDate(DateTime date, {String format = 'yyyy-MM-dd'}) {
    return DateFormat(format).format(date);
  }
  
  /// 格式化时间
  static String formatTime(DateTime date, {String format = 'HH:mm'}) {
    return DateFormat(format).format(date);
  }
  
  /// 格式化日期时间
  static String formatDateTime(DateTime date, {String format = 'yyyy-MM-dd HH:mm'}) {
    return DateFormat(format).format(date);
  }
  
  /// 获取友好的时间描述
  static String getFriendlyTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}周前';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()}个月前';
    } else {
      return formatDate(date);
    }
  }
  
  /// 判断是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  /// 判断是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
  
  /// 获取本周的第一天
  static DateTime getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }
  
  /// 获取本月的第一天
  static DateTime getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }
  
  /// 获取本月的最后一天
  static DateTime getMonthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }
}

/// 数字工具类
class NumberUtils {
  /// 格式化金额
  static String formatMoney(double amount, {int decimals = 2}) {
    return '¥${amount.toStringAsFixed(decimals)}';
  }
  
  /// 格式化百分比
  static String formatPercent(double value, {int decimals = 1}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }
  
  /// 格式化数字（添加千分位）
  static String formatNumber(num value, {int decimals = 0}) {
    final formatter = NumberFormat('#,##0.${'#' * decimals}');
    return formatter.format(value);
  }
}

/// 字符串工具类
class StringUtils {
  /// 判断字符串是否为空
  static bool isEmpty(String? str) {
    return str == null || str.trim().isEmpty;
  }
  
  /// 判断字符串是否不为空
  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }
  
  /// 截断字符串
  static String truncate(String str, int maxLength, {String suffix = '...'}) {
    if (str.length <= maxLength) return str;
    return '${str.substring(0, maxLength)}$suffix';
  }
  
  /// 首字母大写
  static String capitalize(String str) {
    if (isEmpty(str)) return str;
    return str[0].toUpperCase() + str.substring(1);
  }
}
