import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/database_service.dart';
import '../models/mood_diary_model.dart';

/// 心情日记页面
class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => _MoodDiaryScreenState();
}

class _MoodDiaryScreenState extends State<MoodDiaryScreen> {
  List<MoodDiaryModel> _diaries = [];
  bool _isLoading = true;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
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
      final diaries = await DatabaseService.instance.getMoodDiaries(userId);

      setState(() {
        _diaries = diaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _createMoodDiary(MoodDiaryModel diary) async {
    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.createMoodDiary(diary);
      await _loadDiaries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加成功')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _updateMoodDiary(MoodDiaryModel diary) async {
    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.updateMoodDiary(diary);
      await _loadDiaries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新成功')),
        );
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

  Future<void> _deleteMoodDiary(MoodDiaryModel diary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条日记吗？'),
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
        await DatabaseService.instance.deleteMoodDiary(diary.id);
        await _loadDiaries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
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

  void _showDiaryForm([MoodDiaryModel? diary]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DiaryForm(
        diary: diary,
        userId: _userId ?? 'local_user',
        onSave: (newDiary) {
          Navigator.pop(context);
          if (diary != null) {
            _updateMoodDiary(newDiary);
          } else {
            _createMoodDiary(newDiary);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情日记'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _diaries.isEmpty
              ? const Center(child: Text('暂无日记，点击右下角按钮添加'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _diaries.length,
                  itemBuilder: (context, index) {
                    final diary = _diaries[index];
                    final moodType = MoodType.values.firstWhere(
                      (m) => m.name == diary.mood,
                      orElse: () => MoodType.calm,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _showDiaryForm(diary),
                        onLongPress: () => _deleteMoodDiary(diary),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: moodType.color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          moodType.emoji,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(moodType.label),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MM-dd HH:mm').format(diary.date),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              if (diary.content != null && diary.content!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  diary.content!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDiaryForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DiaryForm extends StatefulWidget {
  final MoodDiaryModel? diary;
  final String userId;
  final Function(MoodDiaryModel) onSave;

  const _DiaryForm({this.diary, required this.userId, required this.onSave});

  @override
  State<_DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends State<_DiaryForm> {
  final _contentController = TextEditingController();
  MoodType _selectedMood = MoodType.calm;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.diary != null) {
      _contentController.text = widget.diary!.content ?? '';
      _selectedMood = MoodType.values.firstWhere(
        (m) => m.name == widget.diary!.mood,
        orElse: () => MoodType.calm,
      );
      _selectedDate = widget.diary!.date;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    final newDiary = MoodDiaryModel(
      id: widget.diary?.id ?? 'mood_${DateTime.now().millisecondsSinceEpoch}',
      userId: widget.userId,
      mood: _selectedMood.name,
      content: _contentController.text.isEmpty ? null : _contentController.text,
      date: _selectedDate,
      createdAt: widget.diary?.createdAt ?? DateTime.now(),
    );

    widget.onSave(newDiary);
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
            widget.diary != null ? '编辑日记' : '写日记',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // 心情选择
          Text('今天心情如何？', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MoodType.values.map((mood) => ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mood.emoji),
                  const SizedBox(width: 4),
                  Text(mood.label),
                ],
              ),
              selected: _selectedMood == mood,
              selectedColor: mood.color.withOpacity(0.3),
              onSelected: (selected) {
                if (selected) setState(() => _selectedMood = mood);
              },
            )).toList(),
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
            trailing: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
