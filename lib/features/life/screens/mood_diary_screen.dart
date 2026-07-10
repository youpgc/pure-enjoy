import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/event_bus.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../services/offline_sync_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../widgets/common_widgets.dart';
import '../models/mood_diary_model.dart';
import '../widgets/app_date_picker.dart';

/// 心情日记页面 - Supabase 数据同步
class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => _MoodDiaryScreenState();
}

class _MoodDiaryScreenState extends State<MoodDiaryScreen> with PaginatedListMixin {
  List<MoodDiaryModel> _diaries = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    initPagination();
    _initLoad();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadDiaries();
  }

  /// 初始化加载：先确保字典加载完成，再读缓存，最后静默刷新
  Future<void> _initLoad() async {
    try {
      await DictService.instance.initialize();
      await _loadCache();
      await _loadDiaries(refresh: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MoodDiaryScreen _initLoad 异常');
        debugPrint('堆栈信息');
      }
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
            if (kDebugMode) {
              debugPrint('⚠️ 跳过无效缓存日记数据');
            }
          }
        }
        setState(() {
          _diaries = diaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 加载缓存失败');
      }
    }
  }

  Future<void> _loadDiaries({bool refresh = false}) async {
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

    if (refresh) {
      resetPagination();
    }

    // 触底加载时使用 beginLoadMore
    if (!refresh && !beginLoadMore()) return;

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final (limit, offset) = paginationParams;

      final result = await ApiClient.get(
        'mood_diaries',
        filters: {
          'user_id': 'eq.$userId',
          'and': '(date.gte.${startOfMonth.toIso8601String().split('T').first},date.lt.${endOfMonth.toIso8601String().split('T').first})',
        },
        order: 'date.desc',
        limit: limit,
        offset: offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final diaries = <MoodDiaryModel>[];
        for (final item in data) {
          try {
            diaries.add(MoodDiaryModel.fromJson(item));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ 跳过无效日记数据');
            }
          }
        }

        if (mounted) {
          setState(() {
            if (refresh) {
              _diaries = diaries;
            } else {
              _diaries.addAll(diaries);
            }
            onPaginationDataLoaded(diaries.length);
            _isLoading = false;
          });
        }

        // 写入缓存（仅首次加载时）
        if (refresh) {
          await CacheHelper.instance.saveList(
            CacheHelper.keyDiaries,
            diaries.map((d) => d.toJson()).toList(),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MoodDiaryScreen _loadDiaries 异常');
        debugPrint('堆栈信息');
      }
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
        diary.toJson(),
      );

      if (result.isSuccess) {
        await _loadDiaries();
        OfflineSyncService.instance.syncPending();
        EventBus.instance.fire(EventType.moodDiaryUpdated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.create,
          table: 'mood_diaries',
          data: diary.toJson(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.create,
        table: 'mood_diaries',
        data: diary.toJson(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
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
          OfflineSyncService.instance.syncPending();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          await OfflineSyncService.instance.enqueue(
            action: OfflineAction.delete,
            table: 'mood_diaries',
            filters: {'id': 'eq.$id'},
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
            );
          }
        }
      } catch (e) {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.delete,
          table: 'mood_diaries',
          filters: {'id': 'eq.$id'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
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
        OfflineSyncService.instance.syncPending();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.update,
          table: 'mood_diaries',
          data: diary.toUpdateJson(),
          filters: {'id': 'eq.${diary.id}'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.update,
        table: 'mood_diaries',
        data: diary.toUpdateJson(),
        filters: {'id': 'eq.${diary.id}'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
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
        actions: [
          // 心情统计入口暂不使用
          // IconButton(
          //   icon: const Icon(Icons.bar_chart),
          //   tooltip: '心情统计',
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const MoodStatisticsScreen()),
          //     );
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await AppDatePicker.show(
                context,
                type: DateTimeType.yearMonth,
                initialDate: _selectedMonth,
                minDate: DateTime(2020),
                maxDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedMonth = picked);
                _loadDiaries(refresh: true);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _diaries.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadDiaries(refresh: true),
                  child: const CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyWidget(icon: Icons.mood_outlined, message: '暂无日记，点击右下角按钮添加'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadDiaries(refresh: true),
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _diaries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _diaries.length) {
                        return buildLoadMoreIndicator();
                      }
                      final diary = _diaries[index];
                      final moodLabel = DictService.instance.getLabelOrDefault(
                        'mood_type',
                        diary.mood,
                        defaultValue: diary.mood,
                      );
                      final moodEmoji = DictService.instance.getEmoji(
                        'mood_type',
                        diary.mood,
                      );
                      final displayDate = diary.createdAt != null &&
                              diary.createdAt!.year == diary.entryDate.year &&
                              diary.createdAt!.month == diary.entryDate.month &&
                              diary.createdAt!.day == diary.entryDate.day
                          ? diary.createdAt!
                          : diary.entryDate;

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
                                      DateTimeUtils.formatStandard(displayDate),
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
  bool _isSaving = false;

  bool get _isEditing => widget.diary != null;

  /// 获取心情选项列表（从字典服务）
  List<String> get _moodCodes {
    return DictService.instance.getItemsSync('mood_type').map((e) => e.code).toList();
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
    _selectedMoodCode = diary?.mood ?? DictService.instance.getDefaultCode('mood_type');
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
