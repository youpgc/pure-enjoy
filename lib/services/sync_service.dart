/// 数据同步服务（本地实现）
class SyncService {
  static SyncService? _instance;
  
  SyncService._();
  
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }
  
  /// 同步支出数据（本地空实现）
  Future<void> syncExpenses(List<Map<String, dynamic>> localExpenses) async {
    // 本地存储，无需同步
  }
  
  /// 同步心情日记（本地空实现）
  Future<void> syncMoodDiaries(List<Map<String, dynamic>> localDiaries) async {
    // 本地存储，无需同步
  }
  
  /// 同步笔记（本地空实现）
  Future<void> syncNotes(List<Map<String, dynamic>> localNotes) async {
    // 本地存储，无需同步
  }
  
  /// 同步体重记录（本地空实现）
  Future<void> syncWeightRecords(List<Map<String, dynamic>> localRecords) async {
    // 本地存储，无需同步
  }
  
  /// 同步阅读进度（本地空实现）
  Future<void> syncReadingProgress(List<Map<String, dynamic>> localProgress) async {
    // 本地存储，无需同步
  }
  
  /// 获取服务器数据时间戳（本地空实现）
  Future<DateTime?> getLastSyncTime(String table) async {
    return null;
  }
}
