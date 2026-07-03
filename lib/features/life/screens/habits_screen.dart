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
import '../widgets/reminder_schedule_picker.dart';

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

    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _habits = [];
        _checkinHistory = {};
        _reminderSchedules = {};
        _isLoading = true;
      });
    } else if (_offset == 0) {
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
          if (refresh) {
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        // 如果已有数据，静默失败不提示
        if (_habits.isEmpty) {
          _showError('加载习惯失败: $e');
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${habit.name} 打卡成功！'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      _showError('打卡失败: $e');
    }
  }

  Future<void> _deleteHabit(String id) async {
    final confirmed = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这个习惯吗？相关打卡记录也会被删除。');

    if (confirmed == true) {
      try {
        // 先删除打卡记录
        await ApiClient.batchDeleteByFilter(
          'habit_checkins',
          filters: {'habit_id': 'eq.$id'},
        );

        // 再删除习惯
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
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _showEditDialog({HabitModel? habit}) async {
    final isEditing = habit != null;
    final nameController = TextEditingController(text: habit?.name ?? '');
    final descController = TextEditingController(text: habit?.description ?? '');
    final targetDaysController = TextEditingController(
      text: (habit?.targetDays ?? 21).toString(),
    );

    // 提醒计划状态
    ReminderScheduleModel? reminderSchedule = isEditing
        ? _reminderSchedules[habit.id]
        : null;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑习惯' : '添加习惯'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '习惯名称 *',
                    hintText: '例如：早起、阅读、运动',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '输入习惯描述（可选）',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetDaysController,
                  decoration: const InputDecoration(
                    labelText: '目标天数',
                    hintText: '例如：21',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ReminderSchedulePicker(
                  initialSchedule: reminderSchedule,
                  onChanged: (schedule) {
                    setDialogState(() {
                      reminderSchedule = schedule;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showError('请输入习惯名称');
                  return;
                }

                final targetDays = int.tryParse(targetDaysController.text) ?? 21;
                final userId = _userId ?? 'local_user';
                String? habitId;

                try {
                  if (isEditing) {
                    habitId = habit.id;
                    final result = await ApiClient.patchByFilter(
                      'habits',
                      filters: {'id': 'eq.$habitId'},
                      body: {
                        'name': nameController.text.trim(),
                        'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                        'target_days': targetDays,
                      },
                    );
                    if (!result.isSuccess) {
                      throw Exception('HTTP ${result.statusCode}');
                    }
                  } else {
                    habitId = const Uuid().v4();
                    final result = await ApiClient.post(
                      'habits',
                      {
                        'id': habitId,
                        'user_id': userId,
                        'name': nameController.text.trim(),
                        'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                        'target_days': targetDays,
                        'is_active': true,
                      },
                    );
                    if (!result.isSuccess) {
                      throw Exception('HTTP ${result.statusCode}');
                    }
                  }

                  // 保存提醒计划
                  final schedule = reminderSchedule?.copyWith(
                    habitId: habitId,
                    userId: userId,
                  );
                  if (schedule != null) {
                    if (schedule.id.isNotEmpty) {
                      // 更新已有提醒计划
                      await ApiClient.patchByFilter(
                        'reminder_schedules',
                        filters: {'id': 'eq.${schedule.id}'},
                        body: schedule.toJsonForUpdate(),
                      );
                    } else {
                      // 新建提醒计划
                      final newId = const Uuid().v4();
                      await ApiClient.post(
                        'reminder_schedules',
                        schedule.copyWith(id: newId).toJson(),
                      );
                    }
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadHabits(refresh: true);
                } catch (e) {
                  _showError('保存失败: $e');
                }
              },
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
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
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final habit = _habits[index];
                      final isCheckedIn = _isCheckedInToday(habit.id);
                      final totalCheckins = _getTotalCheckins(habit.id);
                      final schedule = _reminderSchedules[habit.id];
                      final shouldRemindToday = schedule?.shouldRemindToday(DateTime.now()) ?? false;
                      return _HabitCard(
                        habit: habit,
                        isCheckedIn: isCheckedIn,
                        totalCheckins: totalCheckins,
                        reminderSchedule: schedule,
                        shouldRemindToday: shouldRemindToday,
                        onCheckIn: () => _checkIn(habit),
                        onEdit: () => _showEditDialog(habit: habit),
                        onDelete: () => _deleteHabit(habit.id),
                        onViewHistory: () => _showHistoryDialog(habit),
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

class _HabitCard extends StatelessWidget {
  final HabitModel habit;
  final bool isCheckedIn;
  final int totalCheckins;
  final ReminderScheduleModel? reminderSchedule;
  final bool shouldRemindToday;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;

  const _HabitCard({
    required this.habit,
    required this.isCheckedIn,
    required this.totalCheckins,
    this.reminderSchedule,
    required this.shouldRemindToday,
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = Color(habitColors['blue']!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.track_changes,
                    color: habitColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              habit.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (!habit.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '已暂停',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (habit.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          habit.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 提醒状态
                      if (reminderSchedule != null && reminderSchedule!.isEnabled) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              shouldRemindToday ? Icons.notifications_active : Icons.notifications_none,
                              size: 14,
                              color: shouldRemindToday
                                  ? Theme.of(context).colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reminderSchedule!.getScheduleDescription(),
                              style: TextStyle(
                                fontSize: 11,
                                color: shouldRemindToday
                                    ? Theme.of(context).colorScheme.primary
                                    : colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'history':
                        onViewHistory();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text('打卡记录'),
                        ],
                      ),
                    ),
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
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: '目标天数',
                  value: '${habit.targetDays}',
                  icon: Icons.flag,
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatItem(
                  label: '总打卡',
                  value: '$totalCheckins',
                  icon: Icons.check_circle,
                  color: AppTheme.success,
                ),
                _StatItem(
                  label: '最长连续',
                  value: '${habit.longestStreak}',
                  icon: Icons.local_fire_department,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: habit.targetDays > 0 ? totalCheckins / habit.targetDays : 0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '进度: $totalCheckins/${habit.targetDays} 天 (${habit.targetDays > 0 ? ((totalCheckins / habit.targetDays) * 100).toInt() : 0}%)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isCheckedIn ? null : onCheckIn,
                icon: Icon(isCheckedIn ? Icons.check : Icons.add),
                label: Text(isCheckedIn ? '今日已打卡' : '立即打卡'),
                style: FilledButton.styleFrom(
                  backgroundColor: isCheckedIn ? AppTheme.success : habitColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
