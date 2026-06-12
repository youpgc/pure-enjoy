import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../models/note_model.dart';

/// 笔记列表页面 - Supabase 数据同步
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<NoteModel> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    await _loadCache();
    await _loadNotes();
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

  Future<void> _loadNotes() async {
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

    try {
      final result = await ApiClient.get(
        'notes',
        filters: {'user_id': 'eq.$userId'},
        order: 'is_pinned.desc,updated_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final notes = data.map((e) => NoteModel.fromJson(e)).toList();

        setState(() {
          _notes = notes;
          _isLoading = false;
        });

        // 写入缓存
        await CacheHelper.instance.saveList(
          CacheHelper.keyNotes,
          notes.map((n) => n.toJson()).toList(),
        );
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
        body: note.toJson(),
      );

      if (result.isSuccess) {
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建成功')),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<void> _updateNote(NoteModel note) async {
    try {
      final result = await ApiClient.patch(
        'notes',
        filters: {'id': 'eq.${note.id}'},
        body: note.toJsonForUpdate(),
      );

      if (result.isSuccess) {
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    final confirm = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这条笔记吗？');

    if (confirm == true) {
      try {
        final result = await ApiClient.delete(
          'notes',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          await _loadNotes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${result.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _togglePin(NoteModel note) async {
    try {
      final updated = note.copyWith(isPinned: !note.isPinned);
      final result = await ApiClient.patch(
        'notes',
        filters: {'id': 'eq.${note.id}'},
        body: {'is_pinned': updated.isPinned},
      );

      if (result.isSuccess) {
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(note.isPinned ? '已取消置顶' : '已置顶')),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
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
          onSave: (newNote) {
            if (note != null) {
              _updateNote(newNote);
            } else {
              _createNote(newNote);
            }
          },
          onTogglePin: note != null ? () => _togglePin(note) : null,
        ),
      ),
    );
  }

  List<NoteModel> get _filteredNotes {
    if (_searchQuery.isEmpty) return _notes;
    return _notes.where((note) {
      final titleMatch = note.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final contentMatch = note.content?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      return titleMatch || contentMatch;
    }).toList();
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
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: '搜索笔记...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // 笔记列表
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _filteredNotes.isEmpty
                    ? const EmptyWidget(icon: Icons.note_alt_outlined, message: '暂无笔记')
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _showNoteForm(note),
                                onLongPress: () => _deleteNote(note.id),
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
                                          if (note.tags != null && note.tags!.isNotEmpty)
                                            Wrap(
                                              spacing: 4,
                                              children: note.tags!.take(2).map((tag) => Text(
                                                '#$tag',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colorScheme.primary,
                                                ),
                                              )).toList(),
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
                                    if (note.isPinned)
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
  final VoidCallback? onTogglePin;

  const _NoteEditScreen({
    this.note,
    required this.userId,
    required this.onSave,
    this.onTogglePin,
  });

  @override
  State<_NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<_NoteEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isPinned = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content ?? '';
      _tagsController.text = widget.note!.tags?.join(', ') ?? '';
      _isPinned = widget.note!.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final newNote = NoteModel(
      id: widget.note?.id ?? const Uuid().v4(),
      userId: widget.userId,
      title: _titleController.text,
      content: _contentController.text.isEmpty ? null : _contentController.text,
      tags: tags.isEmpty ? null : tags,
      isPinned: _isPinned,
    );

    widget.onSave(newNote);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note != null ? '编辑笔记' : '新建笔记'),
        actions: [
          if (widget.onTogglePin != null)
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
                widget.onTogglePin!();
              },
            ),
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
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                hintText: '标签（可选，逗号分隔）',
                prefixIcon: Icon(Icons.tag),
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
