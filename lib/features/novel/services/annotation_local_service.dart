import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/novel_model.dart';

/// 批注本地缓存服务
/// 使用 sqflite 存储未同步的批注，支持离线读写与后续同步
class AnnotationLocalService {
  static final AnnotationLocalService _instance = AnnotationLocalService._internal();
  factory AnnotationLocalService() => _instance;
  AnnotationLocalService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'annotations.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE novel_annotations_local (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT,
            user_id TEXT NOT NULL,
            novel_id TEXT NOT NULL,
            chapter_id TEXT NOT NULL,
            chapter_order INTEGER NOT NULL,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            highlighted_text TEXT NOT NULL,
            note TEXT,
            color TEXT DEFAULT 'yellow',
            is_deleted INTEGER DEFAULT 0,
            deleted_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            sync_status TEXT DEFAULT 'pending' CHECK(sync_status IN ('pending', 'synced', 'failed'))
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_local_novel ON novel_annotations_local(novel_id)',
        );
        await db.execute(
          'CREATE INDEX idx_local_chapter ON novel_annotations_local(chapter_id)',
        );
        await db.execute(
          'CREATE INDEX idx_local_sync ON novel_annotations_local(sync_status)',
        );
      },
    );
  }

  /// 将 NovelAnnotation 转为本地 Map（增加 sync_status）
  Map<String, dynamic> _toLocalMap(NovelAnnotation a, {required String syncStatus}) {
    return {
      'id': a.id.isEmpty ? null : a.id,
      'user_id': a.userId,
      'novel_id': a.novelId,
      'chapter_id': a.chapterId,
      'chapter_order': a.chapterOrder,
      'start_offset': a.startOffset,
      'end_offset': a.endOffset,
      'highlighted_text': a.highlightedText,
      'note': a.note,
      'color': a.color.name,
      'is_deleted': a.isDeleted ? 1 : 0,
      'deleted_at': a.deletedAt?.toUtc().toIso8601String(),
      'created_at': a.createdAt.toUtc().toIso8601String(),
      'updated_at': a.updatedAt?.toUtc().toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  /// 将本地 Map 转为 NovelAnnotation
  NovelAnnotation _fromLocalMap(Map<String, dynamic> m) {
    return NovelAnnotation(
      id: m['id'] as String? ?? '',
      userId: m['user_id'] as String? ?? '',
      novelId: m['novel_id'] as String? ?? '',
      chapterId: m['chapter_id'] as String? ?? '',
      chapterOrder: m['chapter_order'] as int? ?? 0,
      startOffset: m['start_offset'] as int? ?? 0,
      endOffset: m['end_offset'] as int? ?? 0,
      highlightedText: m['highlighted_text'] as String? ?? '',
      note: m['note'] as String?,
      color: AnnotationColor.values.firstWhere(
        (e) => e.name == (m['color'] as String? ?? 'yellow'),
        orElse: () => AnnotationColor.yellow,
      ),
      isDeleted: (m['is_deleted'] as int? ?? 0) == 1,
      deletedAt: m['deleted_at'] != null
          ? DateTime.tryParse(m['deleted_at'] as String)
          : null,
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: m['updated_at'] != null
          ? DateTime.tryParse(m['updated_at'] as String)
          : null,
    );
  }

  /// 插入或替换本地批注
  Future<int> saveAnnotation(NovelAnnotation annotation, {required String syncStatus}) async {
    final db = await database;
    final map = _toLocalMap(annotation, syncStatus: syncStatus);
    if (annotation.id.isNotEmpty) {
      // 尝试更新已有记录
      final count = await db.update(
        'novel_annotations_local',
        map,
        where: 'id = ?',
        whereArgs: [annotation.id],
      );
      if (count > 0) return count;
    }
    return db.insert('novel_annotations_local', map);
  }

  /// 根据 novelId 查询本地批注（排除已删除）
  Future<List<NovelAnnotation>> getAnnotationsByNovel(String novelId) async {
    final db = await database;
    final rows = await db.query(
      'novel_annotations_local',
      where: 'novel_id = ? AND is_deleted = 0',
      whereArgs: [novelId],
      orderBy: 'chapter_order ASC, start_offset ASC',
    );
    return rows.map(_fromLocalMap).toList();
  }

  /// 根据 chapterId 查询本地批注
  Future<List<NovelAnnotation>> getAnnotationsByChapter(String chapterId) async {
    final db = await database;
    final rows = await db.query(
      'novel_annotations_local',
      where: 'chapter_id = ? AND is_deleted = 0',
      whereArgs: [chapterId],
      orderBy: 'start_offset ASC',
    );
    return rows.map(_fromLocalMap).toList();
  }

  /// 获取所有待同步的记录
  Future<List<NovelAnnotation>> getPendingAnnotations() async {
    final db = await database;
    final rows = await db.query(
      'novel_annotations_local',
      where: "sync_status = 'pending'",
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromLocalMap).toList();
  }

  /// 标记为已同步
  Future<void> markAsSynced(String localIdOrRemoteId) async {
    final db = await database;
    // 先尝试按 remote id 更新
    final count = await db.update(
      'novel_annotations_local',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [localIdOrRemoteId],
    );
    if (count == 0) {
      // 再尝试按 local_id 更新
      await db.update(
        'novel_annotations_local',
        {'sync_status': 'synced'},
        where: 'local_id = ?',
        whereArgs: [int.tryParse(localIdOrRemoteId)],
      );
    }
  }

  /// 标记为同步失败
  Future<void> markAsFailed(String localIdOrRemoteId) async {
    final db = await database;
    final count = await db.update(
      'novel_annotations_local',
      {'sync_status': 'failed'},
      where: 'id = ?',
      whereArgs: [localIdOrRemoteId],
    );
    if (count == 0) {
      await db.update(
        'novel_annotations_local',
        {'sync_status': 'failed'},
        where: 'local_id = ?',
        whereArgs: [int.tryParse(localIdOrRemoteId)],
      );
    }
  }

  /// 更新本地记录的 remote id（通过 local_id）
  Future<void> updateRemoteId(int localId, String remoteId) async {
    final db = await database;
    await db.update(
      'novel_annotations_local',
      {'id': remoteId},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// 通过业务字段更新本地记录的 remote id（用于同步后回填）
  Future<void> updateRemoteIdByFields({
    required String userId,
    required String novelId,
    required String chapterId,
    required int startOffset,
    required int endOffset,
    required String remoteId,
  }) async {
    final db = await database;
    await db.update(
      'novel_annotations_local',
      {'id': remoteId, 'sync_status': 'synced'},
      where: 'user_id = ? AND novel_id = ? AND chapter_id = ? AND start_offset = ? AND end_offset = ? AND (id IS NULL OR id = \'\')',
      whereArgs: [userId, novelId, chapterId, startOffset, endOffset],
    );
  }

  /// 软删除本地记录
  Future<void> deleteLocalAnnotation(String id) async {
    final db = await database;
    await db.update(
      'novel_annotations_local',
      {
        'is_deleted': 1,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'pending',
      },
      where: 'id = ? OR local_id = ?',
      whereArgs: [id, int.tryParse(id) ?? 0],
    );
  }

  /// 清空已同步的软删除记录
  Future<void> cleanupSyncedDeleted() async {
    final db = await database;
    await db.delete(
      'novel_annotations_local',
      where: "is_deleted = 1 AND sync_status = 'synced'",
    );
  }

  /// 以云端数据为准，合并到本地
  Future<void> mergeFromCloud(List<NovelAnnotation> cloudList) async {
    final db = await database;
    for (final a in cloudList) {
      if (a.id.isEmpty) continue;
      final existing = await db.query(
        'novel_annotations_local',
        where: 'id = ?',
        whereArgs: [a.id],
        limit: 1,
      );
      final map = _toLocalMap(a, syncStatus: 'synced');
      if (existing.isNotEmpty) {
        await db.update(
          'novel_annotations_local',
          map,
          where: 'id = ?',
          whereArgs: [a.id],
        );
      } else {
        await db.insert('novel_annotations_local', map);
      }
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
