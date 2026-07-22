import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';
import '../widgets/habit_card.dart';
import 'habit_edit_dialog.dart';

/// 习惯打卡页面 - Supabase 数据同步
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<HabitModel> _habits = [];
  Map<String, List<HabitCheckinModel>> _checkinHistory = {};
  Map<String, ReminderScheduleModel> _reminderSchedules = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  /// 是否已至少成功加载过一次（用于并发守卫，避免拦截首次加载）
  bool _hasLoadedOnce = false;
  bool? _filterStatus;
  int _offset = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHabits();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadHabits();
      }
    }
  }

  Future<void> _loadHabits({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _habits = [];
        _checkinHistory = {};
        _reminderSchedules = {};
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    // 防并发：如果已经在加载中（非刷新且已加载过一次），直接返回
    // 注意：不能用 _isLoading 判断首次加载，因其初始即为 true，
    // 否则会和"首次加载"互相死锁导致永久 loading。
    if (!refresh && _hasLoadedOnce && (_isLoading || _isLoadingMore)) return;

    final isFirstPage = _offset == 0;

    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _habits = [];
        _checkinHistory = {};
        _reminderSchedules = {};
        _isLoading = true;
      });
    } else if (isFirstPage) {
      // 1. 先加载本地缓存（仅在初始第一页时）
      final cachedHabits = await CacheHelper.instance.loadList(CacheHelper.keyHabits);
      if (cachedHabits.isNotEmpty && mounted) {
        setState(() {
          _habits = cachedHabits.map((e) => HabitModel.fromJson(e)).toList();
          _checkinHistory = {}; // 缓存加载时重置打卡记录，避免显示旧状态
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    } else {
      setState(() => _isLoadingMore = true);
    }

    // 2. 从网络分页加载
    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };
      if (_filterStatus != null) {
        filters['is_active'] = 'eq.$_filterStatus';
      }

      final habitsResult = await ApiClient.get(
        'habits',
        filters: filters,
        order: 'is_active.desc',
        limit: _limit,
        offset: _offset,
      );

      if (!habitsResult.isSuccess) {
        throw Exception('HTTP ${habitsResult.statusCode}');
      }

      final habitsData = habitsResult.data!;
      final items = habitsData.map((e) => HabitModel.fromJson(e)).toList();

      // 仅第一页时保存缓存
      if (_offset == 0) {
        await CacheHelper.instance.saveList(CacheHelper.keyHabits, habitsData);
      }

      // 并行加载打卡记录和提醒计划（分页）
      final history = <String, List<HabitCheckinModel>>{};
      final schedules = <String, ReminderScheduleModel>{};
      if (items.isNotEmpty) {
        final habitIds = items.map((h) => h.id).join(',');
        final results = await Future.wait([
          ApiClient.get(
            'habit_checkins',
            filters: {'habit_id': 'in.($habitIds)'},
            order: 'checkin_at.desc',
            limit: _limit,
            offset: _offset,
          ),
          ApiClient.get(
            'reminder_schedules',
            filters: {'habit_id': 'in.($habitIds)'},
            limit: _limit,
            offset: _offset,
          ),
        ]);

        final checkinsResult = results[0];
        final scheduleResult = results[1];

        if (checkinsResult.isSuccess) {
          for (final checkin in checkinsResult.data!) {
            final model = HabitCheckinModel.fromJson(checkin);
            history.putIfAbsent(model.habitId, () => []).add(model);
          }
        }
        // 确保每个 habit 都有条目
        for (final habit in items) {
          history.putIfAbsent(habit.id, () => []);
        }

        if (scheduleResult.isSuccess) {
          for (final s in scheduleResult.data!) {
            final model = ReminderScheduleModel.fromJson(s);
            schedules[model.habitId] = model;
          }
        }
      }

      if (mounted) {
        setState(() {
          if (refresh || isFirstPage) {
            _habits = items;
            _checkinHistory = history;
            _reminderSchedules = schedules;
          } else {
            _habits.addAll(items);
            _checkinHistory.addAll(history);
            _reminderSchedules.addAll(schedules);
          }
          _offset += _limit;
          _hasMore = items.length >= _limit;
          _isLoading = false;
          _isLoadingMore = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasLoadedOnce = true;
        });
        // 如果已有数据，静默失败不提示
        if (_habits.isEmpty) {
          _showError('加载习惯失败，请稍后重试');
        }
      }
    }
  }

  void _showError(String message) {
    showSnackBar(context, message, isError: true);
  }

  Future<void> _checkIn(HabitModel habit) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 检查今天是否已经打卡
      final checkins = _checkinHistory[habit.id] ?? [];
      final alreadyChecked = checkins.any((c) {
        final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
        return dateStr == todayStr;
      });

      if (alreadyChecked) {
        _showError('今天已经打卡了');
        return;
      }

      // 添加打卡记录
      final checkinId = const Uuid().v4();
      final checkinResult = await ApiClient.post(
        'habit_checkins',
        {
          'id': checkinId,
          'habit_id': habit.id,
          'user_id': _userId,
          'checkin_at': today.toUtc().toIso8601String(),
        },
      );

      if (!checkinResult.isSuccess) {
        throw Exception('添加打卡记录失败: HTTP ${checkinResult.statusCode}');
      }

      // 立即本地更新打卡记录，UI马上变为已打卡状态
      if (mounted) {
        setState(() {
          _checkinHistory.putIfAbsent(habit.id, () => []);
          _checkinHistory[habit.id]!.add(HabitCheckinModel(
            id: checkinId,
            habitId: habit.id,
            checkinAt: today,
          ));
        });
      }

      await _loadHabits(refresh: true);

      if (!mounted) return;
      // 显示成功提示
      // TODO: showSnackBar 不支持自定义 backgroundColor，保留原样
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${habit.name} 打卡成功！'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      _showError('打卡失败，请稍后重试');
    }
  }

  Future<void> _deleteHabit(String id) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认删除',
      content: '删除后无法恢复，是否继续？',
    );

    if (confirmed == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'habits',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          _loadHabits(refresh: true);
        } else {
          throw Exception('HTTP ${result.statusCode}');
        }
      } catch (e) {
        _showError('删除失败，请稍后重试');
      }
    }
  }

  Future<void> _toggleHabitActive(HabitModel habit) async {
    final action = habit.isActive ? '暂停' : '恢复';
    final confirmed = await showConfirmDialog(
      context,
      title: '确认$action',
      content: '确定要$action「${habit.name}」吗？',
    );

    if (confirmed != true) return;

    try {
      final newActive = !habit.isActive;
      final result = await ApiClient.patchByFilter(
        'habits',
        filters: {'id': 'eq.${habit.id}'},
        body: {'is_active': newActive},
      );

      if (result.isSuccess) {
        _loadHabits(refresh: true);
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      _showError('\$action失败，请稍后重试');
    }
  }

  Future<void> _showEditDialog({HabitModel? habit}) {
    return showHabitEditDialog(
      context: context,
      habit: habit,
      reminderSchedules: _reminderSchedules,
      currentUserId: _userId,
      onSaved: () => _loadHabits(refresh: true),
    );
  }

  Future<void> _showHistoryDialog(HabitModel habit) async {
    final checkins = _checkinHistory[habit.id] ?? [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${habit.name} 打卡记录'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: checkins.isEmpty
              ? const Center(child: Text('暂无打卡记录'))
              : ListView.builder(
                  itemCount: checkins.length,
                  itemBuilder: (context, index) {
                    final checkin = checkins[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: AppTheme.success),
                      title: Text(DateTimeUtils.formatStandard(checkin.checkinAt)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  bool _isCheckedInToday(String habitId) {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final checkins = _checkinHistory[habitId] ?? [];
    return checkins.any((c) {
      final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
      return dateStr == todayStr;
    });
  }

  int _getTotalCheckins(String habitId) {
    return _checkinHistory[habitId]?.length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯打卡'),
        actions: [
          PopupMenuButton<bool?>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
              _loadHabits(refresh: true);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              const PopupMenuItem(
                value: true,
                child: Text('进行中'),
              ),
              const PopupMenuItem(
                value: false,
                child: Text('已暂停'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _habits.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadHabits(refresh: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(
                          child: EmptyWidget(icon: Icons.track_changes_outlined, message: '还没有习惯'),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadHabits(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _habits.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _habits.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: LoadingWidget()),
                        );
                      }
                      final habit = _habits[index];
                      final isCheckedIn = _isCheckedInToday(habit.id);
                      final totalCheckins = _getTotalCheckins(habit.id);
                      final schedule = _reminderSchedules[habit.id];
                      final shouldRemindToday = schedule?.shouldRemindToday(DateTime.now()) ?? false;
                      return HabitCard(
                        habit: habit,
                        isCheckedIn: isCheckedIn,
                        totalCheckins: totalCheckins,
                        reminderSchedule: schedule,
                        shouldRemindToday: shouldRemindToday,
                        onCheckIn: () => _checkIn(habit),
                        onEdit: () => _showEditDialog(habit: habit),
                        onDelete: () => _deleteHabit(habit.id),
                        onViewHistory: () => _showHistoryDialog(habit),
                        onToggleActive: () => _toggleHabitActive(habit),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

