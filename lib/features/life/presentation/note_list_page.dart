import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';
import '../data/note_model.dart';

/// 笔记本列表页面
class NoteListPage extends ConsumerStatefulWidget {
  const NoteListPage({super.key});

  @override
  ConsumerState<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends ConsumerState<NoteListPage> {
  List<NoteModel> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    final box = StorageService().noteBox;
    setState(() {
      _notes = box.values.toList()
        ..sort((a, b) {
          // 置顶优先，然后按更新时间排序
          if (a.pinned != b.pinned) {
            return a.pinned ? -1 : 1;
          }
          return b.updatedAt.compareTo(a.updatedAt);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记本'),
      ),
      body: _notes.isEmpty
          ? _buildEmptyState()
          : _buildNoteList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有笔记',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角创建第一条笔记',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: note.pinned
                ? const Icon(Icons.push_pin, color: AppTheme.primaryColor)
                : null,
            title: Text(
              note.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.content != null && note.content!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note.content!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(note.updatedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditDialog(note: note);
                    break;
                  case 'pin':
                    _togglePin(note);
                    break;
                  case 'delete':
                    _deleteNote(note);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('编辑'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        note.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(note.pinned ? '取消置顶' : '置顶'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showEditDialog(note: note),
          ),
        );
      },
    );
  }

  void _showEditDialog({NoteModel? note}) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note == null ? '新建笔记' : '编辑笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: '标题',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '内容',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              final now = DateTime.now();
              if (note == null) {
                final newNote = NoteModel(
                  id: now.millisecondsSinceEpoch.toString(),
                  title: title,
                  content: contentController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                await StorageService().noteBox.put(newNote.id, newNote);
                SyncService().uploadNote(newNote); // 同步到云端
              } else {
                final updatedNote = note.copyWith(
                  title: title,
                  content: contentController.text.trim(),
                  updatedAt: now,
                );
                await StorageService().noteBox.put(updatedNote.id, updatedNote);
                SyncService().uploadNote(updatedNote); // 同步到云端
              }
              Navigator.pop(context);
              _loadNotes();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin(NoteModel note) async {
    final updatedNote = note.copyWith(
      pinned: !note.pinned,
      updatedAt: DateTime.now(),
    );
    await StorageService().noteBox.put(updatedNote.id, updatedNote);
    _loadNotes();
  }

  void _deleteNote(NoteModel note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await StorageService().noteBox.delete(note.id);
              SyncService().deleteRemote('notes', note.id); // 从云端删除
              Navigator.pop(context);
              _loadNotes();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
