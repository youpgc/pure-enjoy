import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'notes',
        filters: {'user_id': 'eq.$_userId'},
        order: 'updated_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _notes = result.data!;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNote() async {
    if (_userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _NoteDialog(),
    );

    if (result != null) {
      try {
        final insertResult = await ApiClient.post(
          'notes',
          body: {
            ...result,
            'user_id': _userId,
          },
        );

        if (insertResult.isSuccess) {
          _loadNotes();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('添加失败: ${insertResult.errorMessage}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _editNote(Map<String, dynamic> note) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NoteDialog(
        title: note['title'] ?? '',
        content: note['content'] ?? '',
      ),
    );

    if (result != null) {
      try {
        final updateResult = await ApiClient.patch(
          'notes',
          filters: {'id': 'eq.${note['id']}'},
          body: {
            ...result,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );

        if (updateResult.isSuccess) {
          _loadNotes();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('更新失败: ${updateResult.errorMessage}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      final result = await ApiClient.delete(
        'notes',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadNotes();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备忘录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(child: Text('暂无笔记'))
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final updatedAt = DateTime.parse(note['updated_at']);
                    return Dismissible(
                      key: Key(note['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteNote(note['id']),
                      child: ListTile(
                        title: Text(note['title'] ?? '无标题'),
                        subtitle: Text(
                          note['content'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          DateFormat('MM-dd HH:mm').format(updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _editNote(note),
                      ),
                    );
                  },
                ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  final String title;
  final String content;

  const _NoteDialog({this.title = '', this.content = ''});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _titleController = TextEditingController(text: widget.title);
  late final _contentController = TextEditingController(text: widget.content);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title.isEmpty ? '新建笔记' : '编辑笔记'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '内容',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'title': _titleController.text,
              'content': _contentController.text,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
