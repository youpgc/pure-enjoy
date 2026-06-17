/// 应用配置文件
import 'services/supabase_service.dart';

class AppConfig {
  // Supabase 配置（统一引用 SupabaseConfig）
  static String get supabaseUrl => SupabaseConfig.url;
  static String get supabaseAnonKey => SupabaseConfig.anonKey;

  // 应用信息
  static const String appName = '纯享';
  static const String appVersion = '1.9.185';

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
  static const String readingProgressTable = 'user_novels';
  static const String feedbackTable = 'user_feedback';
}
