import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';
import '../features/auth/data/user_model.dart';
import '../features/life/data/expense_model.dart';
import '../features/life/data/mood_diary_model.dart';
import '../features/life/data/weight_record_model.dart';
import '../features/life/data/note_model.dart';
import '../features/novel/data/novel_model.dart';

/// 本地存储服务
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  
  late Box<UserModel> _userBox;
  late Box<ExpenseModel> _expenseBox;
  late Box<MoodDiaryModel> _moodDiaryBox;
  late Box<WeightRecordModel> _weightBox;
  late Box<NoteModel> _noteBox;
  late Box<NovelModel> _novelBox;
  late Box _settingsBox;
  
  /// 初始化所有存储
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // 注册适配器
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(ExpenseModelAdapter());
    Hive.registerAdapter(MoodDiaryModelAdapter());
    Hive.registerAdapter(WeightRecordModelAdapter());
    Hive.registerAdapter(NoteModelAdapter());
    Hive.registerAdapter(NovelModelAdapter());
    
    // 打开所有Box
    _userBox = await Hive.openBox<UserModel>(AppConstants.userBoxKey);
    _expenseBox = await Hive.openBox<ExpenseModel>('expenses');
    _moodDiaryBox = await Hive.openBox<MoodDiaryModel>('mood_diaries');
    _weightBox = await Hive.openBox<WeightRecordModel>('weight_records');
    _noteBox = await Hive.openBox<NoteModel>('notes');
    _novelBox = await Hive.openBox<NovelModel>(AppConstants.novelBoxKey);
    _settingsBox = await Hive.openBox(AppConstants.settingsBoxKey);
  }
  
  // 用户相关
  Box<UserModel> get userBox => _userBox;
  
  // 消费记录相关
  Box<ExpenseModel> get expenseBox => _expenseBox;
  
  // 心情日记相关
  Box<MoodDiaryModel> get moodDiaryBox => _moodDiaryBox;
  
  // 体重记录相关
  Box<WeightRecordModel> get weightBox => _weightBox;
  
  // 笔记相关
  Box<NoteModel> get noteBox => _noteBox;
  
  // 小说相关
  Box<NovelModel> get novelBox => _novelBox;
  
  // 设置相关
  Box get settingsBox => _settingsBox;
  
  /// 获取设置
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }
  
  /// 保存设置
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }
  
  /// 清空所有数据（退出登录时）
  Future<void> clearAll() async {
    await _expenseBox.clear();
    await _moodDiaryBox.clear();
    await _weightBox.clear();
    await _noteBox.clear();
    await _novelBox.clear();
  }
}
