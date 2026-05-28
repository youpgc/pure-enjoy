import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../models/mood_diary_model.dart';

/// 心情日记页面 - Supabase 数据同步
class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => _MoodDiaryScreenState();
}

class _MoodDiaryScreenState extends State<MoodDiaryScreen> {
  List<MoodDiaryModel> _diaries = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;

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
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/mood_diaries?user_id=eq.$userId&select=*&order=date.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final diaries = data.map((e) => MoodDiaryModel.fromJson(e)).toList();

        setState(() {
          _diaries = diaries;
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

  Future<void> _createMoodDiary(MoodDiaryModel diary) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/mood_diaries'),
        headers: SupabaseConfig.headers,
        body: jsonEncode(diary.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadDiaries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
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

  Future<void> _deleteMoodDiary(String id) async {
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
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/mood_diaries?id=eq.$id'),
          headers: SupabaseConfig.headers,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          await _loadDiaries();
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

  Future<void> _updateMoodDiary(MoodDiaryModel diary) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/mood_diaries?id=eq.${diary.id}'),
        headers: SupabaseConfig.headers,
        body: jsonEncode({
          'mood': diary.mood,
          'mood_score': diary.moodScore,
          'content': diary.content,
          'tags': diary.tags,
          'date': diary.entryDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadDiaries();
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

  void _showEditDiaryForm(MoodDiaryModel diary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DiaryForm(
        userId: _userId ?? 'local_user',
        diary: diary,
        onSave: (updatedDiary) {
          Navigator.pop(context);
          _updateMoodDiary(updatedDiary);
        },
      ),
    );
  }

  void _showDiaryForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DiaryForm(
        userId: _userId ?? 'local_user',
        onSave: (newDiary) {
          Navigator.pop(context);
          _createMoodDiary(newDiary);
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
                        onTap: () => _showEditDiaryForm(diary),
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
                                    DateFormat('MM-dd').format(diary.entryDate),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _showEditDiaryForm(diary);
                                          break;
                                        case 'delete':
                                          _deleteMoodDiary(diary.id);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('编辑'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('删除', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
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
                              if (diary.tags != null && diary.tags!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: diary.tags!.map((tag) => Chip(
                                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  )).toList(),
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
  final String userId;
  final MoodDiaryModel? diary;
  final Function(MoodDiaryModel) onSave;

  const _DiaryForm({required this.userId, this.diary, required this.onSave});

  @override
  State<_DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends State<_DiaryForm> {
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late MoodType _selectedMood;
  late DateTime _selectedDate;

  bool get _isEditing => widget.diary != null;

  @override
  void initState() {
    super.initState();
    final diary = widget.diary;
    _contentController = TextEditingController(text: diary?.content ?? '');
    _tagsController = TextEditingController(
      text: diary?.tags?.join(', ') ?? '',
    );
    _selectedMood = diary != null
        ? MoodType.values.firstWhere(
            (m) => m.name == diary.mood,
            orElse: () => MoodType.calm,
          )
        : MoodType.calm;
    _selectedDate = diary?.entryDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _save() {
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final newDiary = MoodDiaryModel(
      id: _isEditing ? widget.diary!.id : '',
      userId: _isEditing ? widget.diary!.userId : widget.userId,
      mood: _selectedMood.name,
      moodScore: _selectedMood.score,
      content: _contentController.text.isEmpty ? null : _contentController.text,
      tags: tags.isEmpty ? null : tags,
      entryDate: _selectedDate,
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
            '写日记',
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

          // 标签输入
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: '标签（可选，逗号分隔）',
              hintText: '工作, 运动, 阅读',
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
