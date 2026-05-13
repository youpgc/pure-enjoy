import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/life/data/expense_model.dart';
import '../features/life/data/mood_diary_model.dart';
import '../features/life/data/weight_record_model.dart';
import '../features/life/data/note_model.dart';
import '../features/novel/data/novel_model.dart';
import 'storage_service.dart';

/// 云端同步服务
///
/// 同步策略：
/// 1. 上传：将本地未同步的数据（synced=false）推送到云端
/// 2. 下载：从云端拉取数据合并到本地
/// 3. 冲突处理：以最后修改时间为准
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _client = Supabase.instance.client;

  /// 当前用户ID
  String? get _userId => _client.auth.currentUser?.id;

  /// 是否已登录
  bool get isLoggedIn => _userId != null;

  /// 全量同步：先上传再下载
  Future<void> syncAll() async {
    if (!isLoggedIn) return;

    await Future.wait([
      _syncExpenses(),
      _syncMoodDiaries(),
      _syncWeightRecords(),
      _syncNotes(),
      _syncNovels(),
    ]);
  }

  // ==================== 消费记录同步 ====================

  Future<void> _syncExpenses() async {
    final box = StorageService().expenseBox;

    // 1. 上传本地未同步的记录
    final unsynced = box.values.where((e) => !e.synced).toList();
    for (final expense in unsynced) {
      try {
        await _client.from('expenses').upsert({
          'id': expense.id,
          'user_id': _userId,
          'amount': expense.amount,
          'category': expense.category,
          'note': expense.note,
          'date': expense.date.toIso8601String(),
          'created_at': expense.createdAt.toIso8601String(),
          'synced': true,
        });
        // 标记为已同步
        final updated = ExpenseModel(
          id: expense.id,
          amount: expense.amount,
          category: expense.category,
          note: expense.note,
          date: expense.date,
          createdAt: expense.createdAt,
          synced: true,
        );
        await box.put(updated.id, updated);
      } catch (_) {
        // 单条失败不影响其他
      }
    }

    // 2. 从云端下载
    await _downloadExpenses(box);
  }

  Future<void> _downloadExpenses(dynamic box) async {
    final response = await _client
        .from('expenses')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    for (final row in response) {
      final existing = box.get(row['id'] as String);
      if (existing == null) {
        // 云端有本地没有，下载
        final expense = ExpenseModel.fromJson(row);
        await box.put(expense.id, expense);
      }
    }
  }

  // ==================== 心情日记同步 ====================

  Future<void> _syncMoodDiaries() async {
    final box = StorageService().moodDiaryBox;

    final unsynced = box.values.where((e) => !e.synced).toList();
    for (final diary in unsynced) {
      try {
        await _client.from('mood_diaries').upsert({
          'id': diary.id,
          'user_id': _userId,
          'mood': diary.mood,
          'mood_label': diary.moodLabel,
          'content': diary.content,
          'date': diary.date.toIso8601String(),
          'created_at': diary.createdAt.toIso8601String(),
          'synced': true,
        });
        final updated = MoodDiaryModel(
          id: diary.id,
          mood: diary.mood,
          moodLabel: diary.moodLabel,
          content: diary.content,
          date: diary.date,
          createdAt: diary.createdAt,
          synced: true,
        );
        await box.put(updated.id, updated);
      } catch (_) {}
    }

    final response = await _client
        .from('mood_diaries')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    for (final row in response) {
      if (box.get(row['id'] as String) == null) {
        final diary = MoodDiaryModel.fromJson(row);
        await box.put(diary.id, diary);
      }
    }
  }

  // ==================== 体重记录同步 ====================

  Future<void> _syncWeightRecords() async {
    final box = StorageService().weightBox;

    final unsynced = box.values.where((e) => !e.synced).toList();
    for (final record in unsynced) {
      try {
        await _client.from('weight_records').upsert({
          'id': record.id,
          'user_id': _userId,
          'weight': record.weight,
          'note': record.note,
          'date': record.date.toIso8601String(),
          'created_at': record.createdAt.toIso8601String(),
          'synced': true,
        });
        final updated = WeightRecordModel(
          id: record.id,
          weight: record.weight,
          note: record.note,
          date: record.date,
          createdAt: record.createdAt,
          synced: true,
        );
        await box.put(updated.id, updated);
      } catch (_) {}
    }

    final response = await _client
        .from('weight_records')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    for (final row in response) {
      if (box.get(row['id'] as String) == null) {
        final record = WeightRecordModel.fromJson(row);
        await box.put(record.id, record);
      }
    }
  }

  // ==================== 笔记同步 ====================

  Future<void> _syncNotes() async {
    final box = StorageService().noteBox;

    final unsynced = box.values.where((e) => !e.synced).toList();
    for (final note in unsynced) {
      try {
        await _client.from('notes').upsert({
          'id': note.id,
          'user_id': _userId,
          'title': note.title,
          'content': note.content,
          'category': note.category,
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt.toIso8601String(),
          'pinned': note.pinned,
          'synced': true,
        });
        final updated = NoteModel(
          id: note.id,
          title: note.title,
          content: note.content,
          category: note.category,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          pinned: note.pinned,
          synced: true,
        );
        await box.put(updated.id, updated);
      } catch (_) {}
    }

    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', _userId!)
        .order('updated_at', ascending: false);

    for (final row in response) {
      final existing = box.get(row['id'] as String);
      if (existing == null) {
        final note = NoteModel.fromJson(row);
        await box.put(note.id, note);
      } else {
        // 云端更新时间更新，则覆盖本地
        final cloudUpdated = DateTime.parse(row['updated_at']);
        if (cloudUpdated.isAfter(existing.updatedAt)) {
          final note = NoteModel.fromJson(row);
          await box.put(note.id, note);
        }
      }
    }
  }

  // ==================== 小说书架同步 ====================

  Future<void> _syncNovels() async {
    final box = StorageService().novelBox;

    final unsynced = box.values.where((e) => !e.synced).toList();
    for (final novel in unsynced) {
      try {
        await _client.from('novels').upsert({
          'id': novel.id,
          'user_id': _userId,
          'title': novel.title,
          'author': novel.author,
          'cover_url': novel.coverUrl,
          'description': novel.description,
          'source': novel.source,
          'source_id': novel.sourceId,
          'added_at': novel.addedAt.toIso8601String(),
          'last_read_at': novel.lastReadAt?.toIso8601String(),
          'last_chapter_index': novel.lastChapterIndex,
          'progress': novel.progress,
          'synced': true,
        });
        final updated = NovelModel(
          id: novel.id,
          title: novel.title,
          author: novel.author,
          coverUrl: novel.coverUrl,
          description: novel.description,
          source: novel.source,
          sourceId: novel.sourceId,
          addedAt: novel.addedAt,
          lastReadAt: novel.lastReadAt,
          lastChapterIndex: novel.lastChapterIndex,
          progress: novel.progress,
          synced: true,
        );
        await box.put(updated.id, updated);
      } catch (_) {}
    }

    final response = await _client
        .from('novels')
        .select()
        .eq('user_id', _userId!)
        .order('added_at', ascending: false);

    for (final row in response) {
      final existing = box.get(row['id'] as String);
      if (existing == null) {
        final novel = _novelFromJson(row);
        await box.put(novel.id, novel);
      } else {
        final cloudRead = row['last_read_at'] != null
            ? DateTime.parse(row['last_read_at'])
            : null;
        if (cloudRead != null &&
            existing.lastReadAt != null &&
            cloudRead.isAfter(existing.lastReadAt!)) {
          final novel = _novelFromJson(row);
          await box.put(novel.id, novel);
        }
      }
    }
  }

  NovelModel _novelFromJson(Map<String, dynamic> json) {
    return NovelModel(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      coverUrl: json['cover_url'],
      description: json['description'],
      source: json['source'],
      sourceId: json['source_id'],
      addedAt: DateTime.parse(json['added_at']),
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'])
          : null,
      lastChapterIndex: json['last_chapter_index'] ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      synced: true,
    );
  }

  // ==================== 单条操作便捷方法 ====================

  /// 上传单条消费记录
  Future<void> uploadExpense(ExpenseModel expense) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('expenses').upsert({
        'id': expense.id,
        'user_id': _userId,
        'amount': expense.amount,
        'category': expense.category,
        'note': expense.note,
        'date': expense.date.toIso8601String(),
        'created_at': expense.createdAt.toIso8601String(),
        'synced': true,
      });
    } catch (_) {}
  }

  /// 上传单条心情日记
  Future<void> uploadMoodDiary(MoodDiaryModel diary) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('mood_diaries').upsert({
        'id': diary.id,
        'user_id': _userId,
        'mood': diary.mood,
        'mood_label': diary.moodLabel,
        'content': diary.content,
        'date': diary.date.toIso8601String(),
        'created_at': diary.createdAt.toIso8601String(),
        'synced': true,
      });
    } catch (_) {}
  }

  /// 上传单条体重记录
  Future<void> uploadWeightRecord(WeightRecordModel record) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('weight_records').upsert({
        'id': record.id,
        'user_id': _userId,
        'weight': record.weight,
        'note': record.note,
        'date': record.date.toIso8601String(),
        'created_at': record.createdAt.toIso8601String(),
        'synced': true,
      });
    } catch (_) {}
  }

  /// 上传单条笔记
  Future<void> uploadNote(NoteModel note) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('notes').upsert({
        'id': note.id,
        'user_id': _userId,
        'title': note.title,
        'content': note.content,
        'category': note.category,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'pinned': note.pinned,
        'synced': true,
      });
    } catch (_) {}
  }

  /// 上传单条小说
  Future<void> uploadNovel(NovelModel novel) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('novels').upsert({
        'id': novel.id,
        'user_id': _userId,
        'title': novel.title,
        'author': novel.author,
        'cover_url': novel.coverUrl,
        'description': novel.description,
        'source': novel.source,
        'source_id': novel.sourceId,
        'added_at': novel.addedAt.toIso8601String(),
        'last_read_at': novel.lastReadAt?.toIso8601String(),
        'last_chapter_index': novel.lastChapterIndex,
        'progress': novel.progress,
        'synced': true,
      });
    } catch (_) {}
  }

  /// 删除云端单条记录
  Future<void> deleteRemote(String table, String id) async {
    if (!isLoggedIn) return;
    try {
      await _client.from(table).delete().eq('id', id).eq('user_id', _userId);
    } catch (_) {}
  }
}
