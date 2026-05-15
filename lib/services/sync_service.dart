import 'package:supabase_flutter/supabase_flutter.dart';

/// 数据同步服务
class SyncService {
  static SyncService? _instance;
  late final SupabaseClient _client;
  
  SyncService._() {
    _client = Supabase.instance.client;
  }
  
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }
  
  String? get _userId => _client.auth.currentUser?.id;
  
  /// 同步支出数据
  Future<void> syncExpenses(List<Map<String, dynamic>> localExpenses) async {
    if (_userId == null) return;
    
    for (final expense in localExpenses) {
      expense['user_id'] = _userId;
      await _client.from('expenses').upsert(expense, onConflict: 'id');
    }
  }
  
  /// 同步心情日记
  Future<void> syncMoodDiaries(List<Map<String, dynamic>> localDiaries) async {
    if (_userId == null) return;
    
    for (final diary in localDiaries) {
      diary['user_id'] = _userId;
      await _client.from('mood_diaries').upsert(diary, onConflict: 'id');
    }
  }
  
  /// 同步笔记
  Future<void> syncNotes(List<Map<String, dynamic>> localNotes) async {
    if (_userId == null) return;
    
    for (final note in localNotes) {
      note['user_id'] = _userId;
      await _client.from('notes').upsert(note, onConflict: 'id');
    }
  }
  
  /// 同步体重记录
  Future<void> syncWeightRecords(List<Map<String, dynamic>> localRecords) async {
    if (_userId == null) return;
    
    for (final record in localRecords) {
      record['user_id'] = _userId;
      await _client.from('weight_records').upsert(record, onConflict: 'id');
    }
  }
  
  /// 同步阅读进度
  Future<void> syncReadingProgress(List<Map<String, dynamic>> localProgress) async {
    if (_userId == null) return;
    
    for (final progress in localProgress) {
      progress['user_id'] = _userId;
      await _client.from('reading_progress').upsert(
        progress,
        onConflict: 'user_id,novel_id',
      );
    }
  }
  
  /// 获取服务器数据时间戳
  Future<DateTime?> getLastSyncTime(String table) async {
    if (_userId == null) return null;
    
    final response = await _client
        .from(table)
        .select('updated_at')
        .eq('user_id', _userId!)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    
    if (response != null && response['updated_at'] != null) {
      return DateTime.parse(response['updated_at']);
    }
    return null;
  }
}
