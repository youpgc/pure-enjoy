import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/dict_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../life/models/mood_diary_model.dart';
import '../../../../utils/date_time_utils.dart';

/// 添加心情日记底部弹窗
///
/// 用于快速记录当天的心情与日记内容。
class AddMoodSheet extends StatefulWidget {
  final Function(MoodDiaryModel) onSave;

  const AddMoodSheet({super.key, required this.onSave});

  @override
  State<AddMoodSheet> createState() => AddMoodSheetState();
}

class AddMoodSheetState extends State<AddMoodSheet> {
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  String _selectedMoodCode = '';
  DateTime _selectedDate = DateTime.now();
  bool _isDictLoading = true;
  bool _isSaving = false;

  /// 获取心情选项列表（从字典服务）
  List<String> get _moodCodes {
    return DictService.instance.getItemsSync('mood_type').map((e) => e.code).toList();
  }

  @override
  void initState() {
    super.initState();
    _initDict();
    // 监听字典刷新
    DictService.instance.refreshNotifier.addListener(_onDictRefresh);
  }

  Future<void> _initDict() async {
    await DictService.instance.initialize();
    _selectedMoodCode = DictService.instance.getDefaultCode('mood_type');
    if (_selectedMoodCode.isEmpty && _moodCodes.isNotEmpty) {
      _selectedMoodCode = _moodCodes.first;
    }
    if (mounted) {
      setState(() => _isDictLoading = false);
    }
  }

  void _onDictRefresh() {
    if (mounted) {
      setState(() {
        if (_selectedMoodCode.isEmpty && _moodCodes.isNotEmpty) {
          _selectedMoodCode = _moodCodes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    DictService.instance.refreshNotifier.removeListener(_onDictRefresh);
    _contentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final diary = MoodDiaryModel(
        id: const Uuid().v4(),
        userId: AuthService.instance.currentUserId ?? 'local_user',
        mood: _selectedMoodCode,
        moodScore: int.tryParse(DictService.instance.findByCode('mood_type', _selectedMoodCode)?.value ?? '5') ?? 5,
        content: _contentController.text.isEmpty ? null : _contentController.text,
        entryDate: _selectedDate,
      );

      widget.onSave(diary);
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
          Text('写日记', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('今天心情如何？', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          if (_isDictLoading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moodCodes.map((code) {
              final label = DictService.instance.getLabelOrDefault('mood_type', code, defaultValue: code);
              final emoji = DictService.instance.getEmoji('mood_type', code);
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji.isNotEmpty ? emoji : '😊'),
                    const SizedBox(width: 4),
                    Text(label),
                  ],
                ),
                selected: _selectedMoodCode == code,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedMoodCode = code);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '写点什么...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _isSaving ? null : _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
