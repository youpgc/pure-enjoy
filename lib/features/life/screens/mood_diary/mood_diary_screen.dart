import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/event_bus.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/dict_service.dart';
import '../../../../services/api_client.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../services/sensitive_word_service.dart';
import '../../../../utils/cache_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/paginated_list_mixin.dart';
import '../../models/mood_diary_model.dart';
import '../mood_diary_form.dart';
import './mood_diary_content.dart';

/// 心情日记页面 - Supabase 数据同步
class MoodDiaryScreen extends StatefulWidget {
  const MoodDiaryScreen({super.key});

  @override
  State<MoodDiaryScreen> createState() => _MoodDiaryScreenState();
}

class _MoodDiaryScreenState extends State<MoodDiaryScreen> with PaginatedListMixin {
  List<MoodDiaryModel> _diaries = [];
  bool _isLoading = true;

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
        showSnackBar(context, '初始化失败，请稍后重试', isError: true);
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
        showSnackBar(context, '请先登录');
      }
      return;
    }

    if (refresh) {
      resetPagination();
    }

    // 触底加载时使用 beginLoadMore
    if (!refresh && !beginLoadMore()) return;

    try {
      final (limit, offset) = paginationParams;

      final result = await ApiClient.get(
        'mood_diaries',
        filters: {
          'user_id': 'eq.$userId',
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
        showSnackBar(context, '加载失败，请稍后重试', isError: true);
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
        await _loadDiaries(refresh: true);
        OfflineSyncService.instance.syncPending();
        EventBus.instance.fire(EventType.moodDiaryUpdated);
        if (mounted) {
          showSnackBar(context, '添加成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.create,
          table: 'mood_diaries',
          data: diary.toJson(),
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.create,
        table: 'mood_diaries',
        data: diary.toJson(),
      );
      if (mounted) {
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
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
          await _loadDiaries(refresh: true);
          OfflineSyncService.instance.syncPending();
          if (mounted) {
            showSnackBar(context, '删除成功');
          }
        } else {
          await OfflineSyncService.instance.enqueue(
            action: OfflineAction.delete,
            table: 'mood_diaries',
            filters: {'id': 'eq.$id'},
          );
          if (mounted) {
            showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
          }
        }
      } catch (e) {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.delete,
          table: 'mood_diaries',
          filters: {'id': 'eq.$id'},
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
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
        await _loadDiaries(refresh: true);
        OfflineSyncService.instance.syncPending();
        if (mounted) {
          showSnackBar(context, '更新成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.update,
          table: 'mood_diaries',
          data: diary.toUpdateJson(),
          filters: {'id': 'eq.${diary.id}'},
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
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
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
      }
    }
  }

  void _showEditDiaryForm(MoodDiaryModel diary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DiaryForm(
        userId: _userId ?? 'local_user',
        diary: diary,
        onSave: (updatedDiary) async {
          // 系统敏感词检测
          await SensitiveWordService.instance.initialize();
          final contentResult = updatedDiary.content == null || updatedDiary.content!.isEmpty
              ? null
              : SensitiveWordService.instance.checkSystemContentSync(updatedDiary.content!);
          if (contentResult?.isBlocked ?? false) {
            if (!context.mounted) return;
            showSnackBar(context, '日记内容包含敏感信息，请修改后重试', isError: true);
            return;
          }
          if (!context.mounted) return;
          Navigator.pop(context);
          _updateMoodDiary(updatedDiary.copyWith(
            content: contentResult?.processedText ?? updatedDiary.content,
          ));
        },
      ),
    );
  }

  void _showDiaryForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DiaryForm(
        userId: _userId ?? 'local_user',
        onSave: (newDiary) async {
          // 系统敏感词检测
          await SensitiveWordService.instance.initialize();
          final contentResult = newDiary.content == null || newDiary.content!.isEmpty
              ? null
              : SensitiveWordService.instance.checkSystemContentSync(newDiary.content!);
          if (contentResult?.isBlocked ?? false) {
            if (!context.mounted) return;
            showSnackBar(context, '日记内容包含敏感信息，请修改后重试', isError: true);
            return;
          }
          if (!context.mounted) return;
          Navigator.pop(context);
          _createMoodDiary(newDiary.copyWith(
            content: contentResult?.processedText ?? newDiary.content,
          ));
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
      body: MoodDiaryContent(
        diaries: _diaries,
        isLoading: _isLoading,
        scrollController: scrollController,
        onRefresh: () => _loadDiaries(refresh: true),
        onShowEditForm: _showEditDiaryForm,
        onDelete: _deleteMoodDiary,
        buildLoadMoreIndicator: buildLoadMoreIndicator,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDiaryForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

