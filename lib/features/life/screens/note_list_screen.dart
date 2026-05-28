import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
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
    _loadNotes();
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

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/notes?user_id=eq.$userId&select=*&order=is_pinned.desc,created_at.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final notes = data.map((e) => NoteModel.fromJson(e)).toList();

        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
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
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/notes'),
        headers: SupabaseConfig.headers,
        body: jsonEncode(note.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<void> _updateNote(NoteModel note) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/notes?id=eq.${note.id}'),
        headers: SupabaseConfig.headers,
        body: jsonEncode(note.toJsonForUpdate()),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/notes?id=eq.$id'),
          headers: SupabaseConfig.headers,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          await _loadNotes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        setState(() => _isLoading = false);
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
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/notes?id=eq.${note.id}'),
        headers: SupabaseConfig.headers,
        body: jsonEncode({'is_pinned': updated.isPinned}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(note.isPinned ? '已取消置顶' : '已置顶')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
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
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无笔记',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
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
      id: widget.note?.id ?? '',
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
