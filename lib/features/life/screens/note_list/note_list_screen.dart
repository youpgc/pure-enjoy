import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/event_bus.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../services/sensitive_word_service.dart';
import '../../../../utils/date_time_utils.dart';
import '../../../../utils/cache_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/paginated_list_mixin.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/note_model.dart';

part 'note_list_parts.dart';
part 'note_edit_screen_part.dart';

/// 笔记列表页面 - Supabase 数据同步
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> with PaginatedListMixin {
  List<NoteModel> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    initPagination();
    _initLoad();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadNotes();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    try {
      await _loadCache();
      await _loadNotes(refresh: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ NoteListScreen _initLoad 异常');
        debugPrint('堆栈信息');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, '初始化失败，请稍后重试', isError: true);
      }
    }
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyNotes);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _notes = cached.map((e) => NoteModel.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotes({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '请先登录');
      }
      return;
    }

    if (refresh) {
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };

      if (_searchQuery.isNotEmpty) {
        filters['search'] = _searchQuery;
        filters['searchFields'] = 'title,content';
      }

      final (limit, offset) = paginationParams;

      final result = await ApiClient.get(
        'notes',
        filters: filters,
        order: 'is_pinned.desc,updated_at.desc',
        limit: limit,
        offset: offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final notes = data.map((e) => NoteModel.fromJson(e)).toList();

        setState(() {
          if (refresh) {
            _notes = notes;
          } else {
            _notes.addAll(notes);
          }
          _isLoading = false;
          onPaginationDataLoaded(notes.length);
        });

        // 写入缓存（仅刷新时）
        if (refresh) {
          await CacheHelper.instance.saveList(
            CacheHelper.keyNotes,
            notes.map((n) => n.toJson()).toList(),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '加载失败，请稍后重试', isError: true);
      }
    }
  }

  Future<void> _createNote(NoteModel note) async {
    try {
      final result = await ApiClient.post(
        'notes',
        note.toJson(),
      );

      if (result.isSuccess) {
        await _loadNotes(refresh: true);
        OfflineSyncService.instance.syncPending();
        EventBus.instance.fire(EventType.noteUpdated);
        if (mounted) {
          showSnackBar(context, '创建成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.create,
          table: 'notes',
          data: note.toJson(),
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.create,
        table: 'notes',
        data: note.toJson(),
      );
      if (mounted) {
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
      }
    }
  }

  Future<void> _updateNote(NoteModel note) async {
    try {
      final result = await ApiClient.patchByFilter(
        'notes',
        filters: {'id': 'eq.${note.id}'},
        body: note.toJsonForUpdate(),
      );

      if (result.isSuccess) {
        await _loadNotes(refresh: true);
        OfflineSyncService.instance.syncPending();
        EventBus.instance.fire(EventType.noteUpdated);
        if (mounted) {
          showSnackBar(context, '更新成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.update,
          table: 'notes',
          data: note.toJsonForUpdate(),
          filters: {'id': 'eq.${note.id}'},
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.update,
        table: 'notes',
        data: note.toJsonForUpdate(),
        filters: {'id': 'eq.${note.id}'},
      );
      if (mounted) {
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
      }
    }
  }

  Future<void> _showDeleteConfirm(BuildContext context, String noteId, String noteTitle) async {
    final confirm = await showConfirmDialog(context, title: '确认删除', content: '确定要删除笔记「$noteTitle」吗？');
    if (confirm == true) {
      _deleteNote(noteId);
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      final result = await ApiClient.batchDeleteByFilter(
        'notes',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        await _loadNotes(refresh: true);
        OfflineSyncService.instance.syncPending();
        EventBus.instance.fire(EventType.noteUpdated);
        if (mounted) {
          showSnackBar(context, '删除成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.delete,
          table: 'notes',
          filters: {'id': 'eq.$id'},
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.delete,
        table: 'notes',
        filters: {'id': 'eq.$id'},
      );
      if (mounted) {
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
      }
    }
  }

  void _showNoteForm([NoteModel? note]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NoteEditScreen(
          note: note,
          userId: _userId ?? 'local_user',
          onSave: (newNote) async {
            // 系统敏感词检测
            await SensitiveWordService.instance.initialize();
            final titleResult = SensitiveWordService.instance.checkSystemContentSync(newNote.title);
            final contentResult = newNote.content == null || newNote.content!.isEmpty
                ? null
                : SensitiveWordService.instance.checkSystemContentSync(newNote.content!);
            if (titleResult.isBlocked || (contentResult?.isBlocked ?? false)) {
              if (mounted) {
                showSnackBar(context, '笔记内容包含敏感信息，请修改后重试', isError: true);
              }
              return;
            }
            final filteredNote = newNote.copyWith(
              title: titleResult.processedText,
              content: contentResult?.processedText ?? newNote.content,
            );
            if (note != null) {
              _updateNote(filteredNote);
            } else {
              _createNote(filteredNote);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
      ),
      body: Column(
        children: [
          // 搜索框
          _NoteSearchBar(
            searchQuery: _searchQuery,
            onChanged: (value) {
              _searchQuery = value;
              setState(() => _isLoading = true);
              _loadNotes(refresh: true);
            },
            onClear: () {
              _searchQuery = '';
              setState(() => _isLoading = true);
              _loadNotes(refresh: true);
            },
          ),

          // 笔记列表
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _notes.isEmpty
                    ? _NoteEmptyState(
                        onRefresh: () => _loadNotes(refresh: true),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadNotes(refresh: true),
                        child: GridView.builder(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: AppTheme.gridAspectRatio(context, 1),
                          ),
                          itemCount: _notes.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _notes.length) {
                              return buildLoadMoreIndicator();
                            }

                            final note = _notes[index];

                            return _NoteGridItem(
                              note: note,
                              onTap: () => _showNoteForm(note),
                              onLongPress: () => _showDeleteConfirm(context, note.id, note.title),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

