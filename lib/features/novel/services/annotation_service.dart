import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/api_client.dart';
import '../../../services/session_manager.dart';
import '../models/novel_model.dart';
import 'annotation_local_service.dart';

/// 批注/笔记服务（支持离线同步）
/// 管理小说阅读过程中的高亮批注，网络异常时自动降级到本地 SQLite
class AnnotationService {
  static final AnnotationService _instance = AnnotationService._internal();
  factory AnnotationService() => _instance;
  AnnotationService._internal();

  final AnnotationLocalService _local = AnnotationLocalService();

  String? get _userId => SessionManager.instance.currentUserId;

  /// 检查网络是否可用
  Future<bool> get _isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// 获取指定小说的所有批注（本地+云端合并，云端优先）
  Future<List<NovelAnnotation>> getAnnotations(String novelId) async {
    final userId = _userId;
    if (userId == null) return [];

    // 1. 先读取本地缓存
    final localList = await _local.getAnnotationsByNovel(novelId);

    // 2. 在线时拉取云端并合并
    if (await _isOnline) {
      try {
        final result = await ApiClient.get(
          'novel_annotations',
          filters: {
            'user_id': 'eq.$userId',
            'novel_id': 'eq.$novelId',
          },
          order: 'chapter_order.asc,start_offset.asc',
          limit: 200,
        );

        if (result.isSuccess && result.data != null) {
          final cloudList = result.data!
              .map((json) => NovelAnnotation.fromJson(json))
              .where((a) => !a.isDeleted)
              .toList();

          // 以云端数据为准合并到本地
          await _local.mergeFromCloud(cloudList);

          // 返回云端数据（更准确）
          return cloudList;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-云端拉取失败，使用本地缓存: $e');
      }
    }

    // 离线或失败时返回本地数据
    return localList;
  }

  /// 获取指定章节的所有批注
  Future<List<NovelAnnotation>> getChapterAnnotations(
    String novelId,
    String chapterId,
  ) async {
    final userId = _userId;
    if (userId == null) return [];

    final localList = await _local.getAnnotationsByChapter(chapterId);

    if (await _isOnline) {
      try {
        final result = await ApiClient.get(
          'novel_annotations',
          filters: {
            'user_id': 'eq.$userId',
            'novel_id': 'eq.$novelId',
            'chapter_id': 'eq.$chapterId',
          },
          order: 'start_offset.asc',
          limit: 100,
        );

        if (result.isSuccess && result.data != null) {
          final cloudList = result.data!
              .map((json) => NovelAnnotation.fromJson(json))
              .where((a) => !a.isDeleted)
              .toList();
          await _local.mergeFromCloud(cloudList);
          return cloudList;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-云端拉取失败: $e');
      }
    }

    return localList;
  }

  /// 添加批注（本地优先，异步同步到云端）
  Future<NovelAnnotation?> addAnnotation({
    required String novelId,
    required String chapterId,
    required int chapterOrder,
    required int startOffset,
    required int endOffset,
    required String highlightedText,
    String? note,
    AnnotationColor color = AnnotationColor.yellow,
  }) async {
    final userId = _userId;
    if (userId == null) return null;

    final annotation = NovelAnnotation(
      id: '',
      userId: userId,
      novelId: novelId,
      chapterId: chapterId,
      chapterOrder: chapterOrder,
      startOffset: startOffset,
      endOffset: endOffset,
      highlightedText: highlightedText,
      note: note,
      color: color,
      createdAt: DateTime.now(),
    );

    // 1. 先写入本地（pending 状态）
    final localId = await _local.saveAnnotation(annotation, syncStatus: 'pending');

    // 2. 在线时立即同步到云端
    if (await _isOnline) {
      try {
        final result = await ApiClient.post('novel_annotations', annotation.toJson());
        if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
          final saved = NovelAnnotation.fromJson(result.data!.first);
          // 更新本地记录的 remote id 并标记为已同步
          await _local.updateRemoteId(localId, saved.id);
          await _local.markAsSynced(saved.id);
          return saved;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-同步批注失败，标记为 failed: $e');
        await _local.markAsFailed(localId.toString());
      }
    }

    // 离线时返回本地对象（id 为空，后续同步后会更新）
    return annotation;
  }

  /// 更新批注（笔记内容或颜色）
  Future<bool> updateAnnotation({
    required String annotationId,
    String? note,
    AnnotationColor? color,
  }) async {
    final body = <String, dynamic>{};
    if (note != null) body['note'] = note;
    if (color != null) body['color'] = color.name;
    if (body.isEmpty) return true;

    body['updated_at'] = DateTime.now().toUtc().toIso8601String();

    // 1. 更新本地记录为 pending
    final localAnnotation = await _getLocalById(annotationId);
    if (localAnnotation != null) {
      final updated = localAnnotation.copyWith(
        note: note ?? localAnnotation.note,
        color: color ?? localAnnotation.color,
        updatedAt: DateTime.now(),
      );
      await _local.saveAnnotation(updated, syncStatus: 'pending');
    }

    // 2. 在线时同步到云端
    if (await _isOnline) {
      try {
        final result = await ApiClient.patch('novel_annotations', body, id: annotationId);
        if (result.isSuccess) {
          await _local.markAsSynced(annotationId);
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-更新批注失败: $e');
        await _local.markAsFailed(annotationId);
      }
    }

    // 离线时返回 true（本地已保存，后续会同步）
    return true;
  }

  /// 软删除批注
  Future<bool> deleteAnnotation(String annotationId) async {
    // 1. 本地软删除并标记 pending
    await _local.deleteLocalAnnotation(annotationId);

    // 2. 在线时同步到云端
    if (await _isOnline) {
      try {
        final result = await ApiClient.patch(
          'novel_annotations',
          {
            'is_deleted': true,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          },
          id: annotationId,
        );
        if (result.isSuccess) {
          await _local.markAsSynced(annotationId);
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-删除批注失败: $e');
        await _local.markAsFailed(annotationId);
      }
    }

    return true;
  }

  /// 硬删除批注（彻底删除）
  Future<bool> hardDeleteAnnotation(String annotationId) async {
    if (await _isOnline) {
      try {
        final result = await ApiClient.delete('novel_annotations', id: annotationId);
        if (result.isSuccess) {
          await _local.deleteLocalAnnotation(annotationId);
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-硬删除失败: $e');
      }
    }
    return false;
  }

  /// 获取指定位置的批注（精确匹配）
  Future<NovelAnnotation?> getAnnotationAt(
    String novelId,
    String chapterId,
    int startOffset,
    int endOffset,
  ) async {
    final userId = _userId;
    if (userId == null) return null;

    if (await _isOnline) {
      try {
        final result = await ApiClient.get(
          'novel_annotations',
          filters: {
            'user_id': 'eq.$userId',
            'novel_id': 'eq.$novelId',
            'chapter_id': 'eq.$chapterId',
            'start_offset': 'eq.$startOffset',
            'end_offset': 'eq.$endOffset',
          },
          limit: 1,
        );

        if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
          return NovelAnnotation.fromJson(result.data!.first);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AnnotationService-查询失败: $e');
      }
    }

    // 本地兜底查询
    final localList = await _local.getAnnotationsByChapter(chapterId);
    try {
      return localList.firstWhere(
        (a) => a.startOffset == startOffset && a.endOffset == endOffset && !a.isDeleted,
      );
    } catch (_) {
      return null;
    }
  }

  /// 同步所有 pending 状态的本地批注到云端
  /// 返回：成功同步的数量
  Future<int> syncPendingAnnotations() async {
    if (!await _isOnline) return 0;

    final pending = await _local.getPendingAnnotations();
    if (pending.isEmpty) return 0;

    int successCount = 0;

    for (final annotation in pending) {
      bool synced = false;

      // 重试机制：最多3次
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          if (annotation.isDeleted) {
            // 同步删除操作
            if (annotation.id.isNotEmpty) {
              final result = await ApiClient.patch(
                'novel_annotations',
                {
                  'is_deleted': true,
                  'deleted_at': DateTime.now().toUtc().toIso8601String(),
                },
                id: annotation.id,
              );
              if (result.isSuccess) {
                await _local.markAsSynced(annotation.id);
                synced = true;
                break;
              }
            }
          } else if (annotation.id.isEmpty) {
            // 新建批注
            final result = await ApiClient.post('novel_annotations', annotation.toJson());
            if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
              final saved = NovelAnnotation.fromJson(result.data!.first);
              await _local.updateRemoteIdByFields(
                userId: annotation.userId,
                novelId: annotation.novelId,
                chapterId: annotation.chapterId,
                startOffset: annotation.startOffset,
                endOffset: annotation.endOffset,
                remoteId: saved.id,
              );
              synced = true;
              break;
            }
          } else {
            // 更新已有批注
            final body = <String, dynamic>{
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            };
            if (annotation.note != null) body['note'] = annotation.note;
            body['color'] = annotation.color.name;
            body['highlighted_text'] = annotation.highlightedText;

            final result = await ApiClient.patch('novel_annotations', body, id: annotation.id);
            if (result.isSuccess) {
              await _local.markAsSynced(annotation.id);
              synced = true;
              break;
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('AnnotationService-同步尝试${attempt + 1}失败: $e');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (synced) {
        successCount++;
      } else {
        // 3次均失败，标记为 failed
        final id = annotation.id.isNotEmpty ? annotation.id : '0';
        await _local.markAsFailed(id);
      }
    }

    // 清理已同步的软删除记录
    await _local.cleanupSyncedDeleted();

    return successCount;
  }

  /// 获取同步失败的批注列表（供 UI 提示用户）
  Future<List<NovelAnnotation>> getFailedAnnotations() async {
    final db = await _local.database;
    final rows = await db.query(
      'novel_annotations_local',
      where: "sync_status = 'failed' AND is_deleted = 0",
      orderBy: 'created_at DESC',
    );
    return rows.map((m) {
      return NovelAnnotation(
        id: m['id'] as String? ?? m['local_id'].toString(),
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
    }).toList();
  }

  /// 辅助：根据 ID 查找本地记录
  Future<NovelAnnotation?> _getLocalById(String id) async {
    final db = await _local.database;
    final rows = await db.query(
      'novel_annotations_local',
      where: 'id = ? OR local_id = ?',
      whereArgs: [id, int.tryParse(id) ?? 0],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final m = rows.first;
    return NovelAnnotation(
      id: m['id'] as String? ?? m['local_id'].toString(),
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

  /// 获取颜色对应的 Flutter Color
  static int getColorValue(AnnotationColor color) {
    switch (color) {
      case AnnotationColor.yellow:
        return 0xFFFFF59D;
      case AnnotationColor.green:
        return 0xFFA5D6A7;
      case AnnotationColor.blue:
        return 0xFF90CAF9;
      case AnnotationColor.red:
        return 0xFFEF9A9A;
    }
  }
}
