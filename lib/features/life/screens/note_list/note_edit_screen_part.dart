part of './note_list_screen.dart';

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
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isSaving = false;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content ?? '';
      _categoryController.text = widget.note!.category ?? '';
      // 回填标签（逗号分隔）与置顶，避免编辑时丢失已有值
      _tagsController.text = widget.note!.tags?.join(', ') ?? '';
      _isPinned = widget.note!.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_titleController.text.isEmpty) {
      showSnackBar(context, '请输入标题');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 逗号分隔文本 → 标签数组（铁律⑤）；空则传 null 以清空
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final newNote = NoteModel(
        id: widget.note?.id ?? const Uuid().v4(),
        userId: widget.userId,
        title: _titleController.text,
        content: _contentController.text.isEmpty ? null : _contentController.text,
        category: _categoryController.text.isEmpty ? null : _categoryController.text,
        tags: tags.isNotEmpty ? tags : null,
        isPinned: _isPinned,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: '标题',
                border: InputBorder.none,
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                hintText: '分类（可选）',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                hintText: '标签（逗号分隔，可选）',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.tag_outlined),
              ),
              textAlign: TextAlign.start,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('置顶'),
              value: _isPinned,
              onChanged: (v) => setState(() => _isPinned = v),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlign: TextAlign.start,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '写点什么...',
                  border: InputBorder.none,
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
