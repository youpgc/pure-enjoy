/// 应用常量配置
class AppConstants {
  AppConstants._();
  
  // 应用信息
  static const String appName = '纯享';
  static const String appVersion = '1.0.0';
  
  // Supabase配置
  static const String supabaseUrl = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6';
  
  // 本地存储Key
  static const String userBoxKey = 'user_box';
  static const String settingsBoxKey = 'settings_box';
  static const String novelBoxKey = 'novel_box';
  static const String lifeRecordBoxKey = 'life_record_box';
  
  // 心情选项
  static const List<String> moods = ['😄', '😊', '😐', '😔', '😢'];
  static const List<String> moodLabels = ['开心', '愉悦', '平静', '低落', '难过'];
  
  // 消费分类
  static const List<String> expenseCategories = [
    '餐饮',
    '交通',
    '购物',
    '居住',
    '医疗',
    '教育',
    '娱乐',
    '通讯',
    '其他',
  ];
  
  // 体重单位
  static const String weightUnit = 'kg';
}
