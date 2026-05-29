/// 应用配置文件
class AppConfig {
  // Supabase 配置
  static const String supabaseUrl = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6';

  // 应用信息
  static const String appName = '纯享';
  static const String appVersion = '1.8.0';

  // 存储桶名称
  static const String avatarsBucket = 'avatars';
  static const String imagesBucket = 'images';

  // 数据库表名
  static const String expensesTable = 'expenses';
  static const String moodDiariesTable = 'mood_diaries';
  static const String notesTable = 'notes';
  static const String weightRecordsTable = 'weight_records';
  static const String novelsTable = 'novels';
  static const String novelChaptersTable = 'novel_chapters';
  static const String userNovelsTable = 'user_novels';
  static const String readingProgressTable = 'reading_progress';
}
