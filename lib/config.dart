/// 应用配置文件
class AppConfig {
  // Supabase 配置
  static const String supabaseUrl = 'https://mhdrbjpqmzswswoazwjg.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1oZHJianBxbXpzd3N3b2F6d2pnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2MjAyMTMsImV4cCI6MjA5NDE5NjIxM30.2qRPz7rB1n_q_8E2Z1F8X3h9Y4Z5a6b7c8d9e0f1a2b';

  // 应用信息
  static const String appName = '纯享';
  static const String appVersion = '1.0.0';

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
