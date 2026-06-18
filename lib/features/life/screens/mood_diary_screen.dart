import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../widgets/common_widgets.dart';
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
    _initLoad();
  }

  /// 初始化加载：先确保字典加载完成，再读缓存，最后静默刷新
  Future<void> _initLoad() async {
    try {
      await DictService.instance.initialize();
      await _loadCache();
      await _loadDiaries();
    } catch (e, stackTrace) {
      debugPrint('❌ MoodDiaryScreen _initLoad 异常: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
      }
    }
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final cached = await CacheHelper.instance.loadList(CacheHelper.keyDiaries);
      if (cached.isNotEmpty && mounted) {
        final diaries = <MoodDiaryModel>[];
        for (final item in cached) {
          try {
            diaries.add(MoodDiaryModel.fromJson(item));
          } catch (e) {
            debugPrint('⚠️ 跳过无效缓存日记数据: $e');
          }
        }
        setState(() {
          _diaries = diaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 加载缓存失败: $e');
    }
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

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);

      final result = await ApiClient.get(
        'mood_diaries',
        filters: {
          'user_id': 'eq.$userId',
          'date.gte': startOfMonth.toIso8601String().split('T').first,
          'date.lt': endOfMonth.toIso8601String().split('T').first,
        },
        order: 'date.desc',
      );

      if (result.isSuccess) {
        final data = result.data!;
        final diaries = <MoodDiaryModel>[];
        for (final item in data) {
          try {
            diaries.add(MoodDiaryModel.fromJson(item));
          } catch (e) {
            debugPrint('⚠️ 跳过无效日记数据: $e, 数据: $item');
          }
        }

        if (mounted) {
          setState(() {
            _diaries = diaries;
            _isLoading = false;
          });
        }

        // 写入缓存
        await CacheHelper.instance.saveList(
          CacheHelper.keyDiaries,
          diaries.map((d) => d.toJson()).toList(),
        );
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ MoodDiaryScreen _loadDiaries 异常: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _createMoodDiary(MoodDiaryModel diary) async {
    try {
      final result = await ApiClient.post(
        'mood_diaries',
        body: diary.toJson(),
      );

      if (result.isSuccess) {
        await _loadDiaries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteMoodDiary(String id) async {
    final confirm = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这条日记吗？');

    if (confirm == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'mood_diaries',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          await _loadDiaries();
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

  Future<void> _updateMoodDiary(MoodDiaryModel diary) async {
    try {
      final result = await ApiClient.patchByFilter(
        'mood_diaries',
        filters: {'id': 'eq.${diary.id}'},
        body: diary.toUpdateJson(),
      );

      if (result.isSuccess) {
        await _loadDiaries();
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
          ? const LoadingWidget()
          : _diaries.isEmpty
              ? const EmptyWidget(icon: Icons.mood_outlined, message: '暂无日记，点击右下角按钮添加')
              : RefreshIndicator(
                  onRefresh: _loadDiaries,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _diaries.length,
                    itemBuilder: (context, index) {
                      final diary = _diaries[index];
                      final moodLabel = DictService.instance.getLabel(
                        DictService.moodType,
                        diary.mood,
                        defaultValue: diary.mood,
                      );
                      final moodEmoji = DictService.instance.getEmoji(
                        DictService.moodType,
                        diary.mood,
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
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            moodEmoji.isNotEmpty ? moodEmoji : '😊',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(moodLabel),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateTimeUtils.formatStandard(diary.createdAt ?? diary.entryDate),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    EditDeletePopupMenu(
                                      onEdit: () => _showEditDiaryForm(diary),
                                      onDelete: () => _deleteMoodDiary(diary.id),
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
  late String _selectedMoodCode;
  late DateTime _selectedDate;
  bool _isDictLoading = true;

  bool get _isEditing => widget.diary != null;

  /// 获取心情选项列表（从字典服务）
  List<String> get _moodCodes {
    return DictService.instance.getItemsSync(DictService.moodType).map((e) => e.code).toList();
  }

  @override
  void initState() {
    super.initState();
    _initDict();
  }

  Future<void> _initDict() async {
    await DictService.instance.initialize();
    final diary = widget.diary;
    _contentController = TextEditingController(text: diary?.content ?? '');
    _selectedMoodCode = diary?.mood ?? DictService.instance.getDefaultCode(DictService.moodType);
    if (_selectedMoodCode.isEmpty && _moodCodes.isNotEmpty) {
      _selectedMoodCode = _moodCodes.first;
    }
    _selectedDate = diary?.entryDate ?? DateTime.now();
    if (mounted) {
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

  void _save() {
    final newDiary = MoodDiaryModel(
      id: _isEditing ? widget.diary!.id : const Uuid().v4(),
      userId: _isEditing ? widget.diary!.userId : widget.userId,
      mood: _selectedMoodCode,
      moodScore: int.tryParse(DictService.instance.findByCode(DictService.moodType, _selectedMoodCode)?.value ?? '5') ?? 5,
      content: _contentController.text.isEmpty ? null : _contentController.text,
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
          if (_isDictLoading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moodCodes.map((code) {
              final label = DictService.instance.getLabel(DictService.moodType, code, defaultValue: code);
              final emoji = DictService.instance.getEmoji(DictService.moodType, code);
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
