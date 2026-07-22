import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/dict_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../models/mood_diary_model.dart';
import '../widgets/app_date_picker.dart';

/// 心情日记表单（新增/编辑），作为底部弹窗使用
class DiaryForm extends StatefulWidget {
  final String userId;
  final MoodDiaryModel? diary;
  final Function(MoodDiaryModel) onSave;

  // ignore: unused_element_parameter
  const DiaryForm({super.key, required this.userId, this.diary, required this.onSave});

  @override
  State<DiaryForm> createState() => DiaryFormState();
}

class DiaryFormState extends State<DiaryForm> {
  late final TextEditingController _contentController;
  late String _selectedMoodCode;
  late DateTime _selectedDate;
  bool _isDictLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.diary != null;

  /// 获取心情选项列表（从字典服务）
  List<String> get _moodCodes {
    return DictService.instance.getItemsSync('mood_type').map((e) => e.code).toList();
  }

  @override
  void initState() {
    super.initState();
    // 同步初始化 late 字段，避免首次 build（早于 _initDict 异步完成）时
    // 访问未初始化的 _contentController / _selectedDate 触发 LateInitializationError
    final diary = widget.diary;
    _contentController = TextEditingController(text: diary?.content ?? '');
    _selectedDate = diary?.entryDate ?? DateTime.now();
    _selectedMoodCode = diary?.mood ?? '';
    _initDict();
  }

  Future<void> _initDict() async {
    await DictService.instance.initialize();
    if (mounted) {
      // 仅在尚未选定（新增且字典未就绪）时回退到默认/首个心情码
      if (_selectedMoodCode.isEmpty) {
        _selectedMoodCode = DictService.instance.getDefaultCode('mood_type');
        if (_selectedMoodCode.isEmpty && _moodCodes.isNotEmpty) {
          _selectedMoodCode = _moodCodes.first;
        }
      }
      setState(() => _isDictLoading = false);
    }
    // 监听字典刷新
    DictService.instance.refreshNotifier.addListener(_onDictRefresh);
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final newDiary = MoodDiaryModel(
        id: _isEditing ? widget.diary!.id : const Uuid().v4(),
        userId: _isEditing ? widget.diary!.userId : widget.userId,
        mood: _selectedMoodCode,
        moodScore: int.tryParse(DictService.instance.findByCode('mood_type', _selectedMoodCode)?.value ?? '5') ?? 5,
        content: _contentController.text.isEmpty ? null : _contentController.text,
        entryDate: _selectedDate,
      );

      widget.onSave(newDiary);
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
          Text(
            '写日记',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // 心情选择
          Text('今天心情如何？', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          if (_isDictLoading)
            const Center(child: LoadingWidget())
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

          // 内容输入
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '写点什么...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // 日期选择
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
            onTap: () async {
              final picked = await AppDatePicker.show(
                context,
                type: DateTimeType.date,
                initialDate: _selectedDate,
                minDate: DateTime(2020),
                maxDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
