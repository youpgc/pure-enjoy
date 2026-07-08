import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/supabase_service.dart';
import '../../../life/models/note_model.dart';

/// 添加笔记底部弹窗
///
/// 用于快速创建一条笔记，包含标题、内容与分类。
class AddNoteSheet extends StatefulWidget {
  final Function(NoteModel) onSave;

  const AddNoteSheet({super.key, required this.onSave});

  @override
  State<AddNoteSheet> createState() => AddNoteSheetState();
}

class AddNoteSheetState extends State<AddNoteSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
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
      final note = NoteModel(
        id: const Uuid().v4(),
        userId: AuthService.instance.currentUserId ?? 'local_user',
        title: _titleController.text,
        content: _contentController.text.isEmpty ? null : _contentController.text,
        category: _categoryController.text.isEmpty ? null : _categoryController.text,
      );

      widget.onSave(note);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('记笔记', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '输入笔记标题',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '内容',
              hintText: '写点什么...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: '分类（可选）',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
