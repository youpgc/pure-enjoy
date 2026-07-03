import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../services/offline_sync_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../models/note_model.dart';

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
  void _onLoadMore() {
    _loadNotes();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    try {
      await _loadCache();
      await _loadNotes(refresh: true);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ NoteListScreen _initLoad 异常');
        debugPrint('堆栈信息');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.create,
          table: 'notes',
          data: note.toJson(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.create,
        table: 'notes',
        data: note.toJson(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
        );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.update,
          table: 'notes',
          data: note.toJsonForUpdate(),
          filters: {'id': 'eq.${note.id}'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
        );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.delete,
          table: 'notes',
          filters: {'id': 'eq.$id'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.delete,
        table: 'notes',
        filters: {'id': 'eq.$id'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
        );
      }
    }
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      final hex = colorStr.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  void _showNoteForm([NoteModel? note]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NoteEditScreen(
          note: note,
          userId: _userId ?? 'local_user',
          onSave: (newNote) {
            if (note != null) {
              _updateNote(newNote);
            } else {
              _createNote(newNote);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _loadNotes(refresh: true);
              },
              decoration: InputDecoration(
                hintText: '搜索笔记...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchQuery = '';
                          _loadNotes(refresh: true);
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 笔记列表
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _notes.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _loadNotes(refresh: true),
                        child: CustomScrollView(
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: const EmptyWidget(icon: Icons.note_alt_outlined, message: '暂无笔记'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadNotes(refresh: true),
                        child: GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: _notes.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _notes.length) {
                              return buildLoadMoreIndicator();
                            }

                            final note = _notes[index];

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _showNoteForm(note),
                                onLongPress: () => _showDeleteConfirm(context, note.id, note.title),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            note.title,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: Text(
                                              note.content ?? '',
                                              style: Theme.of(context).textTheme.bodySmall,
                                              overflow: TextOverflow.fade,
                                            ),
                                          ),
                                          if (note.color != null)
                                            Container(
                                              width: 4,
                                              height: double.infinity,
                                              decoration: BoxDecoration(
                                                color: _parseColor(note.color),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateTimeUtils.formatStandard(note.createdAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colorScheme.outline.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (note.color != null)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Icon(
                                          Icons.push_pin,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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

class _NoteEditScreen extends StatefulWidget {
  final NoteModel? note;
  final String userId;
  final Function(NoteModel) onSave;

  const _NoteEditScreen({
    this.note,
    required this.userId,
    required this.onSave,
  });

  @override
  State<_NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<_NoteEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newNote = NoteModel(
        id: widget.note?.id ?? const Uuid().v4(),
        userId: widget.userId,
        title: _titleController.text,
        content: _contentController.text.isEmpty ? null : _contentController.text,
      );

      widget.onSave(newNote);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note != null ? '编辑笔记' : '新建笔记'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: '标题',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '写点什么...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
