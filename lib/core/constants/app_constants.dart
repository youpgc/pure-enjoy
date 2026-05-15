/// 应用常量
class AppConstants {
  // 应用信息
  static const String appName = '纯享';
  static const String appVersion = '1.0.0';
  
  // 存储键
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String lastSyncKey = 'last_sync_time';
  
  // 时间格式
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  
  // 默认值
  static const double defaultFontSize = 18.0;
  static const double defaultLineHeight = 1.8;
  static const int defaultPageSize = 20;
  
  // 支出分类
  static const List<String> expenseCategories = [
    '餐饮',
    '交通',
    '购物',
    '娱乐',
    '医疗',
    '教育',
    '其他',
  ];
  
  // 心情类型
  static const List<String> moodTypes = [
    'happy',
    'calm',
    'sad',
    'angry',
    'anxious',
    'tired',
  ];
  
  // 小说分类
  static const List<String> novelCategories = [
    '玄幻',
    '都市',
    '言情',
    '科幻',
    '历史',
    '武侠',
    '悬疑',
    '其他',
  ];
}
